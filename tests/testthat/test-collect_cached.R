test_that("collect_cached writes a cache, then serves it without re-querying", {
  q <- local_memory_tbl(data.frame(x = 1:3))
  dir <- withr::local_tempdir()

  first <- collect_cached(q, dir = dir)
  expect_equal(nrow(first), 3L)
  expect_length(list.files(dir, pattern = "\\.parquet$"), 1L)

  # Change the underlying data; the same query should still return the cached rows.
  DBI::dbExecute(dbplyr::remote_con(q), "INSERT INTO t (x) VALUES (4)")
  cached <- collect_cached(q, dir = dir)
  expect_equal(nrow(cached), 3L)

  # refresh = TRUE re-runs and sees the new row.
  refreshed <- collect_cached(q, refresh = TRUE, dir = dir)
  expect_equal(nrow(refreshed), 4L)
})

test_that("a cache hit is silent unless ckdata.verbose is TRUE", {
  q <- local_memory_tbl(data.frame(x = 1:3))
  dir <- withr::local_tempdir()
  collect_cached(q, dir = dir)

  expect_no_message(collect_cached(q, dir = dir))

  withr::local_options(ckdata.verbose = TRUE)
  expect_message(collect_cached(q, dir = dir), "reading cached result")
})
