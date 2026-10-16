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
