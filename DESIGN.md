<!-- HAND-AUTHORED — enforceable visual source for the showcase UI. -->

# Showcase UI design system

This document is the enforceable visual source for `app/public/**`. Agents
must read it before changing the showcase UI, reuse the CSS custom properties
defined in `app/public/styles.css`, and preserve the accessibility and content
contracts below.

## Visual theme and atmosphere

The product is an **enterprise control plane** for an agentic software delivery
system. It should feel calm, exact, operational, and trustworthy:

- Ink and navy surfaces establish depth without becoming decorative.
- GitHub green communicates healthy repository state.
- Azure blue communicates cloud trust, telemetry, and deployment state.
- Status is always conveyed by text and shape as well as color.
- Dense operational information is grouped into clear panels with generous
  internal spacing.

The UI is original to this starter pack. Do not copy another product's layout,
iconography, type treatment, or distinctive trade dress.

## Color palette and semantic roles

Use these exact values through CSS custom properties; do not introduce raw
color literals in component rules.

| Token | Hex | Role |
| --- | --- | --- |
| `--color-canvas` | `#07111F` | Page background |
| `--color-surface` | `#0D1B2A` | Primary panel |
| `--color-surface-raised` | `#13263A` | Elevated cards |
| `--color-surface-hover` | `#18304A` | Interactive hover |
| `--color-border` | `#2B4058` | Default borders |
| `--color-border-strong` | `#48647F` | Emphasized boundaries |
| `--color-text` | `#F4F7FB` | Primary text |
| `--color-text-muted` | `#AFC0D4` | Secondary text |
| `--color-text-subtle` | `#8296AD` | Tertiary labels |
| `--color-github-green` | `#3FB950` | Healthy/repository signal |
| `--color-azure-blue` | `#4CC2FF` | Azure/trust signal |
| `--color-warning` | `#F2CC60` | Pending/degraded signal |
| `--color-danger` | `#FF7B72` | Error signal |
| `--color-focus` | `#79C0FF` | Focus ring |

Primary copy uses `--color-text` on ink/navy. Muted copy must never be placed
on anything lighter than `--color-surface-raised`. Small text never uses
`--color-text-subtle` below 14px. Green, blue, warning, and danger are accents,
not body-text colors.

## Typography hierarchy

Use only the local system stack:

```css
system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif
```

Use the local monospace stack for commands and machine values:

```css
"SFMono-Regular", Consolas, "Liberation Mono", monospace
```

| Style | Size | Weight | Line height |
| --- | --- | --- | --- |
| Display | `clamp(2.5rem, 7vw, 5.75rem)` | 700 | 0.98 |
| H2 | `clamp(1.75rem, 4vw, 3rem)` | 700 | 1.08 |
| H3 | `1.125rem` | 650 | 1.3 |
| Body large | `1.125rem` | 400 | 1.7 |
| Body | `1rem` | 400 | 1.65 |
| Label | `0.75rem` | 700 | 1.4, uppercase, tracked |
| Machine | `0.875rem` | 500 | 1.6 |

Headings use tight letter spacing and short lines. Body copy is capped near
70 characters. Never use all caps for sentences.

## Component styling and states

### Buttons and links

- Minimum interactive target: 44px by 44px.
- Primary actions use Azure blue with ink text.
- Secondary actions use a transparent surface and a strong border.
- Hover raises contrast; active returns to the base elevation.
- Focus uses a 3px `--color-focus` outline with 3px offset.
- Disabled controls retain readable text and expose `aria-disabled`.

### Status pills

- Include a dot or icon, a text label, and `data-state`.
- `pending` uses warning, `success` uses green, `error` uses danger, and
  `neutral` uses Azure blue.
- Never display "healthy", "deployed", or "passed" until the corresponding
  live request confirms it.

### Cards

- Use a one-pixel border, 16px radius, and the raised surface.
- The card title, state, and supporting detail remain distinct at 200% zoom.
- Interactive cards move no more than 2px on hover.

### Commands

- Commands sit in a dark inset panel with monospace text.
- Copy controls announce success or failure through a polite live region.
- Long commands wrap; they never force horizontal page scrolling.

## Layout, grid, and spacing

The content container is `min(1180px, calc(100% - 2rem))`.

Use this spacing scale only:

| Token | Value |
| --- | --- |
| `--space-1` | `0.25rem` |
| `--space-2` | `0.5rem` |
| `--space-3` | `0.75rem` |
| `--space-4` | `1rem` |
| `--space-5` | `1.5rem` |
| `--space-6` | `2rem` |
| `--space-7` | `3rem` |
| `--space-8` | `4.5rem` |

Desktop sections use a 12-column mental grid. Hero copy spans seven columns;
live system state spans five. Card grids use `minmax(0, 1fr)` so content can
shrink without overflow.

## Depth and elevation

Depth is restrained:

- Canvas: no shadow.
- Primary panel: `0 18px 60px rgb(0 0 0 / 24%)`.
- Interactive card hover: `0 14px 32px rgb(0 0 0 / 20%)`.
- Focus is an outline, never a shadow-only treatment.

Do not use glass blur, neon glow, gradients behind text, or stacked shadows.
A subtle radial background wash is allowed only as atmosphere and must not
reduce contrast.

## Motion

- Fast feedback: 120ms.
- Standard component transition: 180ms.
- Section reveal or state change: 240ms maximum.
- Use `ease-out`; avoid spring/bounce effects.
- Animate opacity and transform only.
- Under `prefers-reduced-motion: reduce`, disable smooth scrolling,
  transitions, and nonessential animation.

## Accessibility

- Meet WCAG 2.2 AA contrast.
- Use semantic landmarks, one H1, ordered heading levels, and meaningful link
  text.
- Provide a visible skip link and visible keyboard focus.
- Touch targets are at least 44px.
- Live operational state uses `aria-live="polite"`; critical failures use
  `role="alert"`.
- Color is never the only state indicator.
- Preserve usable content at 200% zoom and down to 320px width.
- Decorative elements are hidden from assistive technology.

## Responsive behavior

- At 960px, hero and trust diagrams collapse to one column.
- At 720px, navigation becomes horizontally scrollable without hiding focus,
  status cards stack, and section spacing contracts.
- At 480px, buttons fill available width and pipeline connectors disappear.
- No page-level horizontal overflow is allowed at any supported width.

## Do and don't guardrails

**Do**

- Prefer native HTML and small ESM modules.
- Show real API loading, success, and failure states.
- Reuse tokens and existing component classes.
- Keep adoption commands copyable and auditable.
- Write concise operational copy.

**Don't**

- Add external fonts, CDNs, UI frameworks, icon packages, or inline assets.
- Use inline script/style, `innerHTML`, or unsafe CSP directives.
- Fabricate passing gates, deployment success, or healthy runtime state.
- Hide errors behind generic green indicators.
- Add decorative charts that imply data the API does not provide.

## Agent prompt and implementation guide

Before editing UI code:

1. Read this file and `.github/instructions/showcase-ui.instructions.md`.
2. Identify existing tokens/components that satisfy the change.
3. Keep HTML semantic and JavaScript state-driven.
4. Verify loading, success, empty, and error states.
5. Test keyboard focus, 200% zoom, reduced motion, desktop, and 320px width.
6. Confirm the strict same-origin CSP remains valid without inline exceptions.
7. Add or update the semantic HTML contract test when landmarks or live regions
   change.
