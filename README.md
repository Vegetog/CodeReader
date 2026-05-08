# CodeReader

CodeReader 是一个轻量的 iOS 代码与 Markdown 阅读器。它可以从系统文件选择器打开代码、Markdown 和纯文本文件，提供语法高亮、行号、搜索、字体大小调整、Markdown 预览和最近文件记录，适合在 iPhone 或 iPad 上快速查看与简单编辑文本类文件。

## 功能特性

- 打开代码文件、Markdown 文件和普通 UTF-8 文本文件。
- 代码阅读支持行号、语法高亮和字体大小调整。
- Markdown 支持源码/预览模式切换。
- Markdown 预览支持表格、代码块、图片、引用、KaTeX 数学公式和 Mermaid 图表。
- 支持在当前文件内搜索，并在匹配项之间跳转。
- Markdown 文件支持标题大纲跳转。
- 支持简单编辑并保存回原文件。
- 记录最近打开的文件，方便再次访问。
- 注册系统文档类型，可从其他 App 或文件入口打开支持的文本/源码文件。

## 支持的文件类型

CodeReader 会根据文件扩展名识别内容类型：

- Markdown：`.md`
- 代码：`.swift`、`.c`、`.cpp`、`.h`、`.hpp`、`.java`、`.py`、`.js`、`.ts`、`.kt`、`.rs`、`.go`
- 其他 UTF-8 文本：按纯文本打开

## 环境要求

- Xcode
- iOS 26.1 或更高版本的构建目标
- SwiftUI

当前项目版本配置：

- `MARKETING_VERSION = 1.0`
- `CURRENT_PROJECT_VERSION = 1`

## 本地运行

1. 克隆仓库：

   ```bash
   git clone https://github.com/Vegetog/CodeReader.git
   cd CodeReader
   ```

2. 使用 Xcode 打开项目：

   ```bash
   open CodeReader.xcodeproj
   ```

3. 在 Xcode 中选择 `CodeReader` scheme。

4. 选择 iOS Simulator 或真机后运行。

## 项目结构

- `CodeReader/ContentView.swift`：主界面、文件导入、最近文件入口和保存逻辑。
- `CodeReader/FileViewer.swift`：代码、Markdown 和纯文本的阅读/编辑界面。
- `CodeReader/MarkdownWebView.swift`：基于 `WKWebView` 的 Markdown HTML 渲染、KaTeX 和 Mermaid 支持。
- `CodeReader/SyntaxHighlightedText.swift`：源码显示、行号、搜索高亮和大文件阅读优化。
- `CodeReader/RecentFileStore.swift`：最近文件记录和安全书签恢复。
- `mermaid-example.md`：用于验证 Mermaid 渲染效果的示例 Markdown 文件。

## Release

当前首个发布版本为 [v1.0.0](https://github.com/Vegetog/CodeReader/releases/tag/v1.0.0)。

GitHub Release 中提供 source archive。如果需要安装到设备，请使用 Xcode 从源码构建运行。

## License

本项目使用 MIT License。详见 [LICENSE](LICENSE)。
