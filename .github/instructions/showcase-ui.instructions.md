<!-- HAND-AUTHORED — path-scoped instructions for the showcase UI. -->
---
description: "Design-system and accessibility rules for the showcase UI"
applyTo: "app/public/**"
---

# Showcase UI conventions (`app/public/**`)

- Read and follow root [`DESIGN.md`](../../DESIGN.md) before editing UI files.
- Reuse CSS custom-property tokens from `app/public/styles.css`; do not add raw
  color, spacing, radius, or timing values inside component rules.
- Keep HTML, CSS, and ESM JavaScript in separate files. Never add inline
  script/style or loosen the same-origin CSP to make a UI change work.
- Use semantic landmarks, ordered headings, a visible skip link, visible focus,
  44px minimum targets, and text labels for every status.
- Render live state from `/health` and `/api/info`. Loading and failures must be
  visible; never convert an unknown or failed request into a success state.
- Do not use `innerHTML`, external fonts/CDNs, frameworks, icon packages, or
  decorative data that implies measurements the APIs do not provide.
- Verify desktop and 320px-wide layouts, keyboard navigation, 200% zoom, and
  `prefers-reduced-motion` after material changes.
