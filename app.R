# app.R — FROST: Female Records & Olympic Stats Tracker
# 2026 Winter Olympics · Milan-Cortina
# Built with R Shiny + bslib + custom SCSS

library(shiny)
library(bslib)
library(bsicons)

source("R/fetch_data.R")
source("R/data_helpers.R")
source("R/ui_components.R")

# ── Theme ──────────────────────────────────────────────────────────────────────
theme <- bs_bundle(
  bs_theme(),
  sass::sass_layer(
    functions = sass::sass_file("www/functions.scss"),
    defaults = sass::sass_file("www/defaults.scss"),
    mixins = sass::sass_file("www/mixins.scss"),
    rules = sass::sass_file("www/rules.scss")
  )
)

# ── UI ─────────────────────────────────────────────────────────────────────────
ui <- page_navbar(
  theme = theme,
  title = "FROST",
  id = "nav",

  # Load FROST's client-side JS (count-up animation, future interactions)
  header = tags$head(
    tags$script(src = "frost.js")
  ),

  nav_panel("Home", frost_hero_ui()),
  nav_panel(
    "Medal Table",
    frost_placeholder("Medal Table", "Country rankings with female-only toggle")
  ),
  nav_panel(
    "Events",
    frost_placeholder("Events", "Results by sport and discipline")
  ),
  nav_panel(
    "Athletes",
    frost_placeholder("Athletes", "Female athlete spotlight")
  )
)

# ── Server ─────────────────────────────────────────────────────────────────────
server <- function(input, output, session) {
  # Pre-fetch all data once on startup. memoise ensures subsequent calls within
  # the session are instant (no repeated HTTP requests).
  medals_raw <- fetch_medals()
  disciplines_raw <- fetch_disciplines()
  countries_raw <- fetch_countries()

  medals_df <- tidy_medals(medals_raw)
  events_df <- tidy_disciplines(disciplines_raw)
  female_events <- get_female_events(events_df)
  countries_df <- tidy_countries(countries_raw)

  # ── Hero stats ──────────────────────────────────────────────────────────────
  # Rendered once — all values are final (games ended Feb 23 2026).
  # The data-countup attribute triggers the JS count-up animation in frost.js.
  output$hero_stats <- renderUI({
    n_events <- nrow(female_events)
    n_disciplines <- length(unique(female_events$discipline_name))
    n_nations <- nrow(medals_df)

    tags$div(
      class = "frost-stats-row",
      frost_stat(bs_icon("trophy-fill"), "Female Events", n_events),
      frost_stat(bs_icon("snow"), "Disciplines", n_disciplines),
      frost_stat(bs_icon("globe2"), "Nations", n_nations)
    )
  })
}

shinyApp(ui, server)
