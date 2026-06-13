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

Finder Go Up（返回上一级）是一款 macOS 轻量工具。安装后可通过右键菜单或启动器触发，在当前访达窗口跳转到父目录，不新开窗口、无 Dock 图标、不抢焦点。

## 功能

- 当前访达窗口跳转至上一级目录
- 后台常驻，触发响应快
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

安装位置：

| 组件 | 路径 |
| --- | --- |
| Daemon | `~/.local/bin/finder-go-up-daemon` |
| Client | `~/.local/bin/finder-go-up-client` |
| App | `~/Applications/返回上一级.app` |

## 使用

安装完成后，将 `~/Applications/返回上一级.app` 绑定到你的启动方式即可。

**iRightMouse Pro**：偏好设置 → 工具箱 → 添加「打开 App」→ 选择上述 App。详见 [docs/irightmouse.md](docs/irightmouse.md)。

首次使用时若系统请求自动化权限，请允许控制 Finder。

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

## 许可证

[MIT](LICENSE)
