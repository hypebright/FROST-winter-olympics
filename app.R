# app.R — FROST: Female Records Of Snow & Triumph
# 2026 Winter Olympics · Milan-Cortina
# Built with R Shiny + bslib + custom SCSS

library(shiny)
library(bslib)

# ── UI ─────────────────────────────────────────────────────────────────────────

ui <- bslib::page_navbar(
  title = "FROST",
  id = "nav",

  bslib::nav_panel(
    "Home",
    h1("FROST"),
    p("Female Records Of Snow & Triumph — 2026 Winter Olympics")
  )
)

# ── Server ─────────────────────────────────────────────────────────────────────

server <- function(input, output, session) {
  # Pre-fetch data on startup (cached via memoise)
  medals_raw <- fetch_medals()
  disciplines_raw <- fetch_disciplines()
  countries_raw <- fetch_countries()

  medals_df <- tidy_medals(medals_raw)
  events_df <- tidy_disciplines(disciplines_raw)
  female_events <- get_female_events(events_df)
  countries_df <- tidy_countries(countries_raw)
}

shinyApp(ui, server)
