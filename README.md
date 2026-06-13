<div align="center">

<img src="assets/logo.png" width="96" alt="finder-go-up">

# finder-go-up

**在当前访达窗口一键返回上一级目录**

*Go to the parent folder in the current Finder window.*

<br>

[![macOS](https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

<br>

## 简介

finder-go-up 是一款独立的 macOS 轻量工具。安装后自动注册访达右键菜单，并在首次启动时引导完成配置。

## 功能

- 访达右键菜单 **finder-go-up**
- 首次安装引导界面
- 后台常驻，响应快
- 登录后自动启动
- 一条命令安装与卸载

## 要求

- macOS 13 或更高版本
- Xcode Command Line Tools（`xcode-select --install`）

## 安装

```bash
git clone git@github.com:imboni/finder-go-up.git
cd finder-go-up
bash scripts/install.sh
```

安装完成后会自动打开 **finder-go-up** 引导窗口，按提示完成配置即可。

| 组件 | 路径 |
| --- | --- |
| App | `~/Applications/finder-go-up.app` |
| Daemon | `~/.local/bin/finder-go-up-daemon` |
| Client | `~/.local/bin/finder-go-up-client` |

## 使用

1. 打开访达，在窗口空白处 **右键 → finder-go-up**
2. 若未看到菜单项：**系统设置 → 键盘 → 键盘快捷键 → 服务**，勾选 **finder-go-up**
3. 也可随时打开 `~/Applications/finder-go-up.app` 查看说明或试用

## 卸载

```bash
bash scripts/uninstall.sh
```

## 开发

```bash
bash scripts/build.sh    # 仅构建
make install             # 构建并安装
make package             # 打发布包
make clean               # 清理 build/
```

## 可选集成

第三方右键工具（如 iRightMouse Pro）见 [docs/irightmouse.md](docs/irightmouse.md)。

## 许可证

[MIT](LICENSE)
