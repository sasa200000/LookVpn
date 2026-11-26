import { connect } from 'cloudflare:sockets';

const WS_READY_STATE_OPEN = 1;
const WS_READY_STATE_CLOSING = 2;
const DEFAULT_PROXY_IPS = [
    'ProxyIP.DE.CMLiussss.net:443',
    'ProxyIP.Oracle.CMLiussss.net:443',
];

export default {
    async fetch(request, env, ctx) {
        try {
            const settings = readSettings(env);
            if (!settings) {
                return new Response('Not found', { status: 404 });
            }

            const url = new URL(request.url);
            const upgrade = request.headers.get('Upgrade');
            if (upgrade && upgrade.toLowerCase() === 'websocket') {
                return handleWebSocketProxy(request, url, settings);
            }

            // VLESS over XHTTP (Xray stream-one: one streaming POST and its response, to
            // /<uuid>/xhttp or /xhttp; Xray appends a trailing slash to the configured path).
            if (request.method === 'POST' && isXhttpPath(url.pathname, settings.id)) {
                return handleVlessXhttp(request, settings);
            }

            if (url.pathname === `/${settings.id}`) {
                return handleDoH(request);
            }

            return fallback(request, settings);
        } catch {
            return new Response('Internal error', { status: 500 });
        }
    },
};

function readSettings(env) {
    try {
        const data = JSON.parse(
            new TextDecoder().decode(Uint8Array.from(atob(env.ENV), (c) => c.charCodeAt(0)))
        );
        if (!data || data.v !== 1 || typeof data.id !== 'string' || !data.id) return null;
        const pips = (Array.isArray(data.pips) ? data.pips : [])
            .map((s) => String(s).trim())
            .filter(Boolean);

        return {
            id: data.id.toLowerCase(),
            pips,
            fb: String(data.fb || '').trim(),
        };
    } catch {
        return null;
    }
}

async function fallback(request, settings) {
    if (settings.fb) {
        try {
            const target = new URL(settings.fb);
            const url = new URL(request.url);
            url.protocol = target.protocol;
            url.hostname = target.hostname;
            url.port = target.port;
            return fetch(new Request(url, request));
        } catch {
            // Fall through to default 404.
        }
    }
    return new Response('Not found', { status: 404, headers: { 'Content-Type': 'text/plain' } });
}

function handleDoH(request) {
    const incoming = new URL(request.url);
    const target = new URL('https://security.cloudflare-dns.com/dns-query');
    target.search = incoming.search;
    return fetch(new Request(target, request));
}

function isXhttpPath(pathname, userId) {
    const path = String(pathname || '').replace(/\/+$/, '');
    return path === `/${userId}/xhttp` || path === '/xhttp' ||
        path === `/${userId}/splithttp` || path === '/splithttp';
}

// ---------------------------------------------------------------------------
// Multi-Protocol WebSocket Handler: VLESS, Trojan, and Shadowsocks (WS)
// ---------------------------------------------------------------------------
async function handleWebSocketProxy(request, url, settings) {
    const webSocketPair = new WebSocketPair();
    const [client, webSocket] = Object.values(webSocketPair);
    webSocket.accept();
    webSocket.binaryType = 'arraybuffer';

    const earlyDataHeader = request.headers.get('sec-websocket-protocol') || '';
    const readableWebSocketStream = makeReadableWebSocketStream(webSocket, earlyDataHeader);
    const isShadowsocksPath = url.pathname.startsWith(`/${settings.id}/ss`);

    if (isShadowsocksPath) {
        // Shadowsocks AEAD (aes-256-gcm, the cipher the app sets) over the authenticated
        // /<uuid>/ss path: the stream is a salt followed by encrypted length/payload chunks.
        // Xray rejects the old "none" cipher at startup, which is why SS never connected.
        handleShadowsocksWebSocket(readableWebSocketStream, webSocket, settings);
    } else {
        const remoteSocket = { value: null };

        readableWebSocketStream
            .pipeTo(new WritableStream({
                async write(chunk) {
                    if (remoteSocket.value) {
                        const writer = remoteSocket.value.writable.getWriter();
                        await writer.write(chunk);
                        writer.releaseLock();
                        return;
                    }

                    const parsed = await parseProtocolHeader(chunk, settings.id, false);
                    if (parsed.hasError) throw new Error(parsed.message);

                    const rawClientData = chunk.slice(parsed.rawDataIndex);
                    handleTCPOutBound(
                        remoteSocket,
                        parsed.addressRemote,
                        parsed.portRemote,
                        rawClientData,
                        webSocket,
                        parsed.responseHeader,
                        settings
                    );
                },
                close() {
                    safeCloseTcpSocket(remoteSocket.value);
                },
            }))
            .catch(() => safeCloseTcpSocket(remoteSocket.value));
    }

    const headers = earlyDataHeader ? { 'Sec-WebSocket-Protocol': earlyDataHeader } : undefined;
    return new Response(null, { status: 101, webSocket: client, headers });
}

