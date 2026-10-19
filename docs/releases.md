# Releases, Exports and Signing

## Toolchain (pinned)

| Tool | Version | Notes |
|---|---|---|
| Godot editor | **4.7.2-stable** | `tools/godot-version.txt`. Windows zip SHA-512 `83decd58fdf67b9d657958a1ae6bf1929c20785315a81effe245874cdc57acb709bf868e00778a96984338c1b29dafdb453c6847747694621c6ecf5da2259993`; Linux zip SHA-512 `9aa00f7a…ed54c65` (full value in `tools/ci/install_godot.sh`) |
| Export templates | 4.7.2-stable | SHA-512 `ca4d71c4…cb84079` (full value in `tools/ci/install_godot.sh`) |
| JDK | 17+ (CI: Temurin 17; verified locally with Temurin 21.0.11) | Required by Godot's Android export |
| Android SDK | Platform-tools + build-tools (verified locally with build-tools 36.0.0) | Exported APK: minSdk 24, targetSdk 36 |
| gdtoolkit | 4.5.0 | `tools/requirements-dev.txt` |

## Versioning

Semantic versions without Conventional-Commit coupling. The single source is
`application/config/version` in `game/project.godot` (currently `0.4.0`);
Android `version/code` in `export_presets.cfg` must be incremented for every
store upload. Tag `vX.Y.Z` → `release.yml` checks the tag equals the project
version and that `CHANGELOG.md` has a `## [X.Y.Z]` section.

## Desktop

```bash
./tools/godot.sh --headless --path game --export-debug "Windows Desktop" ../builds/windows/METHOD_HORROR.exe
./tools/godot.sh --headless --path game --export-debug "Linux" ../builds/linux/method_horror.x86_64
./builds/linux/method_horror.x86_64 --headless -- --smoke   # verify an exported build
```

Verified locally: Windows debug export (pack 9.5 MB), exported binary starts
cleanly headless.

## Android

### One-time setup (developer machine)

1. Install the 4.7.2 export templates (Editor → Manage Export Templates, or
   `tools/ci/install_godot.sh --templates` on Linux).
2. Editor Settings → Export → Android: set **Java SDK Path** and **Android SDK
   Path**, and a **debug keystore** (Godot creates one on first editor launch;
   or run `tools/ci/android_setup.sh` on Linux, which writes the standard public
   debug key `androiddebugkey` / `android`).
3. Package id: `com.method.horror` (change `package/unique_name` in the Android
   preset once ownership of the id is confirmed).

### Debug APK

```bash
./tools/godot.sh --headless --path game --export-debug "Android" ../builds/android/method_horror_debug.apk
```

Verified locally (2026-10-17, five playable maps): 42.5 MB APK, signed with the debug certificate,
`com.method.horror`, versionCode 5 / versionName 0.4.0, minSdk 24, targetSdk 36,
landscape (`userLandscape`), permissions INTERNET, ACCESS_NETWORK_STATE, VIBRATE,
arm64-v8a.

### Install on a device

```bash
adb devices                                  # enable USB debugging on the phone first
adb install -r builds/android/method_horror_debug.apk
adb logcat -s godot                          # runtime logs
```

**Status: not yet installed on a physical device** (none was connected while
building this milestone).

### Release signing

Never commit a keystore. Create one once, offline:

```bash
keytool -genkeypair -v -keystore method-release.keystore -alias method -keyalg RSA -keysize 4096 -validity 10000
```

Store it in a password manager. For CI, add **repository environment secrets**
on a protected environment named `release` (required reviewers recommended):

- `ANDROID_RELEASE_KEYSTORE_BASE64` — `base64 -w0 method-release.keystore`
- `ANDROID_RELEASE_KEYSTORE_USER` — the alias
- `ANDROID_RELEASE_KEYSTORE_PASSWORD`

`release.yml` writes the keystore to `$RUNNER_TEMP`, passes it to Godot via
`GODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD`, and deletes it in an
`always()` step. Without these secrets the job reports **"signing: SKIPPED"** in
the release notes and produces no signed APK.

Local release build with the same variables:

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/secure/method-release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=method
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='…'
./tools/godot.sh --headless --path game --export-release "Android" ../builds/android/method_horror.apk
```

**The current key.** Since 0.3.1 the APK is signed with the METHOD HORROR
release key (alias `methodhorror`, certificate SHA-256
`AB:E7:8F:00:1E:A5:3A:2F:C6:7C:8B:78:C2:25:51:F3:D0:0C:3D:C2:9E:14:55:0B:62:11:5C:4F:07:69:5C:24`).
It lives on the maintainer's machine, outside the repository, and must be
backed up: an app update has to be signed with the same key. The CI secrets
above are not configured yet, so each release's APK is built locally with the
commands above and attached to the GitHub release as `METHOD_HORROR.apk`
(a fixed name, so `releases/latest/download/METHOD_HORROR.apk` always serves
the newest one), with its `.sha256`.

Every export preset excludes `assets/monsters/*` and `assets/monster-pack/*`:
the imported monster packs are local only (see docs/monsters.md), so a build
made on a machine that has them still ships the procedural enemies.

Google Play requires an AAB built with Gradle (`gradle_build/use_gradle_build=true`
and the Android build template). That path is documented here but **not yet
exercised**.

## iOS

Architecture is mobile-ready (touch, safe areas, Mobile renderer), but an iOS
export needs macOS, Xcode and an Apple developer account. **No iOS build has
been produced or tested.**

## Release checklist

1. All CI green on `main`; manual QA checklist done on real devices.
2. Bump `config/version`, Android `version/code`, Windows file/product version.
3. Move `[Unreleased]` notes to `## [X.Y.Z] - YYYY-MM-DD` in `CHANGELOG.md`.
4. Tag `vX.Y.Z` and push the tag; review the **draft** release; publish manually.
