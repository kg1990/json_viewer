# 自定义域名接入指南 / Custom Domain Setup

当前站点已免费托管在 GitHub Pages：**https://kg1990.github.io/json_viewer/**

如果你购买一个自定义域名，可以把它指向同一个站点（依然免费托管，GitHub 还会自动签发免费 HTTPS 证书）。下面是完整步骤。

---

## 1. 选什么域名（建议）

| 域名 | 说明 |
|------|------|
| `jsonviewer.app` | `.app` 由 Google 运营，**强制 HTTPS**，非常适合 app 落地页（GitHub Pages 提供 HTTPS，完全兼容）。~$12–14/年 |
| `getjsonviewer.com` / `jsonviewer.tools` | 常规选择，记忆度好 |
| `jsonviewer.dev` | 同样强制 HTTPS，开发者向 |

> 可用性请到注册商搜索框实时确认（我无法保证某个域名此刻是否已被注册）。

**注册商建议**（按性价比）：
- **Cloudflare Registrar** — 按成本价卖，无溢价、无续费陷阱；但要求把域名 DNS 托管在 Cloudflare（支持 CNAME flattening，apex 域名也能指向 Pages）。
- **Porkbun** — `.app`/`.dev` 价格便宜，界面清爽。
- **Namecheap** — 老牌，第一年便宜。

---

## 2. 把域名指向 GitHub Pages

### 方式 A：用子域名（最简单，推荐）
例如 `www.你的域名.com` 或 `app.你的域名.com`：

在注册商 DNS 里加一条 **CNAME** 记录：

```
类型: CNAME
主机/Name: www        (或 app)
值/Target: kg1990.github.io
```

### 方式 B：用根域名（apex，例如 `你的域名.com`）
加 **4 条 A 记录**（IPv4）指向 GitHub Pages：

```
A  @  185.199.108.153
A  @  185.199.109.153
A  @  185.199.110.153
A  @  185.199.111.153
```

可选再加 IPv6（AAAA）：

```
AAAA  @  2606:50c0:8000::153
AAAA  @  2606:50c0:8001::153
AAAA  @  2606:50c0:8002::153
AAAA  @  2606:50c0:8003::153
```

> 若用 Cloudflare 托管 apex，直接加一条 `CNAME @ kg1990.github.io`，Cloudflare 会自动做 CNAME flattening。
> 这些 IP 是 GitHub Pages 长期使用的地址，接入前可对照官方文档 https://docs.github.com/pages 再次确认。

---

## 3. 在仓库里绑定域名

两种任选其一：

- **网页操作**：仓库 → Settings → Pages → "Custom domain" 填入你的域名 → Save。GitHub 会自动在 `docs/` 下生成一个 `CNAME` 文件。
- **命令行**：在 `docs/` 下创建文件 `CNAME`，内容只有一行你的域名，然后提交：
  ```bash
  echo "你的域名.com" > docs/CNAME
  git add docs/CNAME && git commit -m "chore: set custom domain" && git push
  ```

DNS 生效后（几分钟到 ~1 小时），回到 Settings → Pages 勾选 **"Enforce HTTPS"**。

---

## 4. 换域名后要同步更新的地方（重要，关系到 SEO）

站点里有几处写死了 `https://kg1990.github.io/json_viewer/`，换正式域名后应改成新域名，否则 SEO 的 canonical 会指错：

- `docs/index.html`：`<link rel="canonical">`、`og:url`、`og:image`、JSON-LD 里的 `url`/`downloadUrl`
- `docs/sitemap.xml`：`<loc>`
- `docs/robots.txt`：`Sitemap:` 行
- `docs/llms.txt`：里面的站点 URL

可以让我在你买好域名后一次性批量替换并重新部署。

---

## 5. 额外的免费提交渠道（增加曝光 / 利于 SEO·GEO）

部署后可手动提交到这些地方，加速被搜索引擎和 AI 答案引擎收录：

- **Google Search Console** / **Bing Webmaster Tools** — 提交 sitemap，验证站点
- **GitHub Topics** — 给仓库加 `json`、`macos`、`swiftui`、`developer-tools` 等 topic
- 开发者目录：**AlternativeTo**、**Product Hunt**、**Hacker News (Show HN)**、**awesome-mac** / **awesome-macos** 等 GitHub 收录列表
- 这些站点的反向链接会显著提升搜索与 AI 引擎对站点的可信度