// ---------------------------------------------------------------------------
// Shadowsocks AEAD over WebSocket (aes-256-gcm)
// ---------------------------------------------------------------------------
async function handleShadowsocksWebSocket(readableStream, webSocket, settings) {
    const decryptor = createSsDecryptor(settings.id);
    const encryptor = createSsEncryptor(settings.id);
    let remote = null;
    let pending = new Uint8Array(0);
    let closed = false;
    let sendChain = Promise.resolve();

    const send = (data) => {
        if (closed || !data || !data.byteLength) return Promise.resolve();
        sendChain = sendChain
            .then(() => {
                if (!closed && webSocket.readyState === WS_READY_STATE_OPEN) webSocket.send(data);
            })
            .catch(() => { });
        return sendChain;
    };

    const close = () => {
        closed = true;
        safeCloseTcpSocket(remote);
        safeCloseWebSocket(webSocket);
    };

    const writeRemote = async (data) => {
        if (!data || !data.byteLength) return;
        const writer = remote.writable.getWriter();
        try { await writer.write(data); } finally { try { writer.releaseLock(); } catch { } }
    };

    const startDownlink = () => {
        remote.readable
            .pipeTo(new WritableStream({
                async write(chunk) {
                    await send(await encryptor.push(chunk));
                },
                close() { close(); },
                abort() { close(); },
            }))
            .catch(close);
    };

    readableStream
        .pipeTo(new WritableStream({
            async write(chunk) {
                let plain;
                try { plain = await decryptor.push(toBytes(chunk)); } catch { close(); return; }
                if (!plain.length) return;
                if (remote) {
                    await writeRemote(plain);
                    return;
                }
                pending = concatBytes(pending, plain);
                const parsed = parseSocks5AddressHeader(pending, 0, null);
                if (parsed.needMore) return;
                if (parsed.hasError) { close(); return; }
                try {
                    remote = await connectTcp(parsed.addressRemote, parsed.portRemote);
                } catch {
                    close();
                    return;
                }
                remote.closed.catch(() => { }).finally(() => close());
                startDownlink();
                const data = pending.slice(parsed.rawDataIndex);
                pending = new Uint8Array(0);
                if (data.byteLength) await writeRemote(data);
            },
            close() { close(); },
            abort() { close(); },
        }))
        .catch(close);
}

async function connectTcp(address, port) {
    // Shadowsocks' payload is already encrypted for the target: a proxy-IP fallback would send
    // that ciphertext to the wrong server, so always dial the requested address.
    if (address.includes(':') && !address.startsWith('[')) address = `[${address}]`;
    return connect({ hostname: address, port });
}

