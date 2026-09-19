## 步骤 1：唯一源与设置展示

- [x] 在 `pubspec.yaml` 将顶层 `version: 1.0.0+1` 改为 `version: 0.0.2`（无 `+` 与 buildNumber）；
- [x] 在 `pubspec.yaml` 将 `version:` 上方关于 `+` / build-number / versionCode 的英文模板注释，改为中文说明：产品版本仅为 `大.小.迭代`，不使用 `+buildNumber`；
- [x] 在 `lib/features/memo/editor/memo_editor_screen.dart` 的 `_loadAppVersionLabel` 中，将 `_appVersionLabel` 的赋值从 `'${info.version}+${info.buildNumber}'` 改为只使用 `info.version`；

## 步骤 2：技能升版收尾

- [x] 在 `.cursor/skills/mode-patch/SKILL.md` 的「按短方案落实」或「交付」中写明：门禁通过并宣告成功后，读取 `pubspec.yaml` 顶层 `version: 大.小.迭代`（三个非负整数、无 `+`），将迭代 +1 写回该行；短方案未点名 `pubspec.yaml` 也要改这一行；停手或测试未过则不改；不改大版本与小版本；
- [x] 在 `.cursor/skills/mode-implement/SKILL.md` 的「交付」中写明：该方案 `tasks.md` 已全部勾选且工程门禁通过后，读取同一 `version:` 行，将小版本 +1、迭代置 0 后写回；不要把升版写进被落实方案的 `tasks.md`；缺口停手或未全部勾完则不改；不改大版本；
- [x] 在上述两份 SKILL 中写明升版只动 `pubspec.yaml` 顶层 `version:`，不改依赖版本、不添加 `+buildNumber`、不为 `versionCode` 做推导；

## 步骤 3：README

- [x] 在 `README.md`「基本信息」表增加一行：版本唯一源为 `pubspec.yaml` 顶层 `version`（`大.小.迭代`），APK 文件名中的 `versionName` 与设置面板展示同一值；
- [x] 在 `README.md`「其他 UX」设置那条中，将「顶部显示 App 版本」改为说明展示的是上述三段式、不含 buildNumber；
- [x] 在 `README.md`「工作流模式」的 `mode-patch` 条末补充：成功交付后将 `pubspec.yaml` 迭代 +1；
- [x] 在 `README.md`「工作流模式」的 `mode-implement` 条末补充：该方案全部勾完且门禁通过后将小版本 +1、迭代置 0；
- [x] 在 `README.md`「工作流模式」注明 explore / propose / archive 不改版本号，大版本不由 AI 改；

## 步骤 4：测试与目录

- [x] 新增 `test/app_version_test.dart`：读 `pubspec.yaml` 顶层 `version:`，断言匹配 `^\d+\.\d+\.\d+$` 且该行不含 `+`；
- [x] 在 `test/app_version_test.dart` 中读 `lib/features/memo/editor/memo_editor_screen.dart`，断言 `_loadAppVersionLabel` 内赋值使用 `info.version` 且不拼接 `buildNumber`；
- [x] 在 `test/app_version_test.dart` 中读 `.cursor/skills/mode-patch/SKILL.md` 与 `mode-implement/SKILL.md`，断言分别含迭代 +1 与小版本 +1、迭代置 0 的收尾约束；
- [x] 在 `test/settings_panel_test.dart` 新增用例：传入 `appVersionLabel` 为某一 `大.小.迭代` 字符串时，面板显示 `版本 {该字符串}`；
- [x] 在 `README.md` 目录结构的 `test/` 下增加 `app_version_test.dart`；
- [x] 运行 `scripts/run_unit_tests`（Windows 为 `.\scripts\run_unit_tests.ps1`）至通过；

## 步骤 5：本方案不升版

- [x] 本方案全部勾选完成后，确认 `pubspec.yaml` 顶层仍为 `version: 0.0.2`，不要执行步骤 2 写入的 implement 升小版本收尾；
