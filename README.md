# TUN VPNSOPR

An Android VPN client source project with a dark navy / cyan cyber-security interface based on the supplied VPNSOPR logo.

## Included features

- sing-box core integration through `flutter_sing_box`.
- Android VPN permission flow through `VpnService`.
- Add, select and delete profiles.
- Import from clipboard, QR code, text/link and local files.
- Base64 subscriptions and supported VLESS, VMess, Trojan, Shadowsocks, Hysteria, Hysteria2 and AnyTLS share links.
- sing-box JSON and Clash-style YAML import through the core package.
- Standard WireGuard `.conf` parser (`[Interface]` and one or more `[Peer]` sections), converted to the current sing-box WireGuard endpoint format.
- Live upload/download rates and traffic totals while the core reports them.
- Core logs, proxy group selection and URL latency testing.
- JSON backup and restore for saved profiles.
- Android Always-on VPN compatibility (enabled manually by the user in Android VPN settings).
- GitHub Actions workflow to build split APKs for arm64, armeabi-v7a and x86_64.

This is a VPN **client**. It does not include VPN servers, free subscriptions or credentials. Add a configuration from a provider you trust.

## Compatibility and limitations

- `flutter_sing_box` 3.0.3 requires Flutter 3.44+ and Dart 3.12+.
- Its Android module requires `minSdk 26`, `compileSdk 37` and Java 17. The included script applies these settings after creating the Android host project.
- WireGuard is represented as a sing-box endpoint in the current core. The old WireGuard outbound format is deprecated.
- The WireGuard importer handles standard `Address`, `PrivateKey`, `DNS`, `MTU`, `PublicKey`, `PresharedKey`, `Endpoint`, `AllowedIPs`, `PersistentKeepalive`, and optional `Reserved` fields. AmneziaWG-specific obfuscation fields and vendor-specific extensions are not implemented in this first build.
- Automatic reconnect after reboot is provided by Android's **Always-on VPN** system option; the user must enable it manually in Android Settings. The app does not silently change system settings.
- Profile files are stored in the app's private application storage. This project does not claim to encrypt those files independently of Android's app sandbox. A backup JSON contains the original configuration data, including any private keys, so keep it private.

## Build locally

Requirements: Flutter 3.44+, Dart 3.12+, Python 3, JDK 17 and Android SDK platform 37.

From this folder:

```bash
./build_android.sh
```

The generated split APKs are placed in:

```text
build/app/outputs/flutter-apk/
```

For a modern 64-bit Android phone, use `app-arm64-v8a-release.apk`.

## Build with GitHub Actions

1. Upload the contents of this folder to a GitHub repository.
2. Open **Actions**.
3. Select **Build VPNSOPR APK**.
4. Press **Run workflow**.
5. When the job finishes, download the `VPNSOPR-Android-APKs` artifact.

The workflow builds APKs; it does not publish them to Google Play.

## License

The application source is intended to be distributed under GPL-3.0-only because it integrates the GPL-3.0 `flutter_sing_box` plugin. Review `THIRD_PARTY_NOTICES.md` before redistributing binaries or source.
