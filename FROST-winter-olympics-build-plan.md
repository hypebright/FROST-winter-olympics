# FROST — Build Plan
### Female Records & Olympic Stats Tracker
#### Winter Olympics 2026 · Milan-Cortina · Built with R Shiny + bslib + custom SCSS

---

## Concept

FROST is a Shiny dashboard covering the 2026 Winter Olympics with a deliberate focus on
female athletes. It is designed to demonstrate that R Shiny (powered by bslib, Bootstrap 5,
and custom SCSS) can produce a truly unique interface that feels nothing like a standard
R dashboard.

Data is pulled from ESPN's public API. The visual identity draws from alpine winter
aesthetics: ice blues, deep slate, snow white, and gold accents.

---

## Acronym

| Letter | Word |
|--------|------|
| F | Female |
| R | Records |
| O | Of |
| S | Snow |
| T | Triumph |

---

## Data Strategy

### Source
ESPN's unofficial public API (no key required).

### Endpoints to probe
```
# Medal standings
https://site.web.api.espn.com/apis/site/v2/olympics/winter/2026/medals

# Countries
https://site.web.api.espn.com/apis/site/v2/olympics/winter/2026/countries

# Disciplines 
https://site.web.api.espn.com/apis/site/v2/olympics/winter/2026/disciplines

# Example to get events for a given sport and discipline
https://site.web.api.espn.com/apis/site/v2/olympics/winter/2026/results?sport=7&discipline=33
```

### Approach
- Use `httr2` for HTTP requests and `jsonlite` for parsing
- Probe endpoints first to confirm structure and available fields
- Filter female athlete events where the API provides gender segmentation
- Cache responses in-session with `memoise` to avoid repeated API calls
- Gracefully handle missing or incomplete data with fallback UI states

---

## File Structure

```
FROST/
├── app.R                    # Entry point: ui + server
├── R/
│   ├── fetch_data.R         # ESPN API calls + caching logic
│   ├── data_helpers.R       # JSON tidying, filtering, reshaping
│   └── ui_components.R      # Reusable bslib card/panel builders
├── www/
│   ├── theme.scss           # Main SCSS entry point (imports all partials)
│   ├── _variables.scss      # Color tokens, typography, spacing
│   ├── _layout.scss         # Page-level overrides (hero, nav, grid)
│   └── _components.scss     # Cards, badges, value boxes, tables
```

---

## Tech Stack

| Purpose | Package |
|---------|---------|
| UI framework | `shiny` + `bslib` |
| SCSS compilation | `bs_bundle()` from `bslib` |
| API requests | `httr2` |
| JSON parsing | `jsonlite` |
| API caching | `memoise` |
| Data wrangling | `dplyr` + `tidyr` |
| Charts | `echarts4r` |
| Icons | `bsicons` + Font Awesome (via bslib) |

---

## Visual Identity

### Palette
| Token | Hex | Usage |
|-------|-----|-------|
| `--frost-ice` | `#D6EAF8` | Backgrounds, subtle fills |
| `--frost-blue` | `#1A3A5C` | Primary brand, headings |
| `--frost-slate` | `#2C3E50` | Body text, dark surfaces |
| `--frost-gold` | `#D4AC0D` | Medal accents, highlights |
| `--frost-snow` | `#F8FAFC` | Page background |
| `--frost-female` | `#E5B7D6` | Female athlete accent color |

### Typography
- Headings: **DM Sans** (geometric, clean, modern) via Google Fonts
- Body: **Inter** (readable, neutral)
- Loaded via `@import` in `_variables.scss`

---

## App Views

### 1. Home / Hero
- Full-bleed hero section with alpine background image or CSS gradient
- App title (FROST) with tagline
- Summary value boxes: total events, total female athletes, nations represented
- Subtle CSS snow animation in the background

### 2. Medal Table
- Country rankings with gold / silver / bronze counts
- Toggle: **All athletes** vs **Female athletes only**
- Sortable by total or by medal type
- Country flags (emoji or CDN-based)
- Animated count-up on load via CSS/JS

### 3. Events
- Results browsable by sport/discipline
- Filter by sport, country, medal type
- Female events highlighted with a badge
- Results displayed in styled cards (not a plain table)

### 4. Athletes
- Spotlight on top-performing female athletes
- Card-based layout: name, country, sport, medals won
- Country filter + sport filter
- Medals shown as styled icons, not text

---

## SCSS Strategy

The goal is to override Bootstrap 5 defaults deeply enough that no default Shiny aesthetic
remains, while still leveraging bslib's layout primitives (cards, grids, value boxes).

### Key SCSS techniques
- Redefine Bootstrap Sass variables before the framework loads (via bslib `bs_theme()`)
- Layer custom CSS variables on `:root` for runtime theming
- Override `.card`, `.navbar`, `.value-box` component styles
- Use `@mixin` for reusable patterns (e.g. frost-card shadow, medal badge)
- Custom scrollbar styling (`-webkit-scrollbar`)
- Smooth transitions on hover states across all interactive elements

### SCSS compilation

The `bslib` package is used to include SASS files and add them to the theme.
```r
theme <- bs_bundle(
  bs_theme(),
  sass::sass_layer(
    functions = sass::sass_file("functions.scss"),
    defaults = sass::sass_file("defaults.scss"),
    mixins = sass::sass_file("mixins.scss"),
    rules = sass::sass_file("rules.scss")
  )
)
```

The theme is included in the ui as follows:

```r
  bslib::page_navbar(
    theme = theme,
    h1("Hello!")
  )
```

---

## Build Phases

### Phase 1 — Data foundation
- [ x ] Probe ESPN API endpoints, confirm 2026 Winter Olympics data availability
- [ x ] Write `fetch_data.R`: API calls, error handling, caching
- [ x ] Write `data_helpers.R`: tidy raw JSON into clean data frames
- [ x ] Confirm female athlete filtering is possible from the data

### Phase 2 — SCSS + theme setup
- [ x ] Set up `www/` folder with all partials
- [ x ] Define color tokens and typography in `defaults.scss`
- [ x ] Configure `bs_theme()` in `app.R` using custom Sass files
- [ x ] Compile and verify custom CSS loads correctly in a bare Shiny app
- [ x ] Put some boilerplate code in app.R with a variety of (empty) elements: headers, simple paragraph, simple value box

### Phase 3 — Hero section + Home view
- [ ] Create hero section for the Home view with summary value boxes wired up to data from ESPN and alpine styling
- [ ] Establish responsive grid using bslib's layout system

### Phase 4 — Medal Table view
- [ ] Wire up medal data from ESPN
- [ ] Build sortable, filterable medal table
- [ ] Add female/all toggle
- [ ] Style with custom SCSS (not default bslib appearance)

### Phase 5 — Events view
- [ ] Wire up event results data
- [ ] Build card-based results display
- [ ] Add sport + country filters
- [ ] Badge female events

### Phase 6 — Athletes view
- [ ] Wire up athlete data
- [ ] Build athlete spotlight cards
- [ ] Add filters
- [ ] Medal icon treatment

### Phase 7 — Polish
- [ ] CSS animations (count-up, snow, hover transitions)
- [ ] Responsive testing
- [ ] Loading states and error fallbacks
- [ ] Final SCSS cleanup and consistency pass

---

## Out of Scope (for now)
- User authentication
- Persistent data storage
- Push notifications or real-time websocket updates
- Mobile-first breakpoints (responsive but desktop-primary)

---

*Plan drafted: February 2026*
