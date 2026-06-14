# finder-go-up

在访达当前窗口返回上一级目录。

## 安装

1. 下载 [Releases](https://github.com/imboni/finder-go-up/releases) 中的 `finder-go-up.app.zip`
2. 解压，将 `finder-go-up.app` 拖入「应用程序」
3. 打开 App，点「授权并试用」→ 允许 →「完成」

无后台进程。之后直接在访达中使用即可。

## 使用

- **右键菜单：** 选中任意项目 → 右键 → 服务 → 返回上一级
- **快捷键：** ⌃⌘↑

## 第三方接入

```bash
finder-go-up
open finder-go-up://go-up
```

| 工具 | 配置 |
|------|------|
| iRightMouse | Shell 脚本：`finder-go-up` |
| Keyboard Maestro | 执行 `finder-go-up` |
| Raycast / Alfred | `open finder-go-up://go-up` |

安装 CLI（可选）：

```bash
sudo ln -sf ~/Applications/finder-go-up.app/Contents/MacOS/finder-go-up-client /usr/local/bin/finder-go-up
```

## 重新打开设置

```bash
open -a ~/Applications/finder-go-up.app --args --show
```

## 卸载

删除 `~/Applications/finder-go-up.app`，并移除 `~/Library/Application Support/finder-go-up`。

## 从源码构建

```bash
git clone git@github.com:imboni/finder-go-up.git
cd finder-go-up
bash scripts/install.sh
```

要求：macOS 13+
