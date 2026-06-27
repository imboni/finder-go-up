# Finder-go-up

在访达当前窗口返回上一级目录。

**官网**：[imboni.github.io/finder-go-up](https://imboni.github.io/finder-go-up/) · [English](https://imboni.github.io/finder-go-up/en/)

## 安装

1. 从 [Releases](https://github.com/imboni/finder-go-up/releases) 下载 `finder-go-up-0.0.3.dmg`
2. 将 **Finder-go-up** 拖到 **Applications**
3. 打开 App 一次；若系统提示，**允许控制「访达」**

安装后 App 在后台保持运行（活动监视器中显示为 `finder-go-up`），供服务菜单与快捷键使用。**再次打开 App 不会出界面，直接返回上一级。**

## 使用

- **打开 App** → 立即返回上一级
- 选中任意项目 → 右键 → 服务 → **返回上一级**
- 快捷键 **⌃⌘↑**（若无效，到 **系统设置 → 键盘 → 键盘快捷键 → 服务** 中启用）

### 超级右键（iRightMouse Pro）

1. **iRightMouse Pro → 偏好设置 → 工具箱 → 打开 App**
2. 选择 **`~/Applications/Finder-go-up.app`**
3. 名称设为 **返回上一级**，保存后重启 iRightMouse Pro

详见 [docs/integrations/irightmouse.md](docs/integrations/irightmouse.md)

## 第三方接入

```bash
finder-go-up
open finder-go-up://go-up
open ~/Applications/Finder-go-up.app
```

CLI（源码安装后位于 `~/.local/bin/finder-go-up`；亦可手动链接）：

```bash
sudo ln -sf ~/Applications/Finder-go-up.app/Contents/MacOS/finder-go-up-client /usr/local/bin/finder-go-up
```

## 卸载

```bash
bash scripts/uninstall.sh
```

## 开发

```bash
make
bash scripts/install.sh
make package   # dist/finder-go-up-0.0.3.dmg
```

## 更新日志

见 [docs/CHANGELOG.md](docs/CHANGELOG.md)
