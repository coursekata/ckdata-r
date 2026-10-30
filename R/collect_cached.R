#' Collect a dbplyr query, caching the result to a local parquet file.
#'
#' Runs the query the first time and writes the result to a parquet cache keyed on the query's
#' SQL; later calls with the same query read the cache instead of re-scanning the lake. Big pulls
#' page in slowly, so caching makes iterating on an analysis fast.
#'
#' The cache is keyed on the query's SQL, not on the data. The lake rebuilds nightly, so a cache
#' made before a rebuild is stale. Pass `refresh = TRUE`, or delete the cache directory, to pull
#' again.
#'
#' @param query A lazy dbplyr query — typically a [lake_tbl()] piped through dplyr verbs, e.g.
#'   `lake_tbl("mart_responses") |> filter(...)`.
#' @param refresh If `TRUE`, ignore any cached result and re-run the query.
#' @param dir Cache directory; defaults to the `ckdata.cache_dir` option (see [ckdata_options]),
#'   or `".ckdata-cache"`.
#' @return A tibble of results.
#' @export
collect_cached <- function(query, refresh = FALSE,
                           dir = getOption("ckdata.cache_dir", ".ckdata-cache")) {
  # Checked before keying: a cache hit is then reported like a fresh pull, and a query publish
  # mode trims gets a key of its own, so a cache built while exploring can't bypass the check.
  query <- apply_column_policy(query)
  key  <- digest::digest(as.character(dbplyr::remote_query(query)))
  path <- file.path(dir, paste0(key, ".parquet"))
  if (!refresh && file.exists(path)) {
    if (ckdata_verbose()) message("ckdata: reading cached result from ", path)
    return(dplyr::as_tibble(arrow::read_parquet(path)))
  }
  # Explore mode keeps collect() from checking the query a second time.
  df <- withr::with_options(list(ckdata.mode = "explore"), dplyr::collect(query))
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  arrow::write_parquet(df, path)
  df
}
