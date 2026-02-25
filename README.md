# FROST — Female Records & Olympic Stats Tracker

R Shiny dashboard covering female athlete performance at the 2026 Winter Olympics (Milan-Cortina). Data from ESPN's public API. Designed to look nothing like a default Shiny app.

---

## SCSS + Theme

FROST compiles Bootstrap 5 and custom SCSS together using `bslib::bs_bundle()` with `sass::sass_layer()`. The four `www/` partials map directly onto Bootstrap's compilation stages:

| File | Layer slot | Purpose |
|------|-----------|---------|
| `www/functions.scss` | `functions` | Google Fonts `@import` — must be first so it lands at the top of the compiled CSS output |
| `www/defaults.scss` | `defaults` | Bootstrap Sass variable overrides (`$primary`, `$body-bg`, typography) — injected before Bootstrap reads its own defaults, so our values win without needing `!default` |
| `www/mixins.scss` | `mixins` | Reusable patterns: `frost-card` (shadow + lift on hover), `medal-badge` (circular pill for G/S/B) |
| `www/rules.scss` | `rules` | Compiled after Bootstrap — CSS custom properties (`:root`), navbar, card and value-box overrides, scrollbar and transition styling |

### Wire-up in `app.R`

```r
theme <- bs_bundle(
  bs_theme(),
  sass::sass_layer(
    functions = sass::sass_file("www/functions.scss"),
    defaults = sass::sass_file("www/defaults.scss"),
    mixins = sass::sass_file("www/mixins.scss"),
    rules = sass::sass_file("www/rules.scss")
  )
)
``` 

Pass `theme` to `page_navbar(theme = theme, ...)`.

### Colour tokens

| Token | Hex | Role |
|-------|-----|------|
| `--frost-ice` | `#D6EAF8` | Subtle fills, scrollbar track |
| `--frost-blue` | `#1A3A5C` | Brand primary, navbar, headings |
| `--frost-slate` | `#2C3E50` | Body text, dark surfaces |
| `--frost-gold` | `#D4AC0D` | Medal accents, navbar underline |
| `--frost-snow` | `#F8FAFC` | Page background |
| `--frost-female` | `#E5B7D6` | Female athlete accent |

Tokens are declared as CSS custom properties in `rules.scss` (runtime) and mirrored as Bootstrap Sass variables in `defaults.scss` (compile-time).

---

## Data

See [`R/README.md`](R/README.md) for full API and data layer documentation.
