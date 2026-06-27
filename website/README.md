# Finder-go-up 官网

静态落地页，部署到 GitHub Pages。

- 中文：https://imboni.github.io/finder-go-up/
- English：https://imboni.github.io/finder-go-up/en/

## 本地预览

```bash
# 直接打开
open index.html

# 或启动本地服务器（推荐，避免相对路径问题）
python3 -m http.server 8080
# 访问 http://localhost:8080
```

## 自动部署

推送 `main` 分支且 `website/` 有变更时，[`.github/workflows/pages.yml`](../.github/workflows/pages.yml) 会自动部署。

**首次启用 GitHub Pages：**

1. 打开仓库 **Settings → Pages**
2. **Build and deployment → Source** 选择 **GitHub Actions**
3. 推送包含 `website/` 的 commit 到 `main`，或手动触发 **Actions → Deploy website → Run workflow**

部署完成后，站点地址为 `https://<owner>.github.io/finder-go-up/`。

## 目录结构

```
website/
├── index.html       # 中文版
├── en/index.html    # 英文版
├── styles.css       # 共享样式
├── assets/logo.png  # 应用图标
└── .nojekyll        # 禁用 Jekyll 处理
```

更新应用版本号时，同步修改两个 `index.html` 中的 `hero-hint` 行。
