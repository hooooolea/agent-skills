---
name: ejuerz-blog-writing
description: Write and publish English blog articles for ejuerz.com (AI Toolkit Guide). The site is an Astro 6 blog monetized via Google AdSense — targeting high-RPM AI/tech keywords. Covers content style, frontmatter format, deployment flow, and user preferences.
version: 1.0.0
metadata:
  hermes:
    tags: [blog, content, ejuerz, astro, adsense]
---

# ejuerz Blog Writing & Publishing

Write and publish articles for ejuerz.com, an AI tools blog monetized with Google AdSense.

## Trigger

When the user asks to write, draft, or publish a blog article for their site (ejuerz.com / "AI Toolkit Guide").

## Site Technical Details

- **Framework**: Astro 6 + Tailwind CSS (AstroPaper v6 template)
- **Content path**: `/Users/ejuer/ejuerz-ai-blog/src/content/posts/`
- **File format**: `.md` with YAML frontmatter
- **Auto-deploys**: GitHub push → auto-deploy to ejuerz.com
- **AdSense**: Already configured (`pub-7420993311388251` in `public/ads.txt`)
- **Published articles currently in `src/content/posts/`** — count them with `ls src/content/posts/*.md | wc -l` before claiming a number in README, social copy, or anywhere else. The user caught a "5 English articles" claim when the real count was 3.

## Scope Rule — Main Site Only

The user runs **two distinct properties** from the same Astro project:

- **Main site** (ejuerz.com / "AI Toolkit Guide") — English-only, AdSense-monetized, the only thing this skill covers
- **`/forbtbuer/*` pages** — separate Chinese student-sharing platform (BTBU campus content), explicitly excluded from this skill

**When the user says "this project", "the site", "ejuerz", or "main site", they mean the English blog, NOT `/forbtbuer/`.** Do not reference, edit, or discuss `src/content/btbuer/`, `/forbtbuer/*` routes, `/biyeji`, or `/btbuer-submit` unless the user explicitly opens that scope.

**Chinese content in `src/content/posts/`** (e.g. `article-zh.md` alongside `article-en.md`) is the user's self-only reading copy — never published to ejuerz.com, never promoted. Leave it in the working tree untracked; do NOT add it to git commits.

### Frontmatter Template

```yaml
---
author: "AI Toolkit Guide"
pubDatetime: 2026-06-03
title: "Article Title Here"
featured: true
draft: false
tags: ["AI Tools", "..." ]
description: "One-sentence SEO description."
---
```

### Git / Deploy

```bash
cd /Users/ejuer/ejuerz-ai-blog
git add src/content/posts/article-name.md
git commit -m "add article"
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 \
  git -c http.proxy=http://127.0.0.1:7897 -c https.proxy=http://127.0.0.1:7897 push
```

Git proxy = **7897**, not 7890 (which is for general web). If the push times out, use port 7897.

## Content Style (User Preferences)

The user has repeatedly corrected the writing style. Follow these rules:

1. **Authentic, personal voice** — Write like a real person sharing their experience. "I tried X and Y happened" not "X is a powerful tool that enables users to..."
2. **Not marketing-speak** — Avoid superlatives, buzzwords, "revolutionary", "game-changing", etc.
3. **Short, punchy sentences** — Break up long paragraphs. Use one-sentence lines for emphasis.
4. **Blockquotes for takeaways** — Use `>` for the single most important point in a section.
5. **Real commands and tables** — Include actual CLI commands and comparison tables for credibility.
6. **Honest about limitations** — Say what doesn't work, not just what does.
7. **Point to original sources** — Link to GitHub repos, not just mention them.
8. **Natural hooks** — Open with a specific personal story or moment of realization, not a generic intro.
9. **Kill the setup fluff** — If the setup is "just send this link to your AI", say that in one blockquote. Don't paste three commands and a terminal output.
10. **English-first** — The blog targets US/English-speaking readers for AdSense RPM. Chinese versions are secondary.

## Pitfalls

- **Don't write like official documentation.** The user rejected a feature-list style article and asked to rewrite as personal narrative.
- **Don't over-explain setup steps.** When the user said "把仓库发给ai让他自己配置吧", they wanted zero commands in the article — just the repo link.
- **Don't include both Chinese and English in the same file.** Write separate `-en.md` and `-zh.md` files.
- **Git push needs proxy 7897**, not 7890. 7890 may be down; 7897 is the reliable one for git.
- **Don't claim an article count without `ls`-ing first.** README "5 articles" turned out to be 3. Always count before writing the number.
- **Don't edit `src/content/btbuer/`, `/forbtbuer/*`, `/biyeji`, or `/btbuer-submit`** unless the user explicitly opens the forbtbuer scope. See "Scope Rule" above.

## Bilingual README Pattern (en + zh)

When the user asks to rewrite or add the GitHub repo README (separate from the blog site's `Layout.astro`), the project's convention is:

- **Two files**: `README.md` (English) + `README.zh.md` (中文)
- **Language switcher header on line 1 of BOTH files**:
  ```
  [English](README.md) | [中文](README.zh.md)
  ```
  English file's own line uses `English` as the link text; Chinese file's line uses `中文`. GitHub won't auto-detect `.zh.md` as a translation — the manual switcher is required.
- **Project-specific content only** — replace upstream template READMEs (e.g. AstroPaper's stock README) with the actual project's description, features, and links
- **Footer**: name + MIT license note + project-specific link (ejuerz.com, GitHub repo URL, maintainer contact)

## Screenshot Inclusion Pattern

When the user provides a screenshot (e.g. "截图可以cp到文件夹，我们放readme"):

1. **Path**: `assets/blog-preview.png` (or `assets/<descriptive-name>.png`)
2. **Commit it to git** — screenshots for README are not generated by the build, they must be in the repo
3. **Reference syntax** in README:
   ```
   ![Blog write-up on ejuerz.com](assets/blog-preview.png)
   ```
4. **Placement**: typically right after the subtitle tagline, before the first H2
5. **Add to BOTH** `README.md` and `README.zh.md` — bilingual coverage

## Download-Source Coordination (blog ↔ skill repo)

When the user creates a **dedicated GitHub repo for a SKILL.md** (e.g. `hooooolea/agent-session-summary`), the blog post's download links need to be checked:

- Blog posts reference `/downloads/skill-name.md` (served from `public/downloads/`) for skill file downloads
- Once a GitHub repo exists for that skill, the **canonical download source becomes the GitHub raw URL**:
  ```
  https://raw.githubusercontent.com/hooooolea/<repo-name>/main/SKILL.md
  ```
- Old `public/downloads/<name>.md` files may stay as a fallback, or be removed — ask the user, don't decide silently
- The blog post and the GitHub repo's `SKILL.md` can drift in content (e.g. blog has an older verbose version, repo has a tighter rewrite). Surface the drift to the user, don't auto-merge.
