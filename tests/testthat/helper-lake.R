# Whether noctua prints its INFO lines. noctua has no getter, but noctua_options() returns every
# option; clear_s3_resource is the setting ckdata always applies anyway.
noctua_verbose <- function() {
  noctua::noctua_options(clear_s3_resource = FALSE)$verbose
}

# Put noctua's verbose setting back when the calling test ends.
local_noctua_state <- function(env = parent.frame()) {
  old <- noctua_verbose()
  withr::defer(noctua::noctua_options(verbose = old), envir = env)
}

# Make `con` the session's lake connection, with no lake tables opened yet, until the calling test
# ends, so lake_tbl() reads from it instead of opening a connection to Athena.
local_lake_session <- function(con, env = parent.frame()) {
  rlang::local_bindings(con = con, tables = the$tables[0, ], .env = the, .frame = env)
}

# A throwaway in-memory SQLite database holding `df` as table `name`, closed when the calling test
# ends.
local_memory_con <- function(df, name, env = parent.frame()) {
  testthat::skip_if_not_installed("RSQLite")
  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  withr::defer(DBI::dbDisconnect(con), envir = env)
  DBI::dbWriteTable(con, name, df)
  con
}

# A lake session in which table `t` exists in the marts and in `research`, each copy with one column
# named after its database, so colnames() tells which one lake_tbl() opened. Neither schema setting
# is set until the calling test sets one.
local_two_schema_lake <- function(env = parent.frame()) {
  testthat::skip_if_not_installed("RSQLite")
  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  withr::defer(DBI::dbDisconnect(con), envir = env)
  for (schema in c("ck_datalake_prd_marts_app", "research")) {
    DBI::dbExecute(con, paste0("ATTACH DATABASE ':memory:' AS ", schema))
    DBI::dbExecute(con, paste0("CREATE TABLE ", schema, ".t (", schema, " INTEGER)"))
  }
  withr::local_options(ckdata.schema = NULL, .local_envir = env)
  withr::local_envvar(CK_DATALAKE_SCHEMA = NA, .local_envir = env)
  local_lake_session(con, env)
}

# The arguments lake_con() opens its connection with, given these environment variables on top of
# placeholder required settings. A stand-in for DBI::dbConnect() records them, so nothing reaches
# AWS.
lake_con_args <- function(...) {
  withr::local_envvar(
    CK_DATALAKE_S3_STAGING_DIR = "s3://bucket/results/",
    CK_DATALAKE_REGION = "us-west-2",
    CK_DATALAKE_WORKGROUP = "workgroup",
    CK_DATALAKE_INTERNAL_PROFILE = NA,
    CK_DATALAKE_ROLE_ARN = NA
  )
  withr::local_envvar(...)
  args <- NULL
  testthat::local_mocked_bindings(
    dbConnect = function(drv, ...) {
      args <<- list(...)
      structure(list(), class = "stand_in_con")
    },
    .package = "DBI"
  )
  rlang::local_bindings(con = NULL, .env = the)
  lake_con()
  args
}

# A plain lazy table (not a lake table) over an in-memory SQLite copy of `df`.
local_memory_tbl <- function(df, name = "t", env = parent.frame()) {
  dplyr::tbl(local_memory_con(df, name, env), name)
}

# `df` as lake table `name`, read from an in-memory SQLite copy that stands in for the lake.
local_memory_lake_tbl <- function(df, name = "t", env = parent.frame()) {
  local_lake_session(local_memory_con(df, name, env), env)
  lake_tbl(name, schema = "main")
}

# int_classes as a lake table over an in-memory SQLite copy. Every column of an intermediate table
# is flagged, so the edges can be tested without depending on the shipped deprecation data.
local_classes_lake_tbl <- function(env = parent.frame()) {
  local_memory_lake_tbl(data.frame(class_id = 1:2, is_test = FALSE), "int_classes", env = env)
}

# A plain dbplyr table over dbplyr's simulated connection: it renders SQL but never runs it, so the
# column check, which reads only a query's SQL and columns, runs offline.
simulated_tbl <- function(table, columns, schema = "ck_datalake_prd_marts_app") {
  dplyr::tbl(dbplyr::simulate_dbi(), dbplyr::in_schema(schema, table), vars = columns)
}

# Registry rows for these lake tables, as lake_tbl() records them.
registry_of <- function(...) {
  dplyr::bind_rows(purrr::map(list(...), lake_table_columns))
}

# Real rows from the shipped column table, one per kind of replacement: a column on the same
# table, a column on another table, another table with no single column, and none.
deprecation_fixture <- tibble::tribble(
  ~table,           ~column,                 ~new_table,         ~new_column,       ~removed_on,
  "mart_responses", "branch",                "mart_enrollments", "variation_index", "2026-12-01",
  "mart_responses", "lms_id",                NA,                 NA,                "2026-12-01",
  "mart_responses", "lrn_question_position", "mart_questions",   NA,                "2026-12-01",
  "mart_responses", "lrn_type",              "mart_responses",   "question_type",   "2026-12-01"
)