// ---------------------------------------------------------------------------
// VLESS over XHTTP (HTTP POST streaming tunnel)
// ---------------------------------------------------------------------------
async function handleVlessXhttp(request, settings) {
    if (!request.body) {
        return new Response('Bad request', { status: 400 });
    }
    const reader = request.body.getReader();
    // The VLESS request header and the first payload can be split across body chunks.
    let buffered = new Uint8Array(0);
    let header = null;
    while (!header) {
        const { done, value } = await reader.read();
        if (done) break;
        if (!value || !value.byteLength) continue;
        buffered = concatBytes(buffered, toBytes(value));
        if (buffered.length < 24) continue;
        header = parseVlessHeader(buffered.buffer.slice(buffered.byteOffset, buffered.byteOffset + buffered.byteLength), settings.id);
        if (header.hasError && buffered.length > 2048) break;
        if (header.hasError) header = null;
    }
    if (!header || header.hasError) {
        try { reader.releaseLock(); } catch { }
        return new Response('Unauthorized', { status: 403 });
    }

    const initialData = buffered.slice(header.rawDataIndex);
    const responseHeader = new Uint8Array([header.version[0], 0]);

    let tcpSocket;
    try {
        tcpSocket = await openTcpWithFallback(header.addressRemote, header.portRemote, initialData, settings);
    } catch {
        try { reader.releaseLock(); } catch { }
        return new Response('Upstream error', { status: 502 });
    }

    // Xray stream-one: the rest of this POST body is the uplink.
    (async () => {
        try {
            const writer = tcpSocket.writable.getWriter();
            while (true) {
                const { done, value } = await reader.read();
                if (done) break;
                if (value && value.byteLength > 0) await writer.write(value);
            }
            writer.releaseLock();
        } catch {
            safeCloseTcpSocket(tcpSocket);
        }
    })();

    const responseStream = new ReadableStream({
        async start(controller) {
            // Send the VLESS response header at once: it starts the streaming response (so the
            // request is no longer idle) and Xray's reader expects it before any payload.
            controller.enqueue(responseHeader);
            try {
                const tcpReader = tcpSocket.readable.getReader();
                while (true) {
                    const { done, value } = await tcpReader.read();
                    if (done) break;
                    if (!value || !value.byteLength) continue;
                    controller.enqueue(value);
                }
                controller.close();
            } catch {
                try { controller.close(); } catch { }
            } finally {
                safeCloseTcpSocket(tcpSocket);
            }
        },
        cancel() {
            safeCloseTcpSocket(tcpSocket);
        },
    });

    return new Response(responseStream, {
        status: 200,
        headers: {
            // Xray's stream-one server answers with an SSE-looking response; the body is still
            // the raw VLESS downlink stream.
            'Content-Type': 'text/event-stream',
            'X-Accel-Buffering': 'no',
            'Cache-Control': 'no-store',
        },
    });
}

// ---------------------------------------------------------------------------
// Unified Protocol Header Parser: VLESS, Trojan (SHA-224), Shadowsocks (WS)
// ---------------------------------------------------------------------------
async function parseProtocolHeader(buffer, userId, isShadowsocksPath) {
    // 1. Shadowsocks over authenticated path /<uuid>/ss
    if (isShadowsocksPath) {
        return parseSocks5AddressHeader(buffer, 0, null);
    }

    // 2. Try VLESS binary header
    const vless = parseVlessHeader(buffer, userId);
    if (!vless.hasError) {
        return {
            ...vless,
            responseHeader: new Uint8Array([vless.version[0], 0]),
        };
    }

    // 3. Try Trojan header: 56-byte lowercase SHA-224(password) + CRLF + cmd(1) + SOCKS5 addr + CRLF
    if (buffer.byteLength >= 64) {
        const trojan = parseTrojanHeader(buffer, userId);
        if (!trojan.hasError) {
            return {
                ...trojan,
                responseHeader: null,
            };
        }
    }

    return vless;
}

