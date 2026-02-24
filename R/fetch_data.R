# R/fetch_data.R
# ESPN API calls and caching for the 2026 Winter Olympics
# API: ESPN public (no key required)

library(httr2)
library(jsonlite)
library(memoise)

.ESPN_BASE <- "https://site.web.api.espn.com/apis/site/v2/olympics/winter/2026"

# Internal helper: perform a GET request and parse JSON
.espn_get <- function(path, query = list()) {
  url <- paste0(.ESPN_BASE, path)

  resp <- tryCatch(
    request(url) |>
      req_url_query(!!!query) |>
      req_timeout(15) |>
      req_error(is_error = \(r) FALSE) |>
      req_perform(),
    error = function(e) {
      warning("ESPN API request failed for ", url, ": ", conditionMessage(e))
      NULL
    }
  )

  if (is.null(resp)) return(NULL)
  if (resp_status(resp) != 200) {
    warning("ESPN API returned status ", resp_status(resp), " for ", url)
    return(NULL)
  }

  tryCatch(
    resp |> resp_body_string() |> fromJSON(simplifyVector = FALSE),
    error = function(e) {
      warning("JSON parse failed for ", url, ": ", conditionMessage(e))
      NULL
    }
  )
}

# ── Public API functions ───────────────────────────────────────────────────────

#' Fetch medal standings by country
fetch_medals <- memoise(function() {
  .espn_get("/medals")
})

#' Fetch all participating countries
fetch_countries <- memoise(function() {
  .espn_get("/countries")
})

#' Fetch all disciplines and their events (includes event type W/M)
fetch_disciplines <- memoise(function() {
  .espn_get("/disciplines")
})

#' Fetch results for a specific event
#'
#' @param sport_id  ESPN sport ID (character or numeric)
#' @param discipline_id  ESPN discipline ID (character or numeric)
#' @param event_id  ESPN event ID (character or numeric)
fetch_results <- memoise(function(sport_id, discipline_id, event_id) {
  .espn_get("/results", query = list(
    sport      = as.character(sport_id),
    discipline = as.character(discipline_id),
    event      = as.character(event_id)
  ))
})
