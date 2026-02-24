# R/data_helpers.R
# Tidy raw ESPN JSON into clean data frames

library(dplyr)
library(tidyr)
library(purrr)

# ── Medals ─────────────────────────────────────────────────────────────────────

#' Tidy raw medals JSON into a data frame
#'
#' Returns one row per country with gold/silver/bronze/total columns.
tidy_medals <- function(raw) {
  if (is.null(raw) || is.null(raw$medals)) return(empty_medals())

  purrr::map(raw$medals, \(m) {
    ms <- m$medalStandings
    tibble::tibble(
      country_id    = m$id %||% NA_character_,
      country_name  = m$displayName %||% NA_character_,
      abbreviation  = m$abbreviation %||% NA_character_,
      flag_url      = m$flag$href %||% NA_character_,
      gold          = ms$goldMedalCount %||% 0L,
      silver        = ms$silverMedalCount %||% 0L,
      bronze        = ms$bronzeMedalCount %||% 0L,
      total         = ms$totalMedals %||% 0L
    )
  }) |>
    dplyr::bind_rows()
}

empty_medals <- function() {
  tibble::tibble(
    country_id = character(), country_name = character(),
    abbreviation = character(), flag_url = character(),
    gold = integer(), silver = integer(), bronze = integer(), total = integer()
  )
}

# ── Countries ──────────────────────────────────────────────────────────────────

#' Tidy raw countries JSON into a data frame
tidy_countries <- function(raw) {
  if (is.null(raw) || is.null(raw$countries)) return(empty_countries())

  purrr::map(raw$countries, \(c) {
    tibble::tibble(
      country_id   = c$id %||% NA_character_,
      country_name = c$displayName %||% c$name %||% NA_character_,
      abbreviation = c$abbreviation %||% NA_character_,
      flag_url     = c$flag$href %||% NA_character_
    )
  }) |>
    dplyr::bind_rows()
}

empty_countries <- function() {
  tibble::tibble(
    country_id = character(), country_name = character(),
    abbreviation = character(), flag_url = character()
  )
}

# ── Disciplines / Events ───────────────────────────────────────────────────────

#' Tidy disciplines JSON into a flat data frame of all events
#'
#' Each row is one event. Key column: `event_gender` ("W" | "M" | "X" for mixed).
tidy_disciplines <- function(raw) {
  if (is.null(raw) || is.null(raw$disciplines)) return(empty_events())

  purrr::map(raw$disciplines, \(disc) {
    events <- disc$events %||% list()
    if (length(events) == 0) return(NULL)

    purrr::map(events, \(e) {
      tibble::tibble(
        discipline_id   = disc$id %||% NA_character_,
        discipline_name = disc$name %||% NA_character_,
        sport_id        = disc$sportId %||% NA_character_,
        sport_name      = disc$sportName %||% NA_character_,
        event_id        = e$id %||% NA_character_,
        event_name      = e$name %||% NA_character_,
        event_gender    = e$type %||% "X",   # W = women, M = men, X = mixed
        event_slug      = e$slug %||% NA_character_
      )
    }) |>
      dplyr::bind_rows()
  }) |>
    purrr::compact() |>
    dplyr::bind_rows()
}

empty_events <- function() {
  tibble::tibble(
    discipline_id = character(), discipline_name = character(),
    sport_id = character(), sport_name = character(),
    event_id = character(), event_name = character(),
    event_gender = character(), event_slug = character()
  )
}

#' Filter events to women's only
get_female_events <- function(events_df) {
  dplyr::filter(events_df, event_gender == "W")
}

# ── Results ────────────────────────────────────────────────────────────────────

#' Tidy a single fetch_results() response into a data frame
#'
#' Returns one row per athlete result (medal finishers only have medal filled in,
#' all competitors are included for ranked events).
tidy_results <- function(raw) {
  if (is.null(raw) || is.null(raw$competitions)) return(empty_results())

  purrr::map(raw$competitions, \(comp) {
    results <- comp$results %||% list()
    if (length(results) == 0) return(NULL)

    purrr::map(results, \(r) {
      athlete <- r$athlete %||% list()
      country <- r$country %||% list()
      tibble::tibble(
        competition_id   = comp$id %||% NA_character_,
        competition_desc = comp$description %||% NA_character_,
        competition_date = comp$date %||% NA_character_,
        competition_type = comp$competitionType %||% NA_character_,
        athlete_id       = athlete$id %||% NA_character_,
        athlete_first    = athlete$firstName %||% NA_character_,
        athlete_last     = athlete$lastName %||% NA_character_,
        country_name     = country$name %||% NA_character_,
        country_abbr     = country$abbreviation %||% NA_character_,
        flag_url         = country$flag$href %||% NA_character_,
        place            = r$place %||% NA_integer_,
        result           = r$result %||% NA_character_,
        medal            = r$medal %||% NA_character_   # "G", "S", "B" or NA
      )
    }) |>
      dplyr::bind_rows()
  }) |>
    purrr::compact() |>
    dplyr::bind_rows()
}

empty_results <- function() {
  tibble::tibble(
    competition_id = character(), competition_desc = character(),
    competition_date = character(), competition_type = character(),
    athlete_id = character(), athlete_first = character(), athlete_last = character(),
    country_name = character(), country_abbr = character(), flag_url = character(),
    place = integer(), result = character(), medal = character()
  )
}

# ── Aggregated helpers ─────────────────────────────────────────────────────────

#' Fetch and tidy results for ALL events in an events data frame
#'
#' @param events_df  Output of tidy_disciplines() (or get_female_events())
#' @return Data frame with all results, joined with event metadata
get_all_results <- function(events_df) {
  if (nrow(events_df) == 0) return(empty_results())

  purrr::pmap(
    list(events_df$sport_id, events_df$discipline_id, events_df$event_id,
         events_df$discipline_name, events_df$event_name, events_df$event_gender),
    \(sport_id, discipline_id, event_id, disc_name, ev_name, ev_gender) {
      raw <- fetch_results(sport_id, discipline_id, event_id)
      df  <- tidy_results(raw)
      if (nrow(df) == 0) return(NULL)
      dplyr::mutate(df,
        sport_id        = sport_id,
        discipline_id   = discipline_id,
        discipline_name = disc_name,
        event_id        = event_id,
        event_name      = ev_name,
        event_gender    = ev_gender
      )
    }
  ) |>
    purrr::compact() |>
    dplyr::bind_rows()
}

#' Derive per-country medal counts from individual results
#'
#' Useful for computing gender-specific medal tables that the medals endpoint
#' does not provide.
derive_medal_table <- function(results_df) {
  results_df |>
    dplyr::filter(!is.na(medal)) |>
    dplyr::mutate(
      gold   = medal == "G",
      silver = medal == "S",
      bronze = medal == "B"
    ) |>
    dplyr::group_by(country_name, country_abbr, flag_url) |>
    dplyr::summarise(
      gold   = sum(gold),
      silver = sum(silver),
      bronze = sum(bronze),
      total  = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(gold), dplyr::desc(silver), dplyr::desc(bronze))
}

# ── Null coalescing helper ─────────────────────────────────────────────────────
`%||%` <- function(x, y) if (!is.null(x) && length(x) > 0) x else y
