#!/usr/bin/env Rscript
# Verify your ckdata setup, end to end.
#
# Run it from a clone of the repo:
#   Rscript inst/smoke-test.R
# or from the installed package:
#   Rscript -e 'source(system.file("smoke-test.R", package = "ckdata"))'
#
# The first section runs offline and checks the install. The second connects with the settings in
# ?ckdata_settings and counts the rows of one table, so it reads no row's values.

suppressMessages({
  library(ckdata)
  library(dplyr)
})

cat("== ckdata install (offline) ==\n")
stopifnot(
  "lake_tbl() is available" = is.function(lake_tbl),
  "collect_cached() is available" = is.function(collect_cached)
)
if (packageVersion("dbplyr") >= "2.6.0") {
  stop("dbplyr ", packageVersion("dbplyr"), " is installed, but ckdata needs dbplyr < 2.6.0 ",
       "(noctua breaks on 2.6.0). Reinstall ckdata to pull a compatible dbplyr.", call. = FALSE)
}
cat("  ok  ckdata ", as.character(packageVersion("ckdata")), " loads; lake_tbl() and ",
    "collect_cached() present\n", sep = "")
cat("  ok  dbplyr ", as.character(packageVersion("dbplyr")), " (< 2.6.0)\n", sep = "")

settings <- c(
  "CK_DATALAKE_S3_STAGING_DIR", "CK_DATALAKE_REGION", "CK_DATALAKE_WORKGROUP",
  "CK_DATALAKE_INTERNAL_PROFILE", "CK_DATALAKE_ROLE_ARN", "CK_DATALAKE_SCHEMA"
)
for (name in settings) {
  cat("  ", if (nzchar(Sys.getenv(name))) "set  " else "unset", " ", name, "\n", sep = "")
}

schema <- ckdata_schema()
table <- if (identical(schema, "research")) "classes" else "mart_classes"

cat("\n== lake connection: counting ", schema, ".", table, " ==\n", sep = "")
connected <- tryCatch({
  n <- lake_tbl(table) |> count() |> collect()
  cat("  ok  connected; ", table, " has ", format(n$n[[1]], big.mark = ","), " rows\n", sep = "")

  d <- tempfile("ckdata-smoke-cache-")
  first <- lake_tbl(table) |> count() |> collect_cached(dir = d)
  cached <- list.files(d, "\\.parquet$", full.names = TRUE)
  stopifnot("the cache holds one result" = length(cached) == 1)
  stopifnot(
    "the cache reads back the same count" =
      as.numeric(arrow::read_parquet(cached)$n) == as.numeric(first$n)
  )
  cat("  ok  collect_cached() wrote a parquet cache that reads back\n")
  TRUE
}, error = function(e) {
  cat("  FAILED: ", conditionMessage(e), "\n", sep = "")
  cat("  A sign-in or expired-token error: sign in again (for a single sign-on profile,\n",
      "  aws sso login --profile <profile>) and rerun.\n", sep = "")
  cat("  A missing CK_DATALAKE_* setting: see ?ckdata_settings.\n")
  cat("  Access denied or no such table: see \"When it fails\" in the getting-started guide,\n",
      "  vignette(\"getting-started\", package = \"ckdata\") or coursekata.github.io/ckdata-r.\n",
      sep = "")
  FALSE
})

if (isTRUE(connected)) {
  cat("\nAll good: your ckdata setup works end to end.\n")
} else if (interactive()) {
  stop("the ckdata smoke test failed", call. = FALSE)
} else {
  quit(status = 1L)
}
