---
paths:
  - "{{FRONTEND_ROOT}}/**"
  - "**/*.html"
  - "**/sitemap*.xml"
  - "**/robots.txt"
---

# SEO standards

This is a checklist, not a reasoning problem, which is why `seo-auditor` runs on
the cheap model tier. Every item is either present or it is not.

**Title and meta description.** One per route, unique across routes. Title
roughly 50–60 characters, description roughly 140–160. A route that inherits the
site-wide default is a finding.

**Headings.** Exactly one `h1` per page. No skipped levels. The heading outline
should read as a table of contents for the page — heading tags are structure,
not a font size shortcut.

**Canonical URL.** Present and absolute on every indexable route,
self-referencing unless the route is a deliberate duplicate.

**Social cards.** Open Graph and Twitter card tags: title, description, image,
type. The `og:image` must resolve — a card image that 404s is worse than none.

**Structured data.** JSON-LD appropriate to the page type (Article, Product,
FAQ, Breadcrumb, Organization). It must validate, and it must describe what is
actually on the page. Marking up content that is not visible is a penalty risk,
not a shortcut.

**Sitemap and robots.** Every new indexable route appears in `sitemap.xml`.
Every exclusion in `robots.txt` is deliberate and stated. A `noindex` shipped
from staging is the single most common own goal here — check it before release.

**hreflang.** If the site is multilingual, every route declares its alternates,
including a self-reference and `x-default`.

**Images.** Descriptive `alt` on content images; empty `alt` on decorative ones.
Explicit dimensions and a modern format. Lazy-load below the fold only.

**Crawlability.** Primary navigation is reachable without executing JavaScript.
Content that only exists after hydration is content that may never be indexed.
No orphan pages — something links to every indexable route.

**URLs.** Lowercase, hyphenated, stable. A changed URL ships a 301. Query
parameters that do not change the content are canonicalised away.

**Core Web Vitals.** LCP ≤ 2.5s, INP ≤ 200ms, CLS ≤ 0.1 on a mid-tier mobile
profile. These are shared with `.claude/rules/frontend.md` and measured by
`perf-a11y-auditor` — read that number rather than measuring a second one.
