---
paths:
  - "{{FRONTEND_GLOB}}"
---

# Front-end standards

**Tokens.** Colour, spacing, radius, shadow and type scale come from
`{{TOKEN_FILE}}`. A literal hex, px or rem in a component is a review blocker.

**Design tooling writes tokens, not components.** Any design skill, plugin or
generator in use produces the *system* — palette, scale, radii, easings — and
that output lands in `{{TOKEN_FILE}}`, or in `docs/specs/<slug>/design.md` as a
proposed token. It never lands as a literal in a component. A generated
component carrying raw values is the same review blocker as a hand-written one;
where the value came from is not a defence.

**Design exploration lives outside the protected source roots.** Scratch
routes, playgrounds and tool-generated drafts are not deliverables. Nothing in a
sandbox directory ships, and real source must not import from one.

**States.** Every interactive element implements default, hover, focus-visible,
active, disabled, loading and error. Every collection implements empty and
error states.

**Responsive.** Breakpoints 390 / 768 / 1024 / 1280 / 1536. Mobile is a
designed layout, not a narrowed desktop. No horizontal scroll at 320px.
Touch targets at least 44x44px. A data table that just overflows silently
below its breakpoint is a defect, not an acceptable tradeoff — it needs a
designed fallback (stacked cards, a reduced column set, or horizontal scroll
with a visible affordance).

**Accessibility.** WCAG 2.2 AA. Semantic HTML before ARIA. Visible focus
everywhere. Contrast 4.5:1 for body text, 3:1 for large text and UI
boundaries. All motion respects `prefers-reduced-motion`.

**Performance.** LCP <= 2.5s, INP <= 200ms, CLS <= 0.1 on a mid-tier mobile
profile. Images get explicit dimensions, modern formats, lazy below the fold.

**SEO.** One h1 per page with correct heading order. Title and meta
description per route. Canonical URL. Open Graph tags. JSON-LD where the page
type warrants it. Navigation crawlable without JavaScript.
