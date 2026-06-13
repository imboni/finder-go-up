<div align="center">

<img src="assets/logo.png" width="96" alt="Finder Go Up">

# Finder Go Up

**在当前访达窗口一键返回上一级目录**

*Go to the parent folder in the current Finder window.*

<br>

[![macOS](https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

<br>

## 简介

Finder Go Up 是一款独立的 macOS 轻量工具。安装后自动注册访达右键菜单，在当前窗口跳转到父目录——不新开窗口、无 Dock 图标、不抢焦点。

## 功能

- 访达右键菜单 **返回上一级**
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

安装完成后，在访达窗口空白处 **右键 → 返回上一级** 即可使用。

若未看到菜单项，打开 **系统设置 → 键盘 → 键盘快捷键 → 服务**，确认 **返回上一级** 已启用，然后重启访达（按住 ⌥ 点击访达图标 → 重新开启）。

首次使用时若系统请求自动化权限，请允许控制 **Finder**。

## 卸载

```bash
bash scripts/uninstall.sh
```

## 开发

```bash
bash scripts/build.sh    # 仅构建
make install             # 构建并安装
make clean               # 清理 build/
```

## 可选集成

如需放入第三方右键工具（如 iRightMouse Pro），见 [docs/irightmouse.md](docs/irightmouse.md)。

## 许可证

[MIT](LICENSE)
