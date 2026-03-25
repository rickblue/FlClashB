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
