#' Options that control ckdata
#'
#' Set these with [options()], for one session or in your `.Rprofile`.
#'
#' - `ckdata.mode`: what ckdata does when a query reads a column that is deprecated or may change
#'   without notice. One of `"explore"` (the default), `"audit"` or `"publish"`; see Modes below.
#' - `ckdata.allow`: flagged columns to accept anyway, as a named list of `table = column names`,
#'   for example `list(mart_responses = c("lrn_type", "item_id"))`. An allowed column is never
#'   reported or removed, in any mode.
#' - `ckdata.verbose`: `TRUE` shows the Athena driver's messages while ckdata runs a query, such as
#'   how much data it scanned, and says when [collect_cached()] serves a result from its cache.
#'   Defaults to `FALSE`, which also hides the driver's notice when it retries a failed request, so
#'   a throttled query waits without saying so. ckdata changes the driver's setting only for its own
#'   queries and puts it back afterwards.
#' - `ckdata.cache_dir`: where [collect_cached()] keeps its parquet files. Defaults to
#'   `".ckdata-cache"`.
#'
#' @section Modes:
#' Two kinds of column are flagged:
#'
#' - **Deprecated** columns, which the lake keeps under an old name until a set removal date. The
#'   report names each one's replacement.
#' - Every column of a **staging** (`stg_`) or **intermediate** (`int_`) table, which can change
#'   without notice, unless a published table in the same query has it too, as a join key does.
#'
#' ckdata checks a query when [dplyr::collect()] or [collect_cached()] runs it. The check reads only
#' the query's SQL and columns, never the data.
#'
#' - `"explore"`: nothing is checked. Use it while you work things out.
#' - `"audit"`: a warning names the flagged columns the query uses or returns, and nothing else
#'   changes, so one run of a script lists what to fix and the script still finishes.
#' - `"publish"`: the same warning, and flagged columns the query returns are removed from it before
#'   it runs, so code that reads them fails now rather than on the removal date. A query that would
#'   return nothing else fails instead. Use it for the final run of a document.
#'
#' The modes are a helper for the common cases, not a guarantee. Because the check reads only the
#' SQL, a flagged column that is renamed, or that a join returns as `.x` or `.y`, is reported but
#' not removed; a query whose first table did not come from [lake_tbl()] is checked only by
#' [collect_cached()]; and now and then a warning names a column the query did not need.
#'
#' @name ckdata_options
NULL

ckdata_verbose <- function() {
  rlang::is_true(getOption("ckdata.verbose"))
}

ckdata_mode <- function() {
  rlang::arg_match0(
    getOption("ckdata.mode", "explore"),
    c("explore", "audit", "publish"),
    arg_nm = "ckdata.mode",
    error_call = NULL
  )
}

ckdata_allow <- function() {
  allow <- getOption("ckdata.allow", list())
  valid <- rlang::is_list(allow) && rlang::is_named2(allow) &&
    purrr::every(allow, rlang::is_character)
  if (!valid) {
    cli::cli_abort(
      c(
        "{.code ckdata.allow} must be a named list of column names.",
        i = 'For example: {.code options(ckdata.allow = list(mart_responses = "lrn_type"))}'
      ),
      class = "ckdata_bad_option",
      call = NULL
    )
  }
  allow
}
