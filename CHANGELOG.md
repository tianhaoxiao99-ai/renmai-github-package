# Changelog

This file separates **application version history** from **repository presentation updates** so the public GitHub page stays clear.

本文件将**应用版本更新**与**仓库展示更新**分开记录，避免把产品版本和 README 装修混在一起。

---

## 2026-04-19 - Repository showcase refresh / 仓库展示升级

### Added

- Added a bilingual root `README.md`.
- Added a screenshot gallery for landing, dashboard, analysis, and gift pages.
- Added a clearer download guide for source, Windows package, and web preview.
- Added a dedicated changelog file for future version tracking.

### Notes

- This update mainly improves repository presentation and onboarding.
- It does **not** claim a new application runtime version beyond `v1.0.0`.

### 中文说明

- 新增中英双语仓库首页 `README.md`
- 新增首页截图展示区
- 新增源码、Windows 包和 Web 预览的下载指引
- 新增独立的版本更新说明文件
- 这次更新主要是仓库展示升级，不代表应用程序本体已经升级到新版本号

---

## 2026-04-15 - Desktop 3 delivery folder added / 补充 Desktop 3 交付归档

### Added

- Added the `desktop_3_renmai` delivery archive into the repository package.
- Kept the main source, Windows build, and web preview together for delivery and reference.

### 中文说明

- 增加 `desktop_3_renmai` 阶段性交付归档目录
- 方便和源码、Windows 可执行包、Web 预览一起统一留档与查看

---

## v1.0.0 - 2026-04-15 - Initial Renmai GitHub package / 首个公开打包版本

### Product baseline

- Flutter desktop application source was packaged into the repository.
- Windows runnable package was included for direct local use.
- Web preview build was included for UI demonstration and lightweight online browsing.

### Functional scope

- Import support for chat files and folders such as `txt`, `html`, `htm`, and `zip`.
- Contact parsing, message organization, and interaction statistics.
- Relationship ranking, activity evaluation, risk hints, and action suggestions.
- Gift recommendation flows based on relationship context.
- Optional AI enhancement with user-configured external model access.
- Local-first handling for imported data, with sensitive config stored locally.

### 中文说明

- 首次整理并公开上传 Flutter 桌面端源码
- 首次提供 Windows 可执行包，支持直接运行
- 首次提供 Web 预览版本，用于演示和结果浏览
- 支持聊天记录文件与目录导入
- 支持联系人归类、关系排序、风险提示、行动建议和礼物建议
- 支持用户自行配置的 AI 增强分析能力
- 整体以本地处理为主，敏感配置走本地安全存储

---

## Version reference / 版本依据

- `source/renmai_src_ascii/pubspec.yaml` currently reports `version: 1.0.0+1`
- Source-side documentation labels the software as `V1.0.0`
- Repository commit history currently starts from `2026-04-15`
