---
paths:
  - "{{FRONTEND_GLOB}}"
---

# Front-end standards

**Tokens.** Colour, spacing, radius, shadow and type scale come from
`{{TOKEN_FILE}}`. A literal hex, px or rem in a component is a review blocker.

**States.** Every interactive element implements default, hover, focus-visible,
active, disabled, loading and error. Every collection implements empty and
error states.

**Responsive.** Breakpoints 390 / 768 / 1024 / 1280 / 1536. Mobile is a
designed layout, not a narrowed desktop. No horizontal scroll at 320px.
Touch targets at least 44x44px.

**Accessibility.** WCAG 2.2 AA. Semantic HTML before ARIA. Visible focus
everywhere. Contrast 4.5:1 for body text, 3:1 for large text and UI
boundaries. All motion respects `prefers-reduced-motion`.

**Performance.** LCP <= 2.5s, INP <= 200ms, CLS <= 0.1 on a mid-tier mobile
profile. Images get explicit dimensions, modern formats, lazy below the fold.

**SEO.** One h1 per page with correct heading order. Title and meta
description per route. Canonical URL. Open Graph tags. JSON-LD where the page
type warrants it. Navigation crawlable without JavaScript.
