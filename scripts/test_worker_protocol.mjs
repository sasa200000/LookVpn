#!/usr/bin/env node
// Protocol checks for worker/worker.js that can run offline:
//   node scripts/test_worker_protocol.mjs
//
// It loads worker.js with the Cloudflare-only import removed, then checks the Shadowsocks
// classic AEAD framing against an independent Node crypto implementation (the wire format
// Xray-core speaks) and the VLESS/XHTTP header parser. No network or Cloudflare needed.
import { createDecipheriv, createCipheriv, createHash, hkdfSync, randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
let source = readFileSync(join(root, 'worker', 'worker.js'), 'utf8');
source = source.replace(/^import .*from 'cloudflare:sockets';$/m, '');
source += `\nexport { md5, ssMasterKey, createSsDecryptor, createSsEncryptor, parseVlessHeader, parseSocks5AddressHeader, isXhttpPath };\n`;
const worker = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);

let passed = 0;
function check(name, condition) {
  if (!condition) throw new Error(`FAILED: ${name}`);
  passed++;
  console.log(`  ok  ${name}`);
}

function leNonce(n) {
  const b = Buffer.alloc(12);
  for (let i = 0; i < 12; i++) {
    b[i] = n & 0xff;
    n = Math.floor(n / 256);
  }
  return b;
}

// Xray's passwordToCipherKey: MD5(password), then MD5(previous || password) until keySize.
function xrayMasterKey(password) {
  const pwd = Buffer.from(password);
  let key = Buffer.alloc(0);
  let prev = Buffer.alloc(0);
  while (key.length < 32) {
    prev = createHash('md5').update(Buffer.concat([prev, pwd])).digest();
    key = Buffer.concat([key, prev]);
  }
  return key.subarray(0, 32);
}

function aesKey(master, salt) {
  return Buffer.from(hkdfSync('sha1', master, salt, Buffer.from('ss-subkey'), 32));
}

// The client side of Xray's AEAD writer: salt, then encrypted length/payload chunks.
function encodeSsStream(password, plaintext, chunkSize = 0x3fff) {
  const salt = randomBytes(32);
  const key = aesKey(xrayMasterKey(password), salt);
  const parts = [salt];
  let nonce = 0;
  for (let off = 0; off < plaintext.length; off += chunkSize) {
    const part = plaintext.subarray(off, off + chunkSize);
    const header = Buffer.from([part.length >> 8, part.length & 0xff]);
    const c1 = createCipheriv('aes-256-gcm', key, leNonce(nonce++));
    parts.push(Buffer.concat([c1.update(header), c1.final(), c1.getAuthTag()]));
    const c2 = createCipheriv('aes-256-gcm', key, leNonce(nonce++));
    parts.push(Buffer.concat([c2.update(part), c2.final(), c2.getAuthTag()]));
  }
  return Buffer.concat(parts);
}

function decodeSsStream(password, wire) {
  const salt = wire.subarray(0, 32);
  const key = aesKey(xrayMasterKey(password), salt);
  let buffer = wire.subarray(32);
  let nonce = 0;
  const out = [];
  while (buffer.length >= 18) {
    const d1 = createDecipheriv('aes-256-gcm', key, leNonce(nonce));
    d1.setAuthTag(buffer.subarray(2, 18));
    const length = Buffer.concat([d1.update(buffer.subarray(0, 2)), d1.final()]).readUInt16BE(0);
    if (buffer.length < 18 + length + 16) break;
    const d2 = createDecipheriv('aes-256-gcm', key, leNonce(nonce + 1));
    d2.setAuthTag(buffer.subarray(18 + length, 18 + length + 16));
    out.push(Buffer.concat([d2.update(buffer.subarray(18, 18 + length)), d2.final()]));
    nonce += 2;
    buffer = buffer.subarray(18 + length + 16);
  }
  return Buffer.concat(out);
}

console.log('Shadowsocks AEAD (aes-256-gcm)');
const password = '5f4dcc3b-2f6e-4a1b-9e5c-8b7a6d5e4f3a';
const payload = Buffer.concat([
  // SOCKS5-style target: ATYP 3, "example.com", port 443, then payload.
  Buffer.from([3, 11]), Buffer.from('example.com'), Buffer.from([0x01, 0xbb]),
  Buffer.from('hello over shadowsocks'),
  randomBytes(70000),
]);
const encrypted = encodeSsStream(password, payload);
const decryptor = worker.createSsDecryptor(password);
const decrypted = [];
// Split the wire into uneven chunks, as WebSocket messages arrive.
for (let off = 0; off < encrypted.length; off += 7777) {
  const out = await decryptor.push(new Uint8Array(encrypted.subarray(off, off + 7777)));
  if (out.length) decrypted.push(Buffer.from(out));
}
check('decrypts Xray AEAD stream split into uneven chunks', Buffer.concat(decrypted).equals(payload));

const encryptor = worker.createSsEncryptor(password);
const serverWire = Buffer.concat([
  Buffer.from(await encryptor.push(new Uint8Array(Buffer.from('HTTP/1.1 200 OK\r\n\r\n')))),
  Buffer.from(await encryptor.push(new Uint8Array(randomBytes(50000)))),
]);
check('server stream decodes with the Xray AEAD reader', decodeSsStream(password, serverWire).length > 50000);

check('MD5 matches node crypto', Buffer.from(worker.md5(Buffer.from('abc'))).equals(createHash('md5').update('abc').digest()));
check('EVP_BytesToKey matches Xray', Buffer.from(worker.ssMasterKey(password)).equals(xrayMasterKey(password)));

console.log('Address parsing');
const readAddress = (bytes) => worker.parseSocks5AddressHeader(new Uint8Array(bytes).buffer, 0, null);
const domainHeader = [...Buffer.from([3, 11]), ...Buffer.from('example.com'), 0x01, 0xbb];
check('domain address needs more bytes while truncated', readAddress(domainHeader.slice(0, 5)).needMore === true);
const parsed = readAddress([...domainHeader, 1, 2, 3]);
check('domain address parses', parsed.addressRemote === 'example.com' && parsed.portRemote === 443 && parsed.rawDataIndex === domainHeader.length);
const v4 = readAddress([1, 104, 16, 1, 1, 0x01, 0xbb, 9]);
check('IPv4 address parses', v4.addressRemote === '104.16.1.1' && v4.portRemote === 443);

console.log('VLESS header');
const uuid = '5f4dcc3b-2f6e-4a1b-9e5c-8b7a6d5e4f3a';
const vless = new Uint8Array([
  0,
  ...uuid.replace(/-/g, '').match(/.{2}/g).map((h) => parseInt(h, 16)),
  0,
  1,
  0x01, 0xbb,
  1, 104, 16, 1, 1,
  9, 9, 9,
]);
const vlessParsed = worker.parseVlessHeader(vless.buffer, uuid);
check('VLESS request parses', vlessParsed.addressRemote === '104.16.1.1' && vlessParsed.portRemote === 443 && vlessParsed.rawDataIndex === 26);
check('XHTTP accepts Xray trailing slash', worker.isXhttpPath(`/${uuid}/xhttp/`, uuid));
check('XHTTP accepts plain path', worker.isXhttpPath(`/${uuid}/xhttp`, uuid));
check('XHTTP rejects another user', !worker.isXhttpPath('/00000000/xhttp/', uuid));

console.log(`\n${passed} checks passed`);