function parseVlessHeader(buffer, userId) {
    if (buffer.byteLength < 24) return { hasError: true, message: 'invalid data' };

    const bytes = new Uint8Array(buffer);
    const version = bytes.slice(0, 1);
    if (uuidFromBytes(bytes, 1) !== userId) return { hasError: true, message: 'invalid user' };

    const optLength = bytes[17];
    const command = bytes[18 + optLength];
    if (command !== 1) {
        return { hasError: true, message: `command ${command} is not supported` };
    }

    const portIndex = 18 + optLength + 1;
    const portRemote = new DataView(buffer.slice(portIndex, portIndex + 2)).getUint16(0);
    const addressType = bytes[portIndex + 2];
    let addressValueIndex = portIndex + 3;
    let addressLength = 0;
    let addressRemote = '';

    switch (addressType) {
        case 1:
            addressLength = 4;
            addressRemote = bytes.slice(addressValueIndex, addressValueIndex + 4).join('.');
            break;
        case 2:
            addressLength = bytes[addressValueIndex];
            addressValueIndex += 1;
            addressRemote = new TextDecoder().decode(buffer.slice(addressValueIndex, addressValueIndex + addressLength));
            break;
        case 3: {
            addressLength = 16;
            const view = new DataView(buffer.slice(addressValueIndex, addressValueIndex + 16));
            const parts = [];
            for (let i = 0; i < 8; i++) parts.push(view.getUint16(i * 2).toString(16));
            addressRemote = parts.join(':');
            break;
        }
        default:
            return { hasError: true, message: `invalid address type ${addressType}` };
    }

    if (!addressRemote) return { hasError: true, message: 'empty address' };

    return {
        hasError: false,
        addressRemote,
        portRemote,
        rawDataIndex: addressValueIndex + addressLength,
        version,
    };
}

function parseTrojanHeader(buffer, password) {
    const bytes = new Uint8Array(buffer);
    if (bytes.length < 64 || bytes[56] !== 0x0d || bytes[57] !== 0x0a) {
        return { hasError: true, message: 'not trojan' };
    }
    const receivedHash = new TextDecoder().decode(bytes.slice(0, 56)).toLowerCase();
    const expectedHash = sha224Hex(password);
    if (receivedHash !== expectedHash) {
        return { hasError: true, message: 'invalid trojan password' };
    }
    const cmd = bytes[58];
    if (cmd !== 1) {
        return { hasError: true, message: 'trojan tcp only' };
    }
    const parsed = parseSocks5AddressHeader(buffer, 59, null);
    if (parsed.hasError) return parsed;
    // Skip trailing CRLF after Trojan request header
    let dataIdx = parsed.rawDataIndex;
    if (bytes[dataIdx] === 0x0d && bytes[dataIdx + 1] === 0x0a) {
        dataIdx += 2;
    }
    return { ...parsed, rawDataIndex: dataIdx };
}

function parseSocks5AddressHeader(buffer, offset, responseHeader) {
    const bytes = new Uint8Array(buffer);
    const need = () => ({ hasError: true, needMore: true, message: 'short socks5 header' });
    if (bytes.length < offset + 1) return need();
    const atyp = bytes[offset] & 0x0f;
    let idx = offset + 1;
    let addressRemote = '';

    if (atyp === 1) {
        if (bytes.length < idx + 4 + 2) return need();
        addressRemote = bytes.slice(idx, idx + 4).join('.');
        idx += 4;
    } else if (atyp === 3) {
        if (bytes.length < idx + 1) return need();
        const len = bytes[idx++];
        if (bytes.length < idx + len + 2) return need();
        addressRemote = new TextDecoder().decode(bytes.slice(idx, idx + len));
        idx += len;
    } else if (atyp === 4) {
        if (bytes.length < idx + 16 + 2) return need();
        const view = new DataView(buffer.slice(idx, idx + 16));
        const parts = [];
        for (let i = 0; i < 8; i++) parts.push(view.getUint16(i * 2).toString(16));
        addressRemote = parts.join(':');
        idx += 16;
    } else {
        return { hasError: true, message: `unsupported atyp ${atyp}` };
    }

    const portRemote = (bytes[idx] << 8) | bytes[idx + 1];
    idx += 2;
    if (!addressRemote || !portRemote) return { hasError: true, message: 'invalid target' };
    return {
        hasError: false,
        addressRemote,
        portRemote,
        rawDataIndex: idx,
        responseHeader,
    };
}

