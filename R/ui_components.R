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

# ── Placeholder panels (phases 5–6) ───────────────────────────────────────────

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
