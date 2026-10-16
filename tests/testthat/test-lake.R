verbose_under_driver_options <- function() {
  local_driver_options()
  noctua_verbose()
}

test_that("ckdata quiets noctua while its own code runs, then puts the setting back", {
  local_noctua_state()
  noctua::noctua_options(verbose = TRUE)

  expect_false(verbose_under_driver_options())
  expect_true(noctua_verbose())
})

test_that("ckdata puts noctua's setting back even when the query fails", {
  local_noctua_state()
  noctua::noctua_options(verbose = TRUE)
  failing_query <- function() {
    local_driver_options()
    stop("query failed")
  }

  expect_error(failing_query(), "query failed")
  expect_true(noctua_verbose())
})

test_that("ckdata.verbose = TRUE lets noctua speak during ckdata's queries", {
  local_noctua_state()
  noctua::noctua_options(verbose = FALSE)
  withr::local_options(ckdata.verbose = TRUE)

  expect_true(verbose_under_driver_options())
  expect_false(noctua_verbose())
})

test_that("lake_tbl() looks up its table's columns with noctua quiet", {
  local_noctua_state()
  local_lake_session(local_memory_con(data.frame(x = 1:2), "t"))
  noctua::noctua_options(verbose = TRUE)
  during <- NULL
  sql_query_fields <- dbplyr::sql_query_fields
  testthat::local_mocked_bindings(
    sql_query_fields = function(con, sql, ...) {
      during <<- noctua_verbose()
      sql_query_fields(con, sql, ...)
    },
    .package = "dbplyr"
  )

  lake_tbl("t", schema = "main")

  expect_false(during)
  expect_true(noctua_verbose())
})

test_that("collect() runs a lake query with noctua quiet", {
  local_noctua_state()
  q <- local_memory_lake_tbl(data.frame(x = 1:2))
  noctua::noctua_options(verbose = TRUE)
  during <- NULL
  testthat::local_mocked_bindings(
    db_collect = function(con, sql, ...) {
      during <<- noctua_verbose()
      data.frame(x = 1:2)
    },
    .package = "dbplyr"
  )

  dplyr::collect(q)

  expect_false(during)
  expect_true(noctua_verbose())
})

test_that("collect() on a lake table applies the mode, through any verbs", {
  q <- local_classes_lake_tbl() |> dplyr::filter(class_id > 0)
  withr::local_options(ckdata.mode = "publish", ckdata.allow = list(int_classes = "class_id"))

  expect_warning(out <- dplyr::collect(q), "is_test", class = "ckdata_flagged_columns")
  expect_equal(out, tibble::tibble(class_id = 1:2))
})

test_that("a table opened again is checked against its current columns, each once", {
  con <- local_memory_con(data.frame(class_id = 1L, is_old = TRUE), "int_classes")
  local_lake_session(con)
  lake_tbl("int_classes", schema = "main")
  DBI::dbWriteTable(con, "int_classes", data.frame(class_id = 1L, is_test = TRUE), overwrite = TRUE)
  q <- lake_tbl("int_classes", schema = "main")
  withr::local_options(ckdata.mode = "audit")

  # One bullet per current column (class_id, is_test), however often the table was opened.
  cnd <- expect_warning(dplyr::collect(q), class = "ckdata_flagged_columns")
  expect_equal(stringr::str_count(conditionMessage(cnd), stringr::fixed("(int_classes)")), 2L)
})
