<div>

[**简体中文**](README_zh_CN.md)

</div>

## FlClash

[![Downloads](https://img.shields.io/github/downloads/chen08209/FlClash/total?style=flat-square&logo=github)](https://github.com/chen08209/FlClash/releases/)[![Last Version](https://img.shields.io/github/release/chen08209/FlClash/all.svg?style=flat-square)](https://github.com/chen08209/FlClash/releases/)[![License](https://img.shields.io/github/license/chen08209/FlClash?style=flat-square)](LICENSE)

[![Channel](https://img.shields.io/badge/Telegram-Channel-blue?style=flat-square&logo=telegram)](https://t.me/FlClash)

A multi-platform proxy client based on ClashMeta, simple and easy to use, open-source and ad-free.

on Desktop:
<p style="text-align: center;">
    <img alt="desktop" src="snapshots/desktop.gif">
</p>

on Mobile:
<p style="text-align: center;">
    <img alt="mobile" src="snapshots/mobile.gif">
</p>

## Features

✈️ Multi-platform: Android, Windows, macOS and Linux

💻 Adaptive multiple screen sizes, Multiple color themes available

💡 Based on Material You Design, [Surfboard](https://github.com/getsurfboard/surfboard)-like UI

☁️ Supports data sync via WebDAV

✨ Support subscription link, Dark mode

## Use

### Linux

⚠️ Make sure to install the following dependencies before using them

   ```bash
    sudo apt-get install libayatana-appindicator3-dev
   ```

### Android

Support the following actions

   ```bash
    com.follow.clash.action.START
    
    com.follow.clash.action.STOP
    
    com.follow.clash.action.TOGGLE
   ```

## Download

<a href="https://chen08209.github.io/FlClash-fdroid-repo/repo?fingerprint=789D6D32668712EF7672F9E58DEEB15FBD6DCEEC5AE7A4371EA72F2AAE8A12FD"><img alt="Get it on F-Droid" src="snapshots/get-it-on-fdroid.svg" width="200px"/></a> <a href="https://github.com/chen08209/FlClash/releases"><img alt="Get it on GitHub" src="snapshots/get-it-on-github.svg" width="200px"/></a>

### Homebrew

```bash
brew tap chen08209/tap
brew install --cask flclash
```

## Build

1. Update submodules
   ```bash
   git submodule update --init --recursive
   ```

2. Install `Flutter` and `Golang` environment

3. Build Application

    - android

        1. Install `Android SDK`, `Android NDK`

        2. Set `ANDROID_NDK` environment variable

        3. Run build script

           ```bash
           dart setup.dart android
           ```

    - windows

        1. Requires a Windows client

        2. Install `GCC`, `Inno Setup`

        3. Run build script

           ```bash
           dart setup.dart windows
           ```

    - linux

        1. Requires a Linux client

        2. Dependencies are auto-installed by setup script, or manually:
           ```bash
           sudo apt-get install -y libayatana-appindicator3-dev
           ```

        3. Run build script

           ```bash
           dart setup.dart linux
           ```

    - macOS

        1. Requires a macOS client

        2. Run build script

           ```bash
           dart setup.dart macos
           ```

        3. **TUN mode requires setuid.** macOS System Integrity Protection (SIP) blocks `chown` on files under home directories, so the binary must be prepared in `/tmp` and hardlinked back:

           ```bash
           BINARY="build/macos/Build/Products/Release/FlClash.app/Contents/MacOS/FlClashCore"
           cp "$BINARY" /tmp/FlClashCore
           sudo chown root:admin /tmp/FlClashCore && sudo chmod u+s,g+s /tmp/FlClashCore
           rm "$BINARY"
           ln /tmp/FlClashCore "$BINARY"
           codesign --force --sign - "build/macos/Build/Products/Release/FlClash.app"
           ```

           The app can also do this automatically via the admin password dialog when toggling TUN for the first time.

## Star

The easiest way to support developers is to click on the star (⭐) at the top of the page.

<p style="text-align: center;">
    <a href="https://api.star-history.com/svg?repos=chen08209/FlClash&Date">
        <img alt="start" width=50% src="https://api.star-history.com/svg?repos=chen08209/FlClash&Date"/>
    </a>
</p>

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
