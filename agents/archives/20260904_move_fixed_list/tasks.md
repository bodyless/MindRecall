## 步骤 1：迁固定清单

- [x] 将仓库根目录 `fixed_list.md` 移动到 `agents/fixed_list.md`（若 `agents/` 不存在则先新建该目录），正文内容保持不变；
- [x] 在 `.cursor/rules/fixed-bugs.mdc` 的「## 文件」段，将「仓库根目录：`fixed_list.md`」改为「`agents/fixed_list.md`」；
- [x] 在 `.cursor/rules/fixed-bugs.mdc` 的「修复新 Bug 之前」步骤 1，将 Read 路径 `fixed_list.md` 改为 `agents/fixed_list.md`；
- [x] 在 `.cursor/rules/project-standards.mdc` 的「## 5. 已修复 Bug 清单」段，将「写入仓库根目录 `fixed_list.md`」改为「写入 `agents/fixed_list.md`」；
- [x] 在 `README.md` 的目录结构 `agents/` 树下，于 `proposes/` 与 `archives/` 旁新增一行 `fixed_list.md` 及注释「已修复 Bug 台账」；
- [x] 在 `README.md` 的「易踩坑」权威清单段，将「仓库根目录 [`fixed_list.md`](fixed_list.md)」改为「[`agents/fixed_list.md`](agents/fixed_list.md)」；
- [x] 在 `README.md` 的易踩坑第 25 条，将「见 `fixed_list.md`」改为「见 `agents/fixed_list.md`」；
- [x] 在 `README.md` 的「修改后必须」第 3 条，将链接 [`fixed_list.md`](fixed_list.md) 改为 [`agents/fixed_list.md`](agents/fixed_list.md)；
- [x] 在 `.cursor/skills/mode-propose/SKILL.md` 的「禁止」段，将工程目录示例中的 `fixed_list.md` 改为 `agents/fixed_list.md`；
- [x] 在 `.cursor/skills/mode-implement/SKILL.md` 的「按计划落实」段，将两处 `fixed_list.md` 均改为 `agents/fixed_list.md`；
