# R/ui_components.R — FROST
# Reusable UI building blocks. No server logic here — pure HTML construction.

# ── Hero ───────────────────────────────────────────────────────────────────────

#' Full-bleed hero section (static shell).
#' The stats row is filled server-side via output$hero_stats (renderUI).
frost_hero_ui <- function() {
  tags$div(
    class = "frost-hero",

    # Snow animation — 25 <span> elements styled entirely via CSS @for loop.
    tags$div(
      class = "frost-snow-layer",
      lapply(seq_len(25), function(i) tags$span())
    ),

    # Hero content — contains only the static text so its height is fixed and
    # flexbox centering never moves when the stats load below.
    tags$div(
      class = "frost-hero-content",
      tags$p(
        class = "frost-hero-eyebrow",
        "Winter Olympics \u00b7 Milan-Cortina \u00b7 February 2026"
      ),
      tags$h1(class = "frost-hero-title", "FROST"),
      tags$p(
        class = "frost-hero-tagline",
        "Female Records & Olympic Stats Tracker"
      )
    ),

    # Stats row — absolutely positioned at the bottom of the hero so it never
    # participates in the flexbox flow that centers the title block above.
    uiOutput("hero_stats")
  )
}

#' Single stat chip shown in the hero stats row.
#'
#' @param icon  An htmltools tag (e.g. bsicons::bs_icon("trophy-fill")).
#' @param label Short uppercase label shown below the number.
#' @param value Integer target value for the count-up animation.
frost_stat <- function(icon, label, value) {
  tags$div(
    class = "frost-stat",
    tags$span(class = "frost-stat-icon", icon),
    tags$span(
      class = "frost-stat-value",
      `data-countup` = as.character(value),
      "0"
    ),
    tags$span(class = "frost-stat-label", label)
  )
}

# ── Medal Table ────────────────────────────────────────────────────────────────

#' Medal Table panel: dataset toggle + sort controls + server-rendered table.
frost_medal_table_ui <- function() {
  tags$div(
    class = "frost-medal-panel",

    # Heading
    tags$div(
      class = "frost-panel-header",
      tags$p(
        class = "frost-panel-eyebrow",
        "Winter Olympics \u00b7 Milan-Cortina \u00b7 2026"
      ),
      tags$h2(class = "frost-panel-title", "Medal Table")
    ),

    # Controls: toggle (left) + sort (right)
    tags$div(
      class = "frost-medal-controls",
      tags$div(
        class = "frost-toggle-group",
        radioButtons(
          "medal_toggle",
          label = NULL,
          choices = c("All Athletes" = "all", "Women Only" = "female"),
          selected = "all",
          inline = TRUE
        )
      ),
      tags$div(
        class = "frost-sort-group",
        radioButtons(
          "medal_sort",
          label = NULL,
          choices = c(
            "Gold" = "gold",
            "Silver" = "silver",
            "Bronze" = "bronze",
            "Total" = "total"
          ),
          selected = "gold",
          inline = TRUE
        )
      )
    ),

    # Table rendered server-side
    uiOutput("medal_table")
  )
}

# ── Events ─────────────────────────────────────────────────────────────────────

#' Events panel: discipline selector + gender/country filters + card grid.
#'
#' @param discipline_choices Named character vector of discipline_id values,
#'   pre-computed at app startup so the selectInput is populated statically.
frost_events_ui <- function(discipline_choices) {
  tags$div(
    class = "frost-events-panel",

    # Heading
    tags$div(
      class = "frost-panel-header",
      tags$p(class = "frost-panel-eyebrow", "Browse by Discipline"),
      tags$h2(class = "frost-panel-title", "Events")
    ),

    # Filters bar
    tags$div(
      class = "frost-events-filters",
      tags$div(
        class = "frost-select-wrap frost-select-wide",
        selectInput("events_discipline", label = NULL, choices = discipline_choices)
      ),
      tags$div(
        class = "frost-toggle-group",
        radioButtons(
          "events_gender",
          label    = NULL,
          choices  = c("All" = "all", "Women" = "W", "Men" = "M", "Mixed" = "X"),
          selected = "all",
          inline   = TRUE
        )
      ),
      tags$div(
        class = "frost-select-wrap",
        selectInput("events_country", label = NULL, choices = c("All Countries" = "all"))
      )
    ),

    # Card grid rendered server-side
    uiOutput("events_grid")
  )
}

#' Build a single event result card.
#'
#' @param event_row  Single-row data frame from events_df (with event metadata).
#' @param all_results  Full results data frame for the active discipline
#'   (output of get_all_results), already joined with event metadata.
build_event_card <- function(event_row, all_results) {
  gender <- event_row$event_gender
  if (is.null(gender) || length(gender) == 0 || is.na(gender)) gender <- "X"
  is_female  <- gender == "W"
  badge_label <- switch(gender, W = "W", M = "M", X = "MX", gender)
  badge_class <- switch(gender, W = "fec-badge-w", M = "fec-badge-m", "fec-badge-x")

  ev_results <- dplyr::filter(all_results, event_id == event_row$event_id, !is.na(medal))

  medal_rows <- lapply(c("G", "S", "B"), function(m) {
    rows <- dplyr::filter(ev_results, medal == m)
    if (nrow(rows) == 0) return(NULL)
    r <- rows[1L, ]

    first <- r$athlete_first %||% ""
    last  <- r$athlete_last  %||% ""
    name  <- trimws(paste(first, last))
    if (nchar(name) == 0) name <- r$country_name %||% r$country_abbr %||% "\u2014"

    medal_html <- switch(m,
      G = HTML("&#129351;"),
      S = HTML("&#129352;"),
      B = HTML("&#129353;")
    )
    flag_el <- if (!is.na(r$flag_url) && nchar(r$flag_url) > 0) {
      tags$img(class = "fec-flag", src = r$flag_url, alt = r$country_abbr %||% "")
    } else {
      tags$span(class = "fec-flag-abbr", r$country_abbr %||% "")
    }
    score_el <- if (!is.na(r$result) && nchar(r$result) > 0) {
      tags$span(class = "fec-score", r$result)
    } else {
      NULL
    }

    tags$div(
      class = paste0("fec-result-row fec-", tolower(m)),
      tags$span(class = "fec-medal-icon", medal_html),
      flag_el,
      tags$span(class = "fec-athlete", name),
      score_el
    )
  })
  medal_rows <- Filter(Negate(is.null), medal_rows)

  body_content <- if (length(medal_rows) == 0) {
    tags$p(class = "fec-empty", "No results available")
  } else {
    do.call(tagList, medal_rows)
  }

  tags$div(
    class = paste("frost-event-card", if (is_female) "fec-female" else ""),
    tags$div(
      class = "fec-header",
      tags$span(class = paste("fec-badge", badge_class), badge_label),
      tags$div(
        class = "fec-titles",
        tags$span(class = "fec-event-name", event_row$event_name),
        tags$span(class = "fec-disc-name",  event_row$discipline_name)
      )
    ),
    tags$div(class = "fec-results", body_content)
  )
}

# ── Placeholder panels (phase 6) ──────────────────────────────────────────────

#' Minimal placeholder for nav panels not yet built.
#'
#' @param title       Panel heading (e.g. "Medal Table").
#' @param description One-line description of what will go here.
frost_placeholder <- function(title, description) {
  tags$div(
    class = "frost-placeholder",
    tags$div(
      class = "frost-placeholder-inner",
      tags$h2(title),
      tags$p(description)
    )
  )
}