// Compact pure-JS SHA-224 for Trojan password verification (zero external deps)
function sha224Hex(str) {
    const K = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];
    const H = [0xc1059ed8, 0x367cd507, 0x3070dd17, 0xf70e5939, 0xffc00b31, 0x68581511, 0x64f98fa7, 0xbefa4fa4];
    const data = new TextEncoder().encode(str);
    const bitLen = data.length * 8;
    const padLen = ((data.length + 9 + 63) & ~63);
    const buf = new Uint8Array(padLen);
    buf.set(data);
    buf[data.length] = 0x80;
    const view = new DataView(buf.buffer);
    view.setUint32(padLen - 8, Math.floor(bitLen / 0x100000000), false);
    view.setUint32(padLen - 4, bitLen >>> 0, false);

    const W = new Uint32Array(64);
    const rotr = (n, x) => (x >>> n) | (x << (32 - n));
    for (let off = 0; off < padLen; off += 64) {
        for (let i = 0; i < 16; i++) W[i] = view.getUint32(off + i * 4, false);
        for (let i = 16; i < 64; i++) {
            const s0 = rotr(7, W[i - 15]) ^ rotr(18, W[i - 15]) ^ (W[i - 15] >>> 3);
            const s1 = rotr(17, W[i - 2]) ^ rotr(19, W[i - 2]) ^ (W[i - 2] >>> 10);
            W[i] = (W[i - 16] + s0 + W[i - 7] + s1) >>> 0;
        }
        let [a, b, c, d, e, f, g, h] = H;
        for (let i = 0; i < 64; i++) {
            const S1 = rotr(6, e) ^ rotr(11, e) ^ rotr(25, e);
            const ch = (e & f) ^ (~e & g);
            const t1 = (h + S1 + ch + K[i] + W[i]) >>> 0;
            const S0 = rotr(2, a) ^ rotr(13, a) ^ rotr(22, a);
            const maj = (a & b) ^ (a & c) ^ (b & c);
            const t2 = (S0 + maj) >>> 0;
            h = g; g = f; f = e; e = (d + t1) >>> 0;
            d = c; c = b; b = a; a = (t1 + t2) >>> 0;
        }
        H[0] = (H[0] + a) >>> 0; H[1] = (H[1] + b) >>> 0; H[2] = (H[2] + c) >>> 0; H[3] = (H[3] + d) >>> 0;
        H[4] = (H[4] + e) >>> 0; H[5] = (H[5] + f) >>> 0; H[6] = (H[6] + g) >>> 0; H[7] = (H[7] + h) >>> 0;
    }
    return H.slice(0, 7).map((x) => x.toString(16).padStart(8, '0')).join('');
}

const byteToHex = Array.from({ length: 256 }, (_, i) => (i + 256).toString(16).slice(1));

function uuidFromBytes(arr, offset) {
    const h = (i) => byteToHex[arr[offset + i]];
    return (
        h(0) + h(1) + h(2) + h(3) + '-' + h(4) + h(5) + '-' + h(6) + h(7) + '-' +
        h(8) + h(9) + '-' + h(10) + h(11) + h(12) + h(13) + h(14) + h(15)
    );
}

async function openTcpWithFallback(addressRemote, portRemote, initialData, settings) {
    const connectAndSend = async (addr, port) => {
        if (addr.includes(':') && !addr.startsWith('[')) addr = `[${addr}]`;
        const sock = connect({ hostname: addr, port });
        if (initialData && initialData.byteLength > 0) {
            const w = sock.writable.getWriter();
            await w.write(initialData);
            w.releaseLock();
        }
        return sock;
    };
    try {
        return await connectAndSend(addressRemote, portRemote);
    } catch {
        const pool = settings.pips.length ? settings.pips : DEFAULT_PROXY_IPS;
        const ep = pool[Math.floor(Math.random() * pool.length)];
        const { host, port } = parseHostPort(ep);
        return connectAndSend(host, port);
    }
}

