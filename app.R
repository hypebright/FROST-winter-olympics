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
  nav_panel("Medal Table", frost_medal_table_ui()),
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

  # Normalize column name so both datasets share the same interface downstream
  medals_all <- dplyr::rename(medals_df, country_abbr = abbreviation)

  # ── Medal Table ─────────────────────────────────────────────────────────────
  # Female data is expensive to fetch (50 API calls). Load it once — lazily —
  # the first time the user switches to "Women Only". memoise caches each
  # fetch_results() call so subsequent sort changes are instant.
  female_medals_rv <- reactiveVal(NULL)

  observe(input$medal_toggle, {
    req(input$medal_toggle == "female", is.null(female_medals_rv()))
    withProgress(message = "Fetching women\u2019s results\u2026", value = 0.1, {
      results <- get_all_results(female_events)
      setProgress(0.9, message = "Computing standings\u2026")
      female_medals_rv(derive_medal_table(results))
    })
  }) |>
    bindEvent(input$medal_toggle, ignoreInit = TRUE)

  # Active dataset — switches between all / female, sorted by selected column
  active_medals <- reactive({
    sort_col <- input$medal_sort %||% "gold"
    if (input$medal_toggle == "all") {
      dplyr::arrange(medals_all, dplyr::desc(.data[[sort_col]]))
    } else {
      req(!is.null(female_medals_rv()))
      dplyr::arrange(female_medals_rv(), dplyr::desc(.data[[sort_col]]))
    }
  })

  output$medal_table <- renderUI({
    # Hold rendering until female data is ready (progress overlay shows meanwhile)
    if (!is.null(input$medal_toggle) && input$medal_toggle == "female") {
      req(!is.null(female_medals_rv()))
    }

    df <- dplyr::select(
      active_medals(),
      country_name,
      country_abbr,
      flag_url,
      gold,
      silver,
      bronze,
      total
    )

    if (nrow(df) == 0) {
      return(tags$div(
        class = "frost-no-data",
        tags$p("No medal data available.")
      ))
    }

    # Table header row
    tbl_header <- tags$div(
      class = "frost-medal-header",
      tags$span(class = "fmr-rank"),
      tags$span(class = "fmr-flag-col"),
      tags$span(class = "fmr-country-col", "Country"),
      tags$span(class = "fmr-medal-col", HTML("&#129351;")),
      tags$span(class = "fmr-medal-col", HTML("&#129352;")),
      tags$span(class = "fmr-medal-col", HTML("&#129353;")),
      tags$span(class = "fmr-medal-col fmr-total-col", "Total")
    )

    # Data rows
    tbl_rows <- lapply(seq_len(nrow(df)), function(i) {
      row <- df[i, ]
      top_class <- dplyr::case_when(
        i == 1 ~ "fmr-top-gold",
        i == 2 ~ "fmr-top-silver",
        i == 3 ~ "fmr-top-bronze",
        TRUE ~ ""
      )
      flag_el <- if (!is.na(row$flag_url) && nchar(row$flag_url) > 0) {
        tags$img(
          class = "fmr-flag-img",
          src = row$flag_url,
          alt = row$country_abbr
        )
      } else {
        tags$span(class = "fmr-flag-abbr", row$country_abbr)
      }
      tags$div(
        class = paste("frost-medal-row", top_class),
        style = paste0("animation-delay:", min((i - 1) * 0.02, 0.5), "s"),
        tags$span(class = "fmr-rank", i),
        flag_el,
        tags$span(class = "fmr-country", row$country_name),
        tags$span(class = "fmr-medal fmr-gold", row$gold),
        tags$span(class = "fmr-medal fmr-silver", row$silver),
        tags$span(class = "fmr-medal fmr-bronze", row$bronze),
        tags$span(class = "fmr-medal fmr-total", row$total)
      )
    })

    tags$div(
      class = "frost-medal-table",
      tbl_header,
      do.call(tagList, tbl_rows)
    )
  })

  # ── Hero stats ──────────────────────────────────────────────────────────────
  # Rendered once — all values are final (games ended Feb 23 2026).
  # The data-countup attribute triggers the JS count-up animation in frost.js.
  output$hero_stats <- renderUI({
    n_events <- nrow(female_events)
    n_disciplines <- length(unique(female_events$discipline_name))
    n_nations <- length(unique((countries_df$country_id)))

    tags$div(
      class = "frost-stats-row",
      frost_stat(bs_icon("trophy-fill"), "Female Events", n_events),
      frost_stat(bs_icon("snow"), "Disciplines", n_disciplines),
      frost_stat(bs_icon("globe2"), "Countries", n_nations)
    )
  })
}

shinyApp(ui, server)
