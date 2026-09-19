---
name: project-pack
description: >-
  Build this project's Android APK as mind_recall_<version>_<debug|release>.apk.
  Use when the user names project-pack, or asks to 打包, 打个包, 出包, 打一个release包,
  打个debug包, build apk, or produce a debug/release APK.
---

# project-pack

当用户使用技能输入「打一个release包或者打个debug」包时，自动打包，并且按照命名规范命名为标准包体，例如「mind_recall_0.0.2_release.apk」。

版本取 `pubspec.yaml` 顶层 `version`（`大.小.迭代`，不含 `+buildNumber`）。产物名由 `android/app/build.gradle.kts` 写出，**不要**手工 `rename` / 另存改名。

## 模式

- 明确 debug / Debug → `--debug`
- 明确 release / Release → `--release`
- 只说「打包 / 出包 / 打个包」且未指定 → `--release`
- 两种都要 → 依次打，不要并行（Gradle 锁）

## 包体名

`mind_recall_<versionName>_<debug|release>.apk`

例：`pubspec.yaml` 为 `0.0.2` 且 release → `mind_recall_0.0.2_release.apk`

`<versionName>`：`version:` 行去掉可选 `+buildNumber` 后的整段。

标准包体路径：

`build/app/outputs/flutter-apk/mind_recall_<versionName>_<mode>.apk`

同目录必须仍有 `app-<mode>.apk`（Flutter CLI 别名，内容相同）。**禁止**只保留自定义名。

## 步骤

1. 读 `pubspec.yaml` 的 `version`，算出期望文件名（先报给用户再开打）
2. 在仓库根执行（Windows / Unix 相同；构建可能数分钟，Shell `block_until_ms` 至少 600000）：
   - release：`flutter build apk --release`
   - debug：`flutter build apk --debug`
3. 确认标准包体与 `app-<mode>.apk` 都存在且非空
4. 用中文交付：模式、版本、**标准包体绝对路径**、文件名。失败则贴关键错误，禁止声称打好了

## 禁止

- 改 `pubspec.yaml` 版本号（打包不加版本）
- 改 `android/app/build.gradle.kts` 的 `outputFileName` / 双复制逻辑
- 把 APK / AAB 提交进 git（`*.apk` 已忽略）
- 为打包改业务代码、跑单元测试门禁、或顺手归档 propose
- 未让用户指定就同时打 debug 和 release（仅「都要」时才打两种）
- 打 AAB / iOS / Windows 安装包（本技能只打 Android APK）

## 交付

只汇报标准包体（自定义名），不要把 `app-release.apk` 当成分发文件名。
