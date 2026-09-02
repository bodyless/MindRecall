## 目标

应用版本为唯一源 `pubspec.yaml` 顶层 `version:`，格式 `大.小.迭代`（基线 `0.0.2`，无 `+buildNumber`）。APK 文件名与设置面板只展示该三段。之后每次成功的 `mode-patch` 将迭代 +1；每次 `mode-implement` 将某一方案全部勾完后将小版本 +1、迭代置 0。大版本不由 AI 改。落实本方案本身保持 `0.0.2`，不额外升版。

## 方案

- 把 `pubspec.yaml` 顶层 `version` 改为 `0.0.2`，去掉 `+1`；注释改为只说明三段式，不再提 `+buildNumber`。
- `MemoEditorScreen._loadAppVersionLabel` 只把 `PackageInfo.version` 赋给 `_appVersionLabel`，不再拼接 `buildNumber`。APK 已用 `variant.versionName`，不改 Gradle 模板。
- 在 `.cursor/skills/mode-patch/SKILL.md` 与 `mode-implement/SKILL.md` 写入升版收尾：只改 `pubspec.yaml` 顶层 `version:` 行（三个非负整数，无 `+`）；patch 成功则迭代 +1；implement 该方案全部勾完则小版本 +1 且迭代 = 0；不改大版本。停手、未跑通门禁、explore / propose / archive 不升。
- README 写明唯一源、展示面、升版规则；测试锁格式与「设置不拼 buildNumber」，不写死具体数字。
- 本方案 implement 收尾禁止再升小版本，保持 `0.0.2`。

## 已决事项

- 包体命名与设置面板只展示三段式版本号，不展示 `buildNumber`。
- 不需要 `buildNumber`：不维护、不随升版增减 `+N`，不为 Android `versionCode` 另做推导。
- 一次成功的 `mode-patch` 将迭代 +1。
- 一次 `mode-implement` 在该方案 `tasks.md` 全部勾完之后，将小版本 +1、迭代置 0。
- 只允许 `mode-patch` 与 `mode-implement` 改版本号。
- 大版本仅当用户明确要求或用户手改；AI 不处理。
- explore / propose / archive 及其余路径不改版本号。
- 当前基线为 `0.0.2`；落地本约定的这一次 implement 不额外升版。

## 关注点

- 只改 `pubspec.yaml` **顶层** `version:`，不要动 `dependencies` 里的包版本。
- 不要在 `lib/app_config.dart`、Gradle、Windows `Runner.rc` fallback 再写一份产品版本。
- 不要改 `android/app/build.gradle.kts` 的 APK 文件名模板（已用 `versionName`）。
- Flutter 仍可能给原生一个默认 `versionCode`；忽略即可，不要补 `+N` 或公式。
- 测试只断言 `version:` 为 `大.小.迭代`、设置赋值不含 `buildNumber`、技能含升版句；不要 `expect` 写死 `0.0.2`（否则随后一次 patch 会红）。
- patch：短方案即使没点名 `pubspec.yaml`，成功交付后仍要改迭代位；停手或门禁未过则不改。
- implement：升版是技能收尾，不要写进被落实方案的 `tasks.md`；中途缺口停手不升。
- 落实**本方案**时：技能条文写好后，勾完仍保持 `0.0.2`，不要执行刚写入的 implement 升版。

## 未决事项

- （无）
