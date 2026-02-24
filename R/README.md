# R/ — Data Layer

This folder contains all data fetching and transformation logic for the FROST app.
No UI code lives here. Two files, one clear responsibility each.

```
R/
├── fetch_data.R      ESPN API calls, HTTP handling, in-session caching
├── data_helpers.R    Tidy raw JSON into clean data frames, aggregation helpers
└── README.md         This file
```

---

## Data source

**ESPN's public Winter Olympics API** — no API key required.

```
Base URL: https://site.web.api.espn.com/apis/site/v2/olympics/winter/2026
```

Four endpoints are used:

| Endpoint | Description |
|---|---|
| `GET /medals` | Overall medal standings per country |
| `GET /countries` | All 93 participating nations |
| `GET /disciplines` | All 16 disciplines and their events, with gender type per event |
| `GET /results?sport=&discipline=&event=` | Athlete-level results for a single event |

The games ended on February 23, 2026. All data is final.

---

## Raw API shapes

What ESPN actually returns (relevant fields only):

### `/medals`

```json
{
  "medals": [
    {
      "id": "58",
      "name": "Norway",
      "displayName": "Norway",
      "abbreviation": "NOR",
      "flag": { "href": "https://a.espncdn.com/i/teamlogos/countries/500/nor.png" },
      "medalStandings": {
        "goldMedalCount": 18,
        "silverMedalCount": 12,
        "bronzeMedalCount": 11,
        "totalMedals": 41
      }
    }
  ]
}
```

29 countries appear in the standings. Countries with zero medals are absent.
There is **no gender breakdown** at this level — see `derive_medal_table()` for that.

---

### `/countries`

```json
{
  "countries": [
    {
      "id": "88",
      "name": "Albania",
      "displayName": "Albania",
      "abbreviation": "ALB",
      "flag": { "href": "https://a.espncdn.com/i/teamlogos/countries/500/alb.png" }
    }
  ]
}
```

93 countries total, including those that sent athletes but won no medals.
Useful as a reference table for complete country metadata and flags.

---

### `/disciplines`

```json
{
  "disciplines": [
    {
      "id": "1",
      "name": "Alpine Skiing",
      "sportId": "7",
      "sportName": "Skiing",
      "events": [
        {
          "id": "10",
          "name": "Women's Slalom",
          "type": "W",
          "slug": "olympics-womens-slalom"
        },
        {
          "id": "2",
          "name": "Men's Downhill",
          "type": "M",
          "slug": "olympics-mens-downhill"
        }
      ]
    }
  ]
}
```

16 disciplines, 116 events total. The `type` field on each event is the gender signal:

| `type` | Meaning |
|--------|---------|
| `"W"` | Women's event |
| `"M"` | Men's event |
| `"X"` | Mixed / team event with both genders |

50 events are women's (`"W"`), spread across 15 disciplines.
Nordic Combined is the only discipline with no women's events.

---

### `/results?sport=7&discipline=1&event=10`

```json
{
  "competitions": [
    {
      "id": "31583",
      "description": "Women's Slalom, Final",
      "date": "2026-02-18T12:30Z",
      "competitionType": "individual",
      "results": [
        {
          "athlete": { "id": "50872", "firstName": "Mikaela", "lastName": "Shiffrin" },
          "country": {
            "name": "United States",
            "abbreviation": "USA",
            "flag": { "href": "https://a.espncdn.com/i/teamlogos/countries/500/usa.png" }
          },
          "place": 1,
          "result": "1:39.10",
          "medal": "G"
        }
      ]
    }
  ]
}
```

`medal` values: `"G"` (gold), `"S"` (silver), `"B"` (bronze), or absent for non-medal finishers.
For team events, each team member appears as a separate row with the same `place`.

---

## `fetch_data.R`

Handles HTTP requests and caches responses for the duration of the session.

### Dependencies

`httr2`, `jsonlite`, `memoise`

### Internal

#### `.espn_get(path, query)`

Private helper. Builds the full URL, performs the GET request with a 15-second
timeout, and parses the response body as JSON (using `simplifyVector = FALSE` so
all nested structures remain as lists, not auto-coerced data frames).

