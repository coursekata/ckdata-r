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

schema_opened <- function(...) colnames(lake_tbl("t", ...))

test_that("lake_tbl() reads from the marts unless a schema is set", {
  local_two_schema_lake()

  expect_equal(schema_opened(), "ck_datalake_prd_marts_app")
})

test_that("CK_DATALAKE_SCHEMA sets the schema lake_tbl() reads from", {
  local_two_schema_lake()
  withr::local_envvar(CK_DATALAKE_SCHEMA = "research")

  expect_equal(schema_opened(), "research")
})

test_that("an empty CK_DATALAKE_SCHEMA counts as unset", {
  local_two_schema_lake()
  withr::local_envvar(CK_DATALAKE_SCHEMA = "")

  expect_equal(schema_opened(), "ck_datalake_prd_marts_app")
})

test_that("the ckdata.schema option takes precedence over CK_DATALAKE_SCHEMA", {
  local_two_schema_lake()
  withr::local_envvar(CK_DATALAKE_SCHEMA = "ck_datalake_prd_marts_app")
  withr::local_options(ckdata.schema = "research")

  expect_equal(schema_opened(), "research")
})

test_that("a schema named in the call takes precedence over both settings", {
  local_two_schema_lake()
  withr::local_envvar(CK_DATALAKE_SCHEMA = "research")
  withr::local_options(ckdata.schema = "research")

  expect_equal(schema_opened(schema = "ck_datalake_prd_marts_app"), "ck_datalake_prd_marts_app")
})

test_that("the mode checks a table opened from the configured schema", {
  withr::local_options(ckdata.schema = "main")
  local_lake_session(local_memory_con(data.frame(class_id = 1:2, is_test = FALSE), "int_classes"))
  q <- lake_tbl("int_classes")
  withr::local_options(ckdata.mode = "publish", ckdata.allow = list(int_classes = "class_id"))

  expect_warning(out <- dplyr::collect(q), "is_test", class = "ckdata_flagged_columns")
  expect_equal(out, tibble::tibble(class_id = 1:2))
})

test_that("CK_DATALAKE_ROLE_ARN names the role the connection assumes", {
  arn <- "arn:aws:iam::123456789012:role/lake-reader"

  expect_equal(lake_con_args(CK_DATALAKE_ROLE_ARN = arn)$role_arn, arn)
})

test_that("without CK_DATALAKE_ROLE_ARN the connection assumes no role", {
  expect_null(lake_con_args()$role_arn)
})

test_that("a missing required setting names itself and the help topic that explains it", {
  withr::local_envvar(CK_DATALAKE_REGION = NA)

  expect_error(lake_env("CK_DATALAKE_REGION"), "CK_DATALAKE_REGION is not set.*\\?ckdata_settings")
})

test_that("a missing optional setting reads as unset", {
  withr::local_envvar(CK_DATALAKE_INTERNAL_PROFILE = "")

  expect_null(lake_env("CK_DATALAKE_INTERNAL_PROFILE", required = FALSE))
})
