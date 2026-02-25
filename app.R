# app.R — FROST: Female Records Of Snow & Triumph
# 2026 Winter Olympics · Milan-Cortina
# Built with R Shiny + bslib + custom SCSS

library(shiny)
library(bslib)
library(bsicons)

source("R/fetch_data.R")
source("R/data_helpers.R")

# ── Theme ──────────────────────────────────────────────────────────────────────
# bs_bundle() layers FROST's SCSS partials into Bootstrap's compilation pipeline.
# The sass_layer() slots map to Bootstrap's own compilation order:
#   functions → before Bootstrap (CSS @import, SCSS functions)
#   defaults  → before Bootstrap variables (our Sass variable overrides win)
#   mixins    → after Bootstrap variables, before rules (reusable patterns)
#   rules     → after Bootstrap (component overrides, CSS custom properties)
theme <- bs_bundle(
  bs_theme(),
  sass::sass_layer(
    functions = sass::sass_file("www/functions.scss"),
    defaults  = sass::sass_file("www/defaults.scss"),
    mixins    = sass::sass_file("www/mixins.scss"),
    rules     = sass::sass_file("www/rules.scss")
  )
)

# ── UI ─────────────────────────────────────────────────────────────────────────

ui <- bslib::page_navbar(
  theme = theme,
  title = "FROST",
  id = "nav",

  bslib::nav_panel(
    "Home",

    bslib::layout_columns(
      col_widths = c(8, 4),
      gap = "1.5rem",

      # ── Hero text ────────────────────────────────────────────────────────────
      card(
        card_body(
          h1("FROST"),
          h2("Female Records Of Snow & Triumph", class = "h4"),
          p(
            "A focused look at women's performance across the 2026 Winter Olympics",
            "in Milan-Cortina. 50 events, 15 disciplines, one spotlight."
          )
        )
      ),

      # ── Summary value boxes ───────────────────────────────────────────────────
      bslib::layout_columns(
        col_widths = 12,
        gap = "1rem",
        value_box(
          title = "Female Events",
          value = "50",
          showcase = bs_icon("trophy-fill"),
          theme = "primary"
        ),
        value_box(
          title = "Disciplines",
          value = "15",
          showcase = bs_icon("snow"),
          theme = "primary"
        ),
        value_box(
          title = "Nations",
          value = "29",
          showcase = bs_icon("globe2"),
          theme = "primary"
        )
      )
    )
  )
)

# ── Server ─────────────────────────────────────────────────────────────────────

server <- function(input, output, session) {
  # Pre-fetch data on startup (cached via memoise)
  medals_raw      <- fetch_medals()
  disciplines_raw <- fetch_disciplines()
  countries_raw   <- fetch_countries()

  medals_df     <- tidy_medals(medals_raw)
  events_df     <- tidy_disciplines(disciplines_raw)
  female_events <- get_female_events(events_df)
  countries_df  <- tidy_countries(countries_raw)
}

shinyApp(ui, server)