Returns `NULL` on any failure — network error, non-200 status, or JSON parse error —
and emits a `warning()` with context. All public functions handle `NULL` gracefully.

---

### Public functions

All four public functions are wrapped with `memoise()`. The first call hits the
network; subsequent calls within the same R session return the cached result instantly.

#### `fetch_medals()`

```r
raw <- fetch_medals()
```

Returns the raw parsed JSON list from `/medals`, or `NULL` on failure.
Pass to `tidy_medals()` to get a data frame.

---

#### `fetch_countries()`

```r
raw <- fetch_countries()
```

Returns the raw parsed JSON list from `/countries`, or `NULL` on failure.
Pass to `tidy_countries()`.

---

#### `fetch_disciplines()`

```r
raw <- fetch_disciplines()
```

Returns the raw parsed JSON list from `/disciplines`, or `NULL` on failure.
Pass to `tidy_disciplines()` to get a flat events data frame.

---

#### `fetch_results(sport_id, discipline_id, event_id)`

```r
raw <- fetch_results("7", "1", "10")
```

All three parameters are required and coerced to character internally.
The IDs come from the disciplines data — use `tidy_disciplines()` to get them.

Returns the raw parsed JSON list from `/results`, or `NULL` on failure.
Pass to `tidy_results()`.

---

## `data_helpers.R`

Converts raw JSON lists into tidy tibbles and provides aggregation helpers.
All `tidy_*` functions return an empty tibble with the correct schema when given
`NULL` or malformed input — the app never needs to guard against `NULL` data frames.

### Dependencies

`dplyr`, `tidyr`, `purrr`

---

### Tidy functions

#### `tidy_medals(raw)`

```r
medals_df <- tidy_medals(fetch_medals())
```

**Output schema:**

| Column | Type | Description |
|--------|------|-------------|
| `country_id` | `chr` | ESPN country ID |
| `country_name` | `chr` | Full country name |
| `abbreviation` | `chr` | 3-letter IOC code (e.g. `"NOR"`) |
| `flag_url` | `chr` | ESPN CDN URL for the country flag PNG |
| `gold` | `int` | Gold medal count |
| `silver` | `int` | Silver medal count |
| `bronze` | `int` | Bronze medal count |
| `total` | `int` | Total medals |

One row per country. Only countries with at least one medal appear (29 rows).
Already sorted by the API in descending gold order.

---

#### `tidy_countries(raw)`

```r
countries_df <- tidy_countries(fetch_countries())
```

**Output schema:**

| Column | Type | Description |
|--------|------|-------------|
| `country_id` | `chr` | ESPN country ID |
| `country_name` | `chr` | Full country name |
| `abbreviation` | `chr` | 3-letter IOC code |
| `flag_url` | `chr` | ESPN CDN URL for the country flag PNG |

One row per country. All 93 participating nations, including those with zero medals.
Useful as a join table to attach flags and names to results data.

---

#### `tidy_disciplines(raw)`

```r
events_df <- tidy_disciplines(fetch_disciplines())
```

Flattens the nested discipline → events structure into one row per event.

**Output schema:**

| Column | Type | Description |
|--------|------|-------------|
| `discipline_id` | `chr` | ESPN discipline ID |
| `discipline_name` | `chr` | Discipline name (e.g. `"Alpine Skiing"`) |
| `sport_id` | `chr` | ESPN sport ID (needed for `fetch_results()`) |
| `sport_name` | `chr` | Parent sport name (e.g. `"Skiing"`) |
| `event_id` | `chr` | ESPN event ID (needed for `fetch_results()`) |
| `event_name` | `chr` | Full event name (e.g. `"Women's Slalom"`) |
| `event_gender` | `chr` | `"W"` women, `"M"` men, `"X"` mixed |
| `event_slug` | `chr` | URL slug |

116 rows across 16 disciplines.

---

#### `tidy_results(raw)`

```r
results_df <- tidy_results(fetch_results("7", "1", "10"))
```

Unpacks a single event's results into one row per athlete.

