# app.R — FROST: Female Records & Olympic Stats Tracker
# 2026 Winter Olympics · Milan-Cortina
# Built with R Shiny + bslib + custom SCSS

library(shiny)
library(bslib)
library(bsicons)

source("R/fetch_data.R")
source("R/data_helpers.R")
source("R/ui_components.R")

# Pre-compute discipline choices at startup for the static Events selectInput.
# fetch_disciplines() is memoised so the server's own call is instant.
.discipline_choices <- local({
  df <- tidy_disciplines(fetch_disciplines()) |>
    dplyr::distinct(discipline_id, discipline_name) |>
    dplyr::arrange(discipline_name)
  setNames(df$discipline_id, df$discipline_name)
})

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
  nav_panel("Events", frost_events_ui(.discipline_choices)),
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

  observe({
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

  # ── Events ──────────────────────────────────────────────────────────────────
  # Results are loaded per-discipline on demand. fetch_results() is memoised so
  # switching back to a discipline that was already viewed is instant.
  events_results_rv <- reactiveVal(NULL)

  # Helper defined inside server to capture events_df, events_results_rv, session
  load_disc_results <- function(disc_id) {
    events_results_rv(NULL)
    withProgress(message = "Loading results\u2026", value = 0.5, {
      disc_evts <- dplyr::filter(events_df, discipline_id == disc_id)
      events_results_rv(get_all_results(disc_evts))
    })
    # Update country filter with medal-winning countries from this discipline
    medal_countries <- events_results_rv() |>
      dplyr::filter(!is.na(medal)) |>
      dplyr::distinct(country_name) |>
      dplyr::arrange(country_name)
    updateSelectInput(session, "events_country",
      choices = c(
        "All Countries" = "all",
        setNames(medal_countries$country_name, medal_countries$country_name)
      )
    )
  }

  # Initial load: fires when user first navigates to Events tab
  observe({
    req(input$nav == "Events", is.null(events_results_rv()))
    load_disc_results(input$events_discipline)
  }) |>
    bindEvent(input$nav)

  # Reload when discipline selector changes
  observe({
    load_disc_results(input$events_discipline)
  }) |>
    bindEvent(input$events_discipline, ignoreInit = TRUE)

  output$events_grid <- renderUI({
    req(!is.null(events_results_rv()))

    # Events for the selected discipline, filtered by gender
    display_events <- dplyr::filter(events_df, discipline_id == input$events_discipline)
    if (!is.null(input$events_gender) && input$events_gender != "all") {
      display_events <- dplyr::filter(display_events, event_gender == input$events_gender)
    }

    # Country filter: keep events where the selected country won at least one medal
    if (!is.null(input$events_country) && input$events_country != "all") {
      medalled_events <- events_results_rv() |>
        dplyr::filter(!is.na(medal), country_name == input$events_country) |>
        dplyr::pull(event_id) |>
        unique()
      display_events <- dplyr::filter(display_events, event_id %in% medalled_events)
    }

    if (nrow(display_events) == 0) {
      return(tags$div(
        class = "frost-no-data",
        tags$p("No events match the current filters.")
      ))
    }

    cards <- lapply(seq_len(nrow(display_events)), function(i) {
      build_event_card(display_events[i, ], events_results_rv())
    })
    tags$div(class = "frost-events-grid", do.call(tagList, cards))
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
