#' Options that control ckdata
#'
#' Set these with [options()], for one session or in your `.Rprofile`.
#'
#' - `ckdata.verbose`: `TRUE` shows the Athena driver's messages while ckdata runs a query, such as
#'   how much data it scanned, and says when [collect_cached()] serves a result from its cache.
#'   Defaults to `FALSE`, which also hides the driver's notice when it retries a failed request, so
#'   a throttled query waits without saying so. ckdata changes the driver's setting only for its own
#'   queries and puts it back afterwards.
#' - `ckdata.cache_dir`: where [collect_cached()] keeps its parquet files. Defaults to
#'   `".ckdata-cache"`.
#'
#' @name ckdata_options
NULL

ckdata_verbose <- function() {
  rlang::is_true(getOption("ckdata.verbose"))
}
