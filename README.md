<div align="center">

<img src="assets/images/icon.png" alt="FlClash" width="88">

# FlClash

A multi-platform proxy client based on ClashMeta. Simple to use, open source and ad-free.

**English** · [简体中文](README_zh_CN.md)

[![Release](https://img.shields.io/github/v/release/chen08209/FlClash?style=flat-square&label=release)](https://github.com/chen08209/FlClash/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/chen08209/FlClash/total?style=flat-square&logo=github)](https://github.com/chen08209/FlClash/releases)
[![License](https://img.shields.io/github/license/chen08209/FlClash?style=flat-square)](LICENSE)
[![Telegram](https://img.shields.io/badge/Telegram-channel-26A5E4?style=flat-square&logo=telegram&logoColor=white)](https://t.me/FlClash)

[Website](https://chen08209.github.io/FlClash) · [Download](#download) · [Changelog](CHANGELOG.md) · [Build from source](#build-from-source)

</div>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="snapshots/preview-dark.png">
    <img alt="FlClash dashboard on a MacBook and a phone" src="snapshots/preview.png" width="92%">
  </picture>
</p>

## Features

- **One app for Android, Windows, macOS and Linux**, with x64 and ARM64 builds on the desktop.
- **mihomo (Clash.Meta) core** with rule routing, proxy groups, latency tests, system proxy and TUN mode.
- **Profiles** from a subscription link or a file, with a built-in editor, override scripts, and custom rules,
  proxies and proxy groups.
- **Live views** of connections, requests, DNS queries and logs.
- **Material You design with Apple-style interaction**: dynamic color, light and dark themes, continuous corners,
  sheets that snap between heights, and layouts that adapt from phones to desktops.
- **Backup and restore** through WebDAV or a local file.
- **Platform touches**: a Quick Settings tile, per-app proxy and Android TV support on Android; a tray menu and
  global hotkeys on the desktop.
- **Open source and ad-free**, licensed under GPL-3.0.

## Download

Get the latest build from [GitHub Releases](https://github.com/chen08209/FlClash/releases/latest), or open the
[website](https://chen08209.github.io/FlClash#download), which picks the right file for your device.

| Platform | Packages | Notes |
| --- | --- | --- |
| Android | APK for `arm64-v8a`, `armeabi-v7a` and `x86_64` | Most phones use `arm64-v8a`. Also on the F-Droid repository below. |
| Windows 10 and later | Installer (`.exe`) or portable `.zip`, for x64 and ARM64 | Pick ARM64 on Snapdragon and other ARM laptops. |
| macOS 12 and later | DMG for Apple Silicon and Intel | Also on Homebrew. |
| Linux | `.deb`, `.rpm` and AppImage, for x64 and ARM64 | See the tray note below. |

<p>
  <a href="https://chen08209.github.io/FlClash-fdroid-repo/repo?fingerprint=789D6D32668712EF7672F9E58DEEB15FBD6DCEEC5AE7A4371EA72F2AAE8A12FD"><img alt="Get it on F-Droid" src="snapshots/get-it-on-fdroid.svg" height="56"></a>
  <a href="https://github.com/chen08209/FlClash/releases/latest"><img alt="Get it on GitHub" src="snapshots/get-it-on-github.svg" height="56"></a>
</p>

**Homebrew**

```bash
brew tap chen08209/tap
brew install --cask flclash
```

**Linux tray icon**

The `.deb` package installs its own dependencies. With the AppImage or the `.rpm`, install the AyatanaAppIndicator
library so the tray icon can show:

```bash
sudo apt-get install libayatana-appindicator3-1   # Debian and Ubuntu
sudo dnf install libayatana-appindicator-gtk3     # Fedora
```

## Usage

**Import a profile from a link.** Opening a link in this form imports the subscription into FlClash. The `clashmeta://`
and `flclash://` schemes work the same way.

```text
clash://install-config?url=<URL-encoded subscription link>
```

**Automate on Android.** Tasker, MacroDroid and similar apps can start, stop or toggle the proxy by starting an
activity with one of these actions:

```text
com.follow.clash.action.START
com.follow.clash.action.STOP
com.follow.clash.action.TOGGLE
```

From a computer, the same works over adb:

```bash
adb shell am start -a com.follow.clash.action.TOGGLE
```

## Build from source

You need [Flutter](https://docs.flutter.dev/get-started/install) 3.47 (release builds use 3.47.6),
[Go](https://go.dev/dl/) 1.27 and [Rust](https://rustup.rs/) installed through rustup. Each platform builds on its own
host, except Android, which builds anywhere.

```bash
git clone --recursive https://github.com/chen08209/FlClash.git
cd FlClash
flutter pub get
dart setup.dart android   # or windows, macos, linux
```

Packages land in `dist/`. The Go core and the Rust libraries are compiled as part of the Flutter build.

| Platform | Also needed |
| --- | --- |
| Android | Android SDK with the NDK. Add `--arch arm64` to build a single ABI. |
| Windows | GCC (MinGW-w64) for the core and [Inno Setup](https://jrsoftware.org/isinfo.php) 6 for the installer. |
| macOS | Xcode and Node.js. The script installs `appdmg` through npm. |
| Linux | Debian or Ubuntu. The script installs the build packages with apt and downloads `appimagetool`. |

Run `dart setup.dart --help` for the remaining options, such as `--targets` to build only some package formats.

## Support

Starring the repository is the easiest way to support the project. Questions and announcements go to the
[Telegram channel](https://t.me/FlClash); bugs and feature requests go to
[GitHub Issues](https://github.com/chen08209/FlClash/issues).

<a href="https://star-history.com/#chen08209/FlClash&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=chen08209/FlClash&type=Date&theme=dark">
    <img alt="Star history" src="https://api.star-history.com/svg?repos=chen08209/FlClash&type=Date" width="640">
  </picture>
</a>

## License

FlClash is released under the [GPL-3.0 license](LICENSE).

---

## Fork Development Notes (flClashBLocal)

> Fork 维护笔记：此仓库为 [chen08209/FlClash](https://github.com/chen08209/FlClash) 的 fork，自定义分支 `flClashBLocal`。
> 项目情况以本 README 为准（CLAUDE.md 已废弃删除）。

### Remotes

- `upstream` = https://github.com/chen08209/FlClash （上游，`main`）
- `origin` = https://github.com/rickblue/FlClashB （fork，`flClashBLocal`）
- 注意：`origin` 的 fetch refspec 只拉取 `flClashBLocal` 单分支，需要同步上游时用 `upstream`

### 自定义改动（相对上游）

- `lib/views/access.dart`：手动添加包名功能
- `core/hub.go`：`handleGetProxies()` 直接遍历 `tunnel.Proxies()`；`handleUpdateConfig` 带 TUN 调试日志（`/tmp/flclash_tun_debug.log`）
- `android/service/build.gradle.kts`：`buildToolsVersion = "36.1.0"`
- `pubspec.yaml`：`material_color_utilities ^0.13.0`、`system_fonts ^1.0.1`
- `arb/intl_*.arb` + `lib/l10n/`：`manualAddPackage`/`manualAdded`/`invalidPackageName`/`packageAlreadyExists`/`inputPackageName`/`systemFont` 键
- 其他：自定义字体选择、tray 图标改进、Linux 窗口恢复、CI workflow（macOS DMG / Windows x64）

### 上游同步流程

```bash
git fetch upstream main
git checkout flClashBLocal
git rebase upstream/main
# 解决冲突（重点：core/hub.go、lib/views/access.dart、arb/*、pubspec.yaml）
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart run intl_utils:generate
# core/Clash.Meta 子模块有更新时：
git submodule update --init --recursive
rm -rf android/core/.cxx/ android/core/build/ android/app/build/
flutter build apk --release
git push origin flClashBLocal --force-with-lease
```

### 构建注意事项（本机环境）

- **home 目录只读**：系统 snap 版 flutter 不可用；使用仓库内 `.flutter_sdk`（Flutter 3.47.0）
- `PUB_CACHE`/`GOMODCACHE`/`GOCACHE` 需指向可写位置（`.pub-cache`/`.gomod`/`.gocache`，已在 `.gitignore` 中）
- 系统 Java 25 会导致 Gradle 直接调用失败；`flutter build` 使用 Android Studio 自带的 JDK 21
- 构建前必须清理 `android/core/.cxx/`，否则 CMake 可能使用缓存的 stub 分支
- `libcore.so` 正常大小 8-13KB（JNI bridge），`libclash.so` 正常大小 ~36MB
- 只构建 Android/macOS/Windows，不构建 Linux 版本

### macOS TUN setuid（post-build）

macOS SIP 阻止在用户目录下 `chown`。在 `/tmp` 准备 setuid 副本再硬链接回 app bundle，group 必须是 `admin`（`checkIsAdmin()` 检查 `root:admin`）：

```bash
BINARY="build/macos/Build/Products/Release/FlClash.app/Contents/MacOS/FlClashCore"
cp "$BINARY" /tmp/FlClashCore
sudo chown root:admin /tmp/FlClashCore && sudo chmod u+s,g+s /tmp/FlClashCore
rm "$BINARY"
ln /tmp/FlClashCore "$BINARY"
codesign --force --sign - "build/macos/Build/Products/Release/FlClash.app"
```

> `authorizeCore()`（`lib/common/system.dart`）已更新为使用 `ln -f` 自动完成此操作。
