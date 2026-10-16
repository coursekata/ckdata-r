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

# Make `con` the session's lake connection until the calling test ends, so lake_tbl() reads from it
# instead of opening a connection to Athena.
local_lake_session <- function(con, env = parent.frame()) {
  rlang::local_bindings(con = con, .env = the, .frame = env)
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

# A plain lazy table (not a lake table) over an in-memory SQLite copy of `df`.
local_memory_tbl <- function(df, name = "t", env = parent.frame()) {
  dplyr::tbl(local_memory_con(df, name, env), name)
}

# `df` as lake table `name`, read from an in-memory SQLite copy that stands in for the lake.
local_memory_lake_tbl <- function(df, name = "t", env = parent.frame()) {
  local_lake_session(local_memory_con(df, name, env), env)
  lake_tbl(name, schema = "main")
}
