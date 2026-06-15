# finder-go-up

在访达当前窗口返回上一级目录。

## 安装

1. 打开 `finder-go-up.dmg`
2. 将 **finder-go-up** 拖到 **Applications**
3. 首次打开 App → 点击 **允许控制访达** → **完成**

App 会在后台保持运行，右键服务即可使用。之后再次打开 App 不会出现界面。

## 使用

- 选中任意项目 → 右键 → 服务 → **返回上一级**
- 快捷键 **⌃⌘↑**（若无效，到 **系统设置 → 键盘 → 键盘快捷键 → 服务** 中启用）

## 重新打开设置

```bash
open -a ~/Applications/finder-go-up.app --args --show
```

设置界面包含：授权状态、第三方接入说明、自动检查更新、产品信息与 GitHub 链接。

## 第三方接入

```bash
finder-go-up
open finder-go-up://go-up
```

CLI（可选）：

```bash
sudo ln -sf ~/Applications/finder-go-up.app/Contents/MacOS/finder-go-up-client /usr/local/bin/finder-go-up
```

## 卸载

```bash
bash scripts/uninstall.sh
```

## 构建

```bash
make package   # → dist/finder-go-up-0.0.3.dmg
```

要求 macOS 13+
