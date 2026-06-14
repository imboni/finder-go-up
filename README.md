# finder-go-up

在访达当前窗口返回上一级目录。

## 安装

1. 打开 `finder-go-up.dmg`
2. 将 **finder-go-up** 拖到 **Applications**
3. 打开 App → **授权并试用** → 允许 → **完成**

## 使用

- 选中任意项目 → 右键 → 服务 → **返回上一级**
- 快捷键 **⌃⌘↑**

## 第三方接入

```bash
finder-go-up
open finder-go-up://go-up
```

CLI（可选）：

```bash
sudo ln -sf ~/Applications/finder-go-up.app/Contents/MacOS/finder-go-up-client /usr/local/bin/finder-go-up
```

## 重新打开设置

```bash
open -a ~/Applications/finder-go-up.app --args --show
```

## 卸载

删除 `~/Applications/finder-go-up.app` 即可。

## 构建

```bash
make package   # → dist/finder-go-up-0.0.1.dmg
```

要求 macOS 13+
