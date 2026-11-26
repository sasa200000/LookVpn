# LookVPN (Android — Flutter + Go)

**One vibrant app. Multiple ways to stay connected — powered by LookVPN & Xray-core.**

LookVPN brings customizable Cloudflare Workers & Pages deployment, **VLESS**, **WARP**, **MASQUE**, **Serverless**, **Psiphon**, **Tor**, a **REAL** Cloudflare/WARP/MASQUE scanner, and **Look Hub** (a bundled Clean IP pool with country filters, 1-tap Fragment & WARP OBF presets, and live Look Panel sync) together in a modern Material You Expressive Android client.

## Key Capabilities

- **One-Tap Cloudflare Deployment:** Guided Setup Wizard deploys private Workers & Pages directly from the app using your own Cloudflare account (with Domain Fronting, ECH, and Tor fallback).
- **Multi-Protocol Core:** Native Go Xray-core (`xray/`), Psiphon (`psiphon/`), Tor + lyrebird, WARP, MASQUE and Serverless, each with live status and node selection.
- **Bento Dashboard & Settings:** three focused tabs (Dashboard, Scanner, Settings), a modular 1x1/2x1/2x2 dashboard with drag-and-resize editing, expandable tools for speed, core, IP/DNS and configurable quick settings, plus a unified expressive settings centre.
- **Built-in REAL Scanner (`scanner/`):** Scan live Cloudflare IPs and WARP/MASQUE endpoints tuned to your ISP.
- **Look Hub Built-In:**
  - **Bundled Clean IP Pool:** Browse by country, lock a **Fixed IP**, or apply a random batch to VLESS Clean IPs in 1 tap.
  - **Look Presets:** 1-tap TCP Fragment presets (`Look Balanced`, `Look Aggressive DPI Bypass`, `Look Stealth`, `Look High-Speed`), WARP OBF profiles (`OBF LITE`, `OBF BALANCED`, `OBF AGGRESSIVE`, `OBF STEALTH`), and DNS/Anti-Sanction presets.
  - **Look Panel Sync:** Pull live `/ips` from any deployed LookVPN Panel or import user subscriptions directly into Chain Proxies.
- **Dynamic Material You UI (7 palettes):** Sage Mint, Bettbox Blue, Deep Teal, Soft Lavender, Warm Amber, Soft Coral and Graphite Slate. Connected states, charts, halos and controls all follow the selected palette instead of a fixed green.
- **Everyday Power Tools:** Per-app proxy, Chain Proxies (VLESS/VMess/Trojan/Shadowsocks/WireGuard/Hysteria), Routing rules, DNS/FakeDNS, LAN sharing, Live Logs, and Config import/export.

## Building & Releasing APKs (GitHub Actions)

Every release APK must be signed with the **same** keystore. Android only installs an update when the package name and signing certificate match; otherwise it asks the user to uninstall the installed app first. The release workflow restores one persistent keystore from repository secrets and **fails** when any of them is missing — it never falls back to a debug key in CI.

### Required repository secrets

| Secret | Value |
| --- | --- |
| `KEYSTORE_BASE64` | Base64 of the PKCS12 keystore (`base64 -w0 release.p12`) |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_ALIAS` | Key alias inside the keystore (for example `lookvpn`) |
| `KEY_PASSWORD` | Key password (for PKCS12 usually the same as the store password) |

Set them under **Settings → Secrets and variables → Actions**. Keep the `.p12` and both passwords in two offline backups. Never create a new key for an existing app: that would force every user to uninstall and lose the update path.

### First-time setup (new app only)

```bash
keytool -genkeypair -v -keystore release.p12 -storetype PKCS12 \
  -alias lookvpn -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 release.p12 > release.p12.b64
```

Paste the contents of `release.p12.b64` into `KEYSTORE_BASE64`. Never commit `release.p12`, `release.p12.b64`, `android/key.properties`, or `android/keystore/release.p12` (all are git-ignored).

### Release checklist

1. Bump `version` in `pubspec.yaml` (`2.4.9+24`: the number after `+` is the Android `versionCode` and must always increase).
2. Update `RELEASE_NOTES.md`.
3. Commit and push `main`.
4. Tag the matching version and push the tag:
   ```bash
   git tag v2.4.9 && git push origin v2.4.9
   ```
5. GitHub Actions (`.github/workflows/release.yml`) builds `xray.aar`, `libpsiphon.so`, fetches Tor and Iran geo rules, minifies `worker/worker.js`, runs `flutter test`, and signs split + universal APKs.
6. The workflow uploads `SIGNING_CERT.txt` next to the APKs. Record its `SHA-256` fingerprint and compare it on every later release; it must never change.

### Installing updates

A build installed before v2.1.0 can still require one uninstall when moving to v2.1.0 or newer, because those older builds used a different or debug key. From v2.1.0 onward every release uses the keystore above, so newer APKs install directly over the installed app and keep its data. Do not change the four secrets after users have installed a release.

## License

Licensed under [GNU GPL v3.0](LICENSE).