**Output schema:**

| Column | Type | Description |
|--------|------|-------------|
| `competition_id` | `chr` | ESPN competition ID |
| `competition_desc` | `chr` | Human-readable description (e.g. `"Women's Slalom, Final"`) |
| `competition_date` | `chr` | ISO 8601 UTC datetime string |
| `competition_type` | `chr` | `"individual"` or `"team"` |
| `athlete_id` | `chr` | ESPN athlete ID |
| `athlete_first` | `chr` | First name |
| `athlete_last` | `chr` | Last name |
| `country_name` | `chr` | Full country name |
| `country_abbr` | `chr` | 3-letter IOC code |
| `flag_url` | `chr` | ESPN CDN URL for the country flag PNG |
| `place` | `int` | Finishing position |
| `result` | `chr` | Raw result string (time, score, distance — format varies by sport) |
| `medal` | `chr` | `"G"`, `"S"`, `"B"`, or `NA` for non-medallists |

For team events, each athlete on a medal-winning team has the same `place` value.
Non-medal competitors are included with `medal = NA`.

---

### Filter helpers

#### `get_female_events(events_df)`

```r
female_events <- get_female_events(tidy_disciplines(fetch_disciplines()))
```

Wraps `dplyr::filter(events_df, event_gender == "W")`.
Returns a subset of the events data frame containing only women's events.
50 events across 15 disciplines.

---

### Aggregation helpers

#### `get_all_results(events_df)`

```r
all_results <- get_all_results(events_df)            # all 116 events
female_results <- get_all_results(female_events)     # 50 women's events only
```

Iterates over every row of an events data frame, calls `fetch_results()` for each,
tidies with `tidy_results()`, and appends event metadata columns before combining.

Adds these columns to the `tidy_results()` schema:

| Column | Type | Description |
|--------|------|-------------|
| `sport_id` | `chr` | ESPN sport ID |
| `discipline_id` | `chr` | ESPN discipline ID |
| `discipline_name` | `chr` | Discipline name |
| `event_id` | `chr` | ESPN event ID |
| `event_name` | `chr` | Full event name |
| `event_gender` | `chr` | `"W"`, `"M"`, or `"X"` |

Because `fetch_results()` is memoised, repeated calls for the same event are free.
Events that return no data are silently dropped.

---

#### `derive_medal_table(results_df)`

```r
# Gender-specific medal table — something the /medals endpoint doesn't provide
female_medals <- derive_medal_table(get_all_results(female_events))
```

Aggregates individual results into a per-country medal count table.
Only rows where `medal` is non-`NA` are counted.

**Output schema:**

| Column | Type | Description |
|--------|------|-------------|
| `country_name` | `chr` | Full country name |
| `country_abbr` | `chr` | 3-letter IOC code |
| `flag_url` | `chr` | ESPN CDN URL for the country flag PNG |
| `gold` | `int` | Gold medals won |
| `silver` | `int` | Silver medals won |
| `bronze` | `int` | Bronze medals won |
| `total` | `int` | Total medals won |

Sorted descending by gold, then silver, then bronze.
This is the primary source for the female-only medal table in the app, since the
`/medals` endpoint only provides overall counts without gender segmentation.

---

## Typical usage in the app

```r
source("R/fetch_data.R")
source("R/data_helpers.R")

# One-time fetch on startup (cached after first call)
medals_df     <- tidy_medals(fetch_medals())
countries_df  <- tidy_countries(fetch_countries())
events_df     <- tidy_disciplines(fetch_disciplines())

# Gender filtering
female_events <- get_female_events(events_df)

# Bulk results fetch (makes one API call per event, all cached)
female_results <- get_all_results(female_events)

# Derived medal table for the female-only toggle
female_medals  <- derive_medal_table(female_results)
```

---

## Error handling

Every `fetch_*` function returns `NULL` on failure and emits a `warning()`.
Every `tidy_*` function returns an empty tibble (with the correct column schema)
when passed `NULL`. The app can always call `nrow()` on results without crashing,
and can display a "data unavailable" fallback UI when a data frame has zero rows.