async function handleTCPOutBound(remoteSocket, addressRemote, portRemote, rawClientData, webSocket, responseHeader, settings) {
    async function connectAndWrite(address, port) {
        if (address.includes(':') && !address.startsWith('[')) address = `[${address}]`;
        const tcpSocket = connect({ hostname: address, port });
        remoteSocket.value = tcpSocket;
        const writer = tcpSocket.writable.getWriter();
        if (rawClientData && rawClientData.byteLength > 0) {
            await writer.write(rawClientData);
        }
        writer.releaseLock();
        return tcpSocket;
    }

    async function retry() {
        const randomItem = (arr) => arr[Math.floor(Math.random() * arr.length)];
        try {
            const endpoint = settings.pips.length
                ? randomItem(settings.pips)
                : randomItem(DEFAULT_PROXY_IPS);
            const { host, port } = parseHostPort(endpoint);

            const tcpSocket = await connectAndWrite(host, port);
            tcpSocket.closed.catch(() => { }).finally(() => safeCloseWebSocket(webSocket));
            remoteSocketToWS(tcpSocket, webSocket, responseHeader, null);
        } catch (error) {
            webSocket.close(1011, `Retry failed: ${error && error.message || error}`);
        }
    }

    try {
        const tcpSocket = await connectAndWrite(addressRemote, portRemote);
        remoteSocketToWS(tcpSocket, webSocket, responseHeader, retry);
    } catch (error) {
        webSocket.close(1011, `Connection failed: ${error && error.message || error}`);
    }
}

async function remoteSocketToWS(remoteSocket, webSocket, responseHeader, retry) {
    let header = responseHeader;
    let hasIncomingData = false;

    try {
        await remoteSocket.readable.pipeTo(new WritableStream({
            async write(chunk, controller) {
                hasIncomingData = true;
                if (webSocket.readyState !== WS_READY_STATE_OPEN) {
                    controller.error('WebSocket is not open');
                }
                if (header) {
                    webSocket.send(await new Blob([header, chunk]).arrayBuffer());
                    header = null;
                } else {
                    webSocket.send(chunk);
                }
            },
            abort() {
                safeCloseTcpSocket(remoteSocket);
            },
        }));
    } catch {
        safeCloseTcpSocket(remoteSocket);
        safeCloseWebSocket(webSocket);
    }

    if (!hasIncomingData && retry) retry();
}

function makeReadableWebSocketStream(webSocket, earlyDataHeader) {
    let cancelled = false;
    return new ReadableStream({
        start(controller) {
            webSocket.addEventListener('message', (event) => {
                if (!cancelled) controller.enqueue(event.data);
            });
            webSocket.addEventListener('close', () => {
                safeCloseWebSocket(webSocket);
                if (!cancelled) controller.close();
            });
            webSocket.addEventListener('error', (err) => controller.error(err));

            const { earlyData, error } = base64ToArrayBuffer(earlyDataHeader);
            if (error) controller.error(error);
            else if (earlyData) controller.enqueue(earlyData);
        },
        cancel() {
            if (cancelled) return;
            cancelled = true;
            safeCloseWebSocket(webSocket);
        },
    });
}

function base64ToArrayBuffer(base64Str) {
    if (!base64Str) return { earlyData: null, error: null };
    try {
        const decoded = atob(base64Str.replace(/-/g, '+').replace(/_/g, '/'));
        return { earlyData: Uint8Array.from(decoded, (c) => c.charCodeAt(0)).buffer, error: null };
    } catch (error) {
        return { earlyData: null, error };
    }
}

function safeCloseTcpSocket(socket) {
    try {
        if (socket) socket.close();
    } catch { }
}

function safeCloseWebSocket(socket) {
    try {
        if (socket.readyState === WS_READY_STATE_OPEN || socket.readyState === WS_READY_STATE_CLOSING) socket.close();
    } catch { }
}

function parseHostPort(input) {
    const match = String(input).trim().match(/^(?:\[(?<ipv6>.+?)\]|(?<host>[^:]+))(?::(?<port>\d+))?$/);
    if (!match) throw new Error(`Invalid host:port: ${input}`);
    const { ipv6, host, port } = match.groups;
    return {
        host: ipv6 ? `[${ipv6}]` : host,
        port: port ? Number(port) : 443,
    };
}

function toBytes(value) {
    if (value instanceof Uint8Array) return value;
    if (value instanceof ArrayBuffer) return new Uint8Array(value);
    if (ArrayBuffer.isView(value)) return new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
    if (value && typeof value.arrayBuffer === 'function') return value.arrayBuffer().then((b) => new Uint8Array(b));
    return new Uint8Array(0);
}

