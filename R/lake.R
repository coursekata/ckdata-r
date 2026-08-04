# Package-level state: holds the single managed DBI connection for the session.
.ckdata_state <- new.env(parent = emptyenv())

#' A lazy table reference into the CourseKata data lake.
#'
#' Returns a lazy dbplyr `tbl` bound to a package-managed Athena connection, so you never open or
#' close a connection yourself. The result is an ordinary dbplyr `tbl`: pipe it through dplyr
#' verbs (`filter()`, `count()`, ...), `collect()` or [collect_cached()] it, `show_query()` it,
#' or join two `lake_tbl()` results together — they share the one managed connection.
#'
#' @param table Name of the table in the data lake.
#' @param schema Database the table lives in; defaults to the marts database.
#' @return A lazy dbplyr `tbl`.
#' @export
lake_tbl <- function(table, schema = "ck_datalake_prd_marts_app") {
  dplyr::tbl(lake_con(), dbplyr::in_schema(schema, table))
}

# Return the package-managed lake connection, opening it on first use and reusing it afterwards.
# Self-heals: a cached connection that has gone invalid (dbIsValid() is FALSE) is reopened.
lake_con <- function() {
  con <- .ckdata_state$con
  if (is.null(con) || !DBI::dbIsValid(con)) {
    con <- .lake_connect()
    .ckdata_state$con <- con
  }
  con
}

# Open a fresh Athena connection via noctua. Settings come from the environment (see the
# Datalake onboarding docs), so a moved bucket or a dev pipeline is configuration, not a
# package change. clear_s3_resource = FALSE because the read-only role can't delete its own
# result file (noctua's cleanup would 403).
.lake_connect <- function() {
  noctua::noctua_options(clear_s3_resource = FALSE)
  DBI::dbConnect(
    noctua::athena(),
    s3_staging_dir = lake_env("CK_DATALAKE_S3_STAGING_DIR"),
    region_name    = lake_env("CK_DATALAKE_REGION"),
    work_group     = lake_env("CK_DATALAKE_WORKGROUP"),
    profile_name   = lake_env("CK_DATALAKE_INTERNAL_PROFILE", required = FALSE)
  )
}

# A connection setting from the environment. required = TRUE settings fail with a fix-it pointer
# if unset; optional ones return NULL so AWS's ambient chain applies (how a role-based pipeline
# authenticates without a named profile).
lake_env <- function(name, required = TRUE) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) {
    return(value)
  }
  if (required) {
    stop(
      paste0(
        "ckdata: ", name,
        " is not set; add it to your ~/.Renviron ",
        "(see the CourseKata Datalake onboarding docs)."
      ),
      call. = FALSE
    )
  }
  NULL
}
