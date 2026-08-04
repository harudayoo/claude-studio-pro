---
description: Runs a performance, accessibility, SEO and responsive audit against the running app. Use before closing the verify phase on UI work.
disable-model-invocation: true
---

Audit the current build. Report findings only — fix nothing.

**Performance** — LCP, INP, CLS from a cold load on a mid-tier mobile profile,
against the budget in `.claude/rules/frontend.md`. Largest bundles.
Unoptimised images. Render-blocking resources.

**Accessibility** — run axe. Keyboard traversal of every interactive element.
Focus visibility. Contrast. Heading order. Form labels. `prefers-reduced-motion`.

**SEO** — title and meta description per route with length bounds. One h1,
correct heading order. Canonical. Open Graph. JSON-LD. `sitemap.xml`,
`robots.txt`. Image alt text. Navigation crawlable without JavaScript.

**Responsive** — 320, 390, 768, 1024, 1280, 1536. No horizontal overflow.
Touch targets >= 44px.

Output one table: check, status, evidence path, fix. Rank failures by user
impact, not by category.