function concatBytes(...parts) {
    const flat = parts.filter((p) => p && p.byteLength);
    if (!flat.length) return new Uint8Array(0);
    if (flat.length === 1) return flat[0];
    const total = flat.reduce((n, p) => n + p.byteLength, 0);
    const out = new Uint8Array(total);
    let offset = 0;
    for (const part of flat) {
        out.set(part, offset);
        offset += part.byteLength;
    }
    return out;
}

// ---------------------------------------------------------------------------
// Shadowsocks classic AEAD (aes-256-gcm), as Xray-core implements it.
// key = EVP_BytesToKey(password, MD5); per connection subkey = HKDF-SHA1(key, salt, "ss-subkey").
// Every TCP chunk is [2-byte length][16-byte tag] then [payload][16-byte tag], with the
// 12-byte AES-GCM nonce counting up little-endian. The server sends its own salt first.
// ---------------------------------------------------------------------------
const SS_KEY_LEN = 32;
const SS_SALT_LEN = 32;
const SS_CHUNK_MAX = 0x3fff;
const SS_INFO = new TextEncoder().encode('ss-subkey');
const ssKeyCache = new Map();

const MD5_K = Array.from({ length: 64 }, (_, i) => Math.floor(Math.abs(Math.sin(i + 1)) * 0x100000000) >>> 0);
const MD5_S = [7, 12, 17, 22, 5, 9, 14, 20, 4, 11, 16, 23, 6, 10, 15, 21];

function md5(bytes) {
    const len = bytes.length;
    const total = (((len + 8) >> 6) + 1) * 64;
    const padded = new Uint8Array(total);
    padded.set(bytes);
    padded[len] = 0x80;
    const view = new DataView(padded.buffer);
    const bits = len * 8;
    view.setUint32(total - 8, bits >>> 0, true);
    view.setUint32(total - 4, Math.floor(bits / 0x100000000), true);

    let a0 = 0x67452301, b0 = 0xefcdab89, c0 = 0x98badcfe, d0 = 0x10325476;
    const rotl = (x, n) => ((x << n) | (x >>> (32 - n))) >>> 0;
    for (let off = 0; off < total; off += 64) {
        const M = new Array(16);
        for (let i = 0; i < 16; i++) M[i] = view.getUint32(off + i * 4, true);
        let A = a0, B = b0, C = c0, D = d0;
        for (let i = 0; i < 64; i++) {
            let F, g;
            if (i < 16) { F = (B & C) | (~B & D); g = i; }
            else if (i < 32) { F = (D & B) | (~D & C); g = (5 * i + 1) % 16; }
            else if (i < 48) { F = B ^ C ^ D; g = (3 * i + 5) % 16; }
            else { F = C ^ (B | ~D); g = (7 * i) % 16; }
            const s = MD5_S[(i >> 4) * 4 + (i % 4)];
            const tmp = D;
            D = C;
            C = B;
            B = (B + rotl((A + F + MD5_K[i] + M[g]) >>> 0, s)) >>> 0;
            A = tmp;
        }
        a0 = (a0 + A) >>> 0;
        b0 = (b0 + B) >>> 0;
        c0 = (c0 + C) >>> 0;
        d0 = (d0 + D) >>> 0;
    }
    const out = new Uint8Array(16);
    const ov = new DataView(out.buffer);
    ov.setUint32(0, a0, true);
    ov.setUint32(4, b0, true);
    ov.setUint32(8, c0, true);
    ov.setUint32(12, d0, true);
    return out;
}

function ssMasterKey(password) {
    const cached = ssKeyCache.get(password);
    if (cached) return cached;
    const pw = new TextEncoder().encode(password);
    let key = new Uint8Array(0);
    let prev = new Uint8Array(0);
    while (key.length < SS_KEY_LEN) {
        prev = md5(concatBytes(prev, pw));
        key = concatBytes(key, prev);
    }
    const result = key.slice(0, SS_KEY_LEN);
    ssKeyCache.set(password, result);
    return result;
}

