# 仁迈 GitHub 上传包

这个文件夹已经按 GitHub 上传和交付查看整理好。

## 目录结构

- `source/renmai_src_ascii`
  - Flutter 桌面端源码。
  - 已排除 `.dart_tool`、`build`、`output`、`windows/flutter/ephemeral` 等本地缓存和构建目录。

- `windows/renmai_windows`
  - Windows 可运行包。
  - 双击 `renmai.exe` 运行。
  - 已保留运行所需的 `data`、DLL 和导入脚本。
  - 未包含 `RenmaiData` 本地数据目录，避免把本机使用数据上传到 GitHub。

- `web/renmai_web_preview`
  - Web 预览版本。
  - 可打开 `index.html` 查看。

## 上传建议

- 如果要放进 GitHub 仓库，可以直接上传这个包内的三个目录。
- 如果只想维护源码仓库，优先上传 `source/renmai_src_ascii`。
- 如果要分发 Windows 程序，建议把 `windows/renmai_windows` 作为 Release 附件。
- 如果要展示网页预览，上传 `web/renmai_web_preview` 到静态托管或仓库目录。

## 检查结果

- 当前包没有单个超过 GitHub 100MB 限制的文件。
- 当前包没有包含 `RenmaiData` 本地使用数据。
