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

test_that("a cache built while exploring does not hand flagged columns to publish mode", {
  q <- local_classes_lake_tbl()
  dir <- withr::local_tempdir()
  collect_cached(q, dir = dir)

  withr::local_options(ckdata.mode = "publish", ckdata.allow = list(int_classes = "class_id"))
  expect_warning(out <- collect_cached(q, dir = dir), class = "ckdata_flagged_columns")
  expect_named(out, "class_id")
})

test_that("collect_cached checks a query once, whether or not the cache has it", {
  q <- local_classes_lake_tbl()
  dir <- withr::local_tempdir()
  withr::local_options(ckdata.mode = "audit")

  expect_length(testthat::capture_warnings(first <- collect_cached(q, dir = dir)), 1L)
  DBI::dbExecute(dbplyr::remote_con(q), "INSERT INTO int_classes VALUES (3, 0)")
  expect_length(testthat::capture_warnings(second <- collect_cached(q, dir = dir)), 1L)

  # Audit mode leaves the query as it is, so the second call is served from the first call's cache.
  expect_equal(second, first)
})
