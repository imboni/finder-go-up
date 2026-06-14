# finder-go-up

在访达当前窗口返回上一级目录。

## 安装

```bash
git clone git@github.com:imboni/finder-go-up.git
cd finder-go-up
bash scripts/install.sh
```

安装后按引导窗口完成授权（约 10 秒）。之后无需打开 App，无后台进程。

## 使用

**右键菜单：** 选中任意项目 → 右键 → 服务 → 返回上一级

**快捷键：** ⌃⌘↑（Control + Command + ↑）

## 第三方接入

命令行（安装后可用）：

```bash
finder-go-up
# 或
open finder-go-up://go-up
```

| 工具 | 配置 |
|------|------|
| iRightMouse | 添加 Shell 脚本，命令 `finder-go-up` |
| Keyboard Maestro | 执行 Shell 脚本 `finder-go-up` |
| Raycast / Alfred | 运行 `open finder-go-up://go-up` |
| Shortcuts | 运行 Shell 脚本 `finder-go-up` |

## 重新打开设置

```bash
open -a ~/Applications/finder-go-up.app --args --show
```

## 卸载

```bash
bash scripts/uninstall.sh
```

## 要求

macOS 13+，Xcode Command Line Tools
