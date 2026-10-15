# Regenerates column_changes in R/sysdata.rda: the deprecated columns the lake still publishes, one
# row per alias with its replacement and removal date.
#
# The source is ck-datalake's column_changes.csv, which maps every renamed, retyped or retired
# lake column and is held to the dbt model yml by a ck-datalake test. Only the deprecated aliases
# are kept: a column with a removal date. The migration notes are dropped, because the Data Lake
# Handbook carries that prose and two copies would drift apart.
#
# Run from the package root, with a ck-datalake checkout beside this repo, whenever ck-datalake
# changes the file:
#
#   Rscript data-raw/column_changes.R

source_csv <- "../ck-datalake/dbt-runner/dbt/column_changes.csv"
if (!file.exists(source_csv)) {
  stop("Expected a ck-datalake checkout beside this repo: ", source_csv, " not found.")
}

column_changes <- readr::read_csv(
  source_csv,
  col_types = readr::cols(.default = readr::col_character())
) |>
  dplyr::filter(!is.na(column), !is.na(removed_on)) |>
  dplyr::select(table, column, new_table, new_column, removed_on) |>
  dplyr::arrange(table, column)

usethis::use_data(column_changes, internal = TRUE, overwrite = TRUE)
