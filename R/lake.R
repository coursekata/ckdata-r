# Package-level state for the session: the managed DBI connection (con), opened on first use, and
# the columns of every lake table opened so far (tables), one row per column under the table's
# quoted path. The column check finds a query's tables by looking for these paths in its SQL.
the <- new.env(parent = emptyenv())
the$tables <- tibble::tibble(path = character(), table = character(), column = character())

#' A lazy table reference into the CourseKata data lake.
#'
#' Returns a lazy dbplyr `tbl` bound to a package-managed Athena connection, so you never open or
#' close a connection yourself. The result is an ordinary dbplyr `tbl`: pipe it through dplyr
#' verbs (`filter()`, `count()`, ...), `collect()` or [collect_cached()] it, `show_query()` it,
#' or join two `lake_tbl()` results together — they share the one managed connection.
#'
#' Collecting it checks the query for deprecated and unstable columns, as the `ckdata.mode` option
#' asks; see [ckdata_options].
#'
#' @param table Name of the table in the data lake.
#' @param schema Database the table lives in. Defaults to the `ckdata.schema` option, then the
#'   `CK_DATALAKE_SCHEMA` environment variable, then the marts database; see [ckdata_options].
#' @return A lazy dbplyr `tbl`.
#' @export
lake_tbl <- function(table, schema = ckdata_schema()) {
  local_driver_options()
  tbl <- dplyr::tbl(lake_con(), dbplyr::in_schema(schema, table))
  # dbplyr keeps this class through verbs and joins, so collect() reaches collect.tbl_ckdata().
  class(tbl) <- c("tbl_ckdata", class(tbl))
  register_lake_table(tbl)
  tbl
}

#' @exportS3Method dplyr::collect
collect.tbl_ckdata <- function(x, ...) {
  local_driver_options()
  x <- apply_column_policy(x)
  NextMethod()
}

# Record lake table `tbl`'s columns, replacing any earlier record of the same table.
register_lake_table <- function(tbl) {
  entry <- lake_table_columns(tbl)
  the$tables <- the$tables |>
    dplyr::anti_join(entry, by = "path") |>
    dplyr::bind_rows(entry)
}

# One row per column of lake table `tbl`, under its quoted path.
lake_table_columns <- function(tbl) {
  path <- dbplyr::remote_table(tbl)
  table <- dbplyr::table_path_name(path, dbplyr::remote_con(tbl))
  tibble::tibble(path = as.character(path), table = table, column = colnames(tbl))
}

# Set noctua the way ckdata's queries need until the calling function returns. clear_s3_resource =
# FALSE because the read-only role can't delete its own result file (noctua's cleanup would 403),
# so it stays set. verbose follows ckdata.verbose and is put back afterwards, so a researcher's own
# noctua calls keep their setting. noctua has no getter, but noctua_options() returns every option,
# so setting clear_s3_resource also reads the verbose value to restore.
local_driver_options <- function(env = parent.frame()) {
  old <- noctua::noctua_options(clear_s3_resource = FALSE)
  noctua::noctua_options(verbose = ckdata_verbose())
  withr::defer(noctua::noctua_options(verbose = old$verbose), envir = env)
}

# Return the package-managed lake connection, opening it on first use and reusing it afterwards.
# Self-heals: a cached connection that has gone invalid (dbIsValid() is FALSE) is reopened.
# Settings come from the environment (see the Datalake onboarding docs), so a moved bucket or a
# dev pipeline is configuration, not a package change.
lake_con <- function() {
  if (is.null(the$con) || !DBI::dbIsValid(the$con)) {
    the$con <- DBI::dbConnect(
      noctua::athena(),
      s3_staging_dir = lake_env("CK_DATALAKE_S3_STAGING_DIR"),
      region_name    = lake_env("CK_DATALAKE_REGION"),
      work_group     = lake_env("CK_DATALAKE_WORKGROUP"),
      profile_name   = lake_env("CK_DATALAKE_INTERNAL_PROFILE", required = FALSE)
    )
  }
  the$con
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