async function hmacSha1(keyBytes, data) {
    const key = await crypto.subtle.importKey('raw', keyBytes, { name: 'HMAC', hash: 'SHA-1' }, false, ['sign']);
    return new Uint8Array(await crypto.subtle.sign('HMAC', key, data));
}

async function hkdfSha1(ikm, salt, info, length) {
    const prk = await hmacSha1(salt, ikm);
    const out = new Uint8Array(length);
    let previous = new Uint8Array(0);
    let offset = 0;
    for (let counter = 1; offset < length; counter++) {
        const input = concatBytes(previous, info, new Uint8Array([counter]));
        previous = await hmacSha1(prk, input);
        out.set(previous.slice(0, Math.min(previous.length, length - offset)), offset);
        offset += previous.length;
    }
    return out;
}

function ssNonce(value) {
    const nonce = new Uint8Array(12);
    let n = value;
    for (let i = 0; i < 12; i++) {
        nonce[i] = n & 0xff;
        n = Math.floor(n / 256);
    }
    return nonce;
}

async function ssAesKey(password, salt) {
    const subkey = await hkdfSha1(ssMasterKey(password), salt, SS_INFO, SS_KEY_LEN);
    return crypto.subtle.importKey('raw', subkey, 'AES-GCM', false, ['encrypt', 'decrypt']);
}

function createSsDecryptor(password) {
    let key = null;
    let nonce = 0;
    let buffer = new Uint8Array(0);

    async function push(chunk) {
        buffer = concatBytes(buffer, chunk);
        const parts = [];
        while (true) {
            if (!key) {
                if (buffer.length < SS_SALT_LEN) break;
                const salt = buffer.slice(0, SS_SALT_LEN);
                buffer = buffer.slice(SS_SALT_LEN);
                key = await ssAesKey(password, salt);
            }
            if (buffer.length < 18) break;
            let lengthBytes;
            try {
                lengthBytes = new Uint8Array(await crypto.subtle.decrypt(
                    { name: 'AES-GCM', iv: ssNonce(nonce), tagLength: 128 }, key, buffer.slice(0, 18)
                ));
            } catch {
                throw new Error('shadowsocks: bad chunk length');
            }
            const length = (lengthBytes[0] << 8) | lengthBytes[1];
            if (length > SS_CHUNK_MAX) throw new Error('shadowsocks: chunk too large');
            if (buffer.length < 18 + length + 16) break;
            const payload = new Uint8Array(await crypto.subtle.decrypt(
                { name: 'AES-GCM', iv: ssNonce(nonce + 1), tagLength: 128 },
                key, buffer.slice(18, 18 + length + 16)
            ));
            parts.push(payload);
            nonce += 2;
            buffer = buffer.slice(18 + length + 16);
        }
        return concatBytes(...parts);
    }

    return { push };
}

function createSsEncryptor(password) {
    let key = null;
    let salt = null;
    let nonce = 0;
    let saltSent = false;

    async function push(data) {
        if (!data || !data.byteLength) return new Uint8Array(0);
        if (!key) {
            salt = crypto.getRandomValues(new Uint8Array(SS_SALT_LEN));
            key = await ssAesKey(password, salt);
        }
        const frames = [];
        for (let offset = 0; offset < data.length; offset += SS_CHUNK_MAX) {
            const part = data.slice(offset, offset + SS_CHUNK_MAX);
            const header = new Uint8Array([part.length >> 8, part.length & 0xff]);
            frames.push(new Uint8Array(await crypto.subtle.encrypt(
                { name: 'AES-GCM', iv: ssNonce(nonce), tagLength: 128 }, key, header
            )));
            nonce++;
            frames.push(new Uint8Array(await crypto.subtle.encrypt(
                { name: 'AES-GCM', iv: ssNonce(nonce), tagLength: 128 }, key, part
            )));
            nonce++;
        }
        const body = concatBytes(...frames);
        if (!saltSent) {
            saltSent = true;
            return concatBytes(salt, body);
        }
        return body;
    }

    return { push };
}
