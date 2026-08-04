test_that("collect_cached writes a cache, then serves it without re-querying", {
  skip_if_not_installed("RSQLite")
  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con))
  DBI::dbWriteTable(con, "t", data.frame(x = 1:3))
  dir <- withr::local_tempdir()

  q <- dplyr::tbl(con, "t")
  first <- collect_cached(q, dir = dir)
  expect_equal(nrow(first), 3L)
  expect_length(list.files(dir, pattern = "\\.parquet$"), 1L)

  # Change the underlying data; the same query should still return the cached rows.
  DBI::dbExecute(con, "INSERT INTO t (x) VALUES (4)")
  cached <- collect_cached(q, dir = dir)
  expect_equal(nrow(cached), 3L)

  # refresh = TRUE re-runs and sees the new row.
  refreshed <- collect_cached(q, refresh = TRUE, dir = dir)
  expect_equal(nrow(refreshed), 4L)
})
