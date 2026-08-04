#' Collect a dbplyr query, caching the result to a local parquet file.
#'
#' Runs the query the first time and writes the result to a parquet cache keyed on the query's
#' SQL; later calls with the same query read the cache instead of re-scanning the lake. Big
#' response pulls page in slowly, so this makes iterating on an analysis fast.
#'
#' The cache is keyed on the query only, NOT on the data — the lake rebuilds nightly, so a
#' cache made before a rebuild is stale. Pass refresh = TRUE (or delete the cache directory)
#' to re-pull.
#'
#' @param query A lazy dbplyr query (e.g. tbl(con, ...) |> filter(...)).
#' @param refresh If TRUE, ignore any cached result and re-run the query.
#' @param dir Cache directory; defaults to option ckdata.cache_dir or ".ckdata-cache".
#' @return A tibble of results.
#' @export
collect_cached <- function(query, refresh = FALSE,
                           dir = getOption("ckdata.cache_dir", ".ckdata-cache")) {
  key  <- digest::digest(as.character(dbplyr::remote_query(query)))
  path <- file.path(dir, paste0(key, ".parquet"))
  if (!refresh && file.exists(path)) {
    message("ckdata: reading cached result from ", path)
    return(dplyr::as_tibble(arrow::read_parquet(path)))
  }
  df <- dplyr::collect(query)
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  arrow::write_parquet(df, path)
  df
}
