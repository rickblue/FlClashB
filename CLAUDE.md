# CLAUDE.md - Claude Code instructions

Please read AGENTS.md for all project guidelines and conventions.

@AGENTS.md

## 项目信息
- Fork: https://github.com/rickblue/FlClashB
- 上游: https://github.com/chen08209/FlClash (remote: origin)
- Fork remote: myfork
- 自定义分支: flClashBLocal
- Flutter SDK: stable 3.41.2

## 自定义改动 (基于上游 main 672eacc)
- `lib/views/access.dart`: 手动添加包名功能 + 去掉 _getRealAccessControlProps 过滤
- `core/hub.go`: handleGetProxies() 改为直接遍历 tunnel.Proxies()
- `android/service/build.gradle.kts`: 加 buildToolsVersion = "36.1.0"
- `pubspec.yaml`: material_color_utilities 升级到 ^0.13.0
- `arb/intl_*.arb` + `lib/l10n/l10n.dart`: 5个i18n key (manualAddPackage, manualAdded, invalidPackageName, packageAlreadyExists, inputPackageName)

## 上游更新同步流程
```bash
git fetch origin
git checkout flClashBLocal
git rebase origin/main
# 解决冲突（重点关注 access.dart 和 hub.go）
flutter pub get
dart run build_runner build --delete-conflicting-outputs
# 如果 core/ 子模块有更新，重新编译 libclash.so
rm -rf android/core/.cxx/ android/core/build/ android/app/build/
flutter build apk --release
git push myfork flClashBLocal --force-with-lease
```

## 构建注意事项
- 系统 Java 25 会导致 Gradle 直接调用失败，但 flutter build 使用 Android Studio 自带的 JDK 21，不受影响
- 构建前必须清理 android/core/.cxx/ 否则 CMake 可能使用缓存的 stub 分支
- libcore.so 正常大小 8-13KB（JNI bridge），libclash.so 正常大小 ~36MB
- 不用编译linux版本

### macOS 构建

仅编译 Go 核心（不编译 Flutter）：

```bash
bash plugins/setup/buildkit/run_build_tool.sh macos
# 输出: libclash/macos/FlClashCore
```

编译后**必须**重新设置 setuid 权限，否则 TUN 模式无法工作。

由于 macOS SIP 限制，无法对用户目录下的文件直接 `chown`。使用 `ln -f` 创建一个指向 `/tmp` 中 setuid 副本的硬链接：

```bash
BINARY="build/macos/Build/Products/Release/FlClash.app/Contents/MacOS/FlClashCore"
cp "$BINARY" /tmp/FlClashCore
sudo chown root:admin /tmp/FlClashCore && sudo chmod u+s,g+s /tmp/FlClashCore
rm "$BINARY"
ln /tmp/FlClashCore "$BINARY"
codesign --force --sign - "build/macos/Build/Products/Release/FlClash.app"
```

> `authorizeCore()` (system.dart:88-100) 已更新为使用 `ln -f` 代替 `mv -f` 来自动完成此操作。

> **注意**：group 必须是 `admin`（不是 `wheel`）。Flutter 端 `checkIsAdmin()` 检查 `root:admin` 才认为已授权，否则每次开关 TUN 都会弹密码框并阻塞 `updateConfig` 命令。

如果手动替换 app bundle 中的二进制文件，需要重新签名：

```bash
codesign --force --sign - "FlClash.app/Contents/MacOS/FlClashCore"
```

完整替换命令（一次性完成）：

```bash
BINARY="build/macos/Build/Products/Release/FlClash.app/Contents/MacOS/FlClashCore"
cp "$BINARY" /tmp/FlClashCore
sudo chown root:admin /tmp/FlClashCore && sudo chmod u+s,g+s /tmp/FlClashCore
rm "$BINARY"
ln /tmp/FlClashCore "$BINARY"
codesign --force --sign - "build/macos/Build/Products/Release/FlClash.app"
```

### macOS TUN 调试

Go 核心的 mihomo logger 输出到 `os.Stdout`，但 Flutter 端丢弃了 stdout（`_process?.stdout.listen((_) {})`），只监听 stderr。这导致 TUN 错误日志在 Flutter 日志中不可见。两种解决方法：

1. 修改 `core/Clash.Meta/log/log.go:19`：`log.SetOutput(os.Stdout)` → `log.SetOutput(os.Stderr)`
2. 或在关键路径加文件日志：`os.OpenFile("/tmp/flclash_tun_debug.log", ...)`

TUN 创建链路：`updateConfig()` → `updateListeners()` → `listener.ReCreateTun()` → `sing_tun.New()`。静默失败点在 `ReCreateTun` 的 defer 中（错误只记 log，不返回给 Flutter）。

### `_requestAdmin` 阻塞 Bug

`lib/providers/action.dart:350` 的 `_requestAdmin` 在首次 TUN 切换时存在逻辑问题：
- 首次开 TUN → `checkIsAdmin()` 返回 false → `authorizeCore()` → `success` → `restartCore()` → `return Result.error('')` → **`updateConfig` 被跳过**
- `restartCore()` 内部会 `applyProfile(force: true)` 重新生成 YAML，此时 `patchConfig.tun.enable=true`，**第二次** `_requestAdmin` 成功，所以 profile 加载时 TUN 最终会启用
- 前提是 setuid 已正确设置为 `root:admin`，否则 `checkIsAdmin()` 永远返回 false，`authorizeCore()` 反复弹密码框
