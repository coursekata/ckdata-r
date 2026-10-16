# ckdata

Query the CourseKata data lake from R.

## Installation

```r
pak::pak("coursekata/ckdata-r")
```

## Usage

```r
library(ckdata)
library(dplyr)

lake_tbl("mart_classes") |>
  count() |>
  collect()
```

`lake_tbl()` returns a lazy dbplyr table reference into the lake, with the Athena
connection opened and managed for you. `collect_cached()` is a drop-in for
`dplyr::collect()` that caches big pulls to a local parquet file.

## Exploring, then publishing

Deprecated columns leave the lake on a set date, and staging (`stg_`) and
intermediate (`int_`) tables can change without notice. While you explore, ckdata
lets you read anything. Before a final run, ask it to check:

```r
options(ckdata.mode = "audit")    # warn about each such column a query reads
options(ckdata.mode = "publish")  # warn, and drop them from the results
```

Keep a column you depend on with `ckdata.allow`. `?ckdata_options` documents
every option.

## Getting connected

A first-time AWS sign-in plus a one-line `~/.Renviron` setup are required before
any query. That setup — and the query walkthrough — live in the internal
**Datalake** docs on Confluence, kept out of this repo so it stays shareable.
Start there.

## Reference

Function reference: <https://coursekata.github.io/ckdata-r>.
