#!/usr/bin/env Rscript
# Verify your ckdata setup, end to end.
#
# Run it either way:
#   - from a clone of the repo:    Rscript inst/smoke-test.R
#   - from the installed package:  Rscript -e 'source(system.file("smoke-test.R", package = "ckdata"))'
#
# The first section runs offline and checks the install. The second needs an AWS
# sign-in (aws sso login --profile ck-research) and runs a real query.

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
cat("  ok  ckdata loads; lake_tbl() and collect_cached() present\n")
cat("  ok  dbplyr ", as.character(packageVersion("dbplyr")), " (< 2.6.0)\n", sep = "")

cat("\n== lake connection (needs `aws sso login --profile ck-research`) ==\n")
connected <- tryCatch({
  n <- lake_tbl("mart_classes") |> count() |> collect()
  cat("  ok  connected — mart_classes has ", format(n$n[[1]], big.mark = ","), " rows\n", sep = "")

  d <- file.path(tempdir(), "ckdata-smoke-cache")
  q <- function() lake_tbl("mart_classes") |> head(5) |> collect_cached(dir = d)
  invisible(q())
  invisible(suppressMessages(q()))
  cat("  ok  collect_cached wrote and re-read a parquet cache\n")
  TRUE
}, error = function(e) {
  cat("  FAILED: ", conditionMessage(e), "\n", sep = "")
  cat("  If this is a sign-in/expiry error, run  aws sso login --profile ck-research  and rerun.\n")
  cat("  If it names a missing CK_DATALAKE_* setting, finish the setup in the Datalake 'Connect' guide.\n")
  FALSE
})

if (isTRUE(connected)) {
  cat("\nAll good — your ckdata setup works end to end.\n")
} else {
  quit(status = 1L)
}
