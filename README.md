# ckdata

Query the CourseKata data lake from R.

## Installation

```r
options(repos = c(CRAN = "https://p3m.dev/cran/2026-06-15"))
pak::pak("coursekata/ckdata-r")
```

ckdata needs noctua, its Athena driver, and dbplyr older than 2.6.0, which noctua breaks on. Current CRAN carries neither, so the first line points this R session at a dated snapshot of CRAN that has both. If something later upgrades dbplyr, reinstall ckdata the same way.

pak skips the guides when it installs from GitHub. To read them with `vignette()`, also run `options(pkg.build_vignettes = TRUE)` before installing; building them needs knitr, rmarkdown and pandoc.

## Getting connected

ckdata connects with settings it reads from environment variables, usually in `~/.Renviron`. Three say where the lake is:

```
CK_DATALAKE_S3_STAGING_DIR=s3://<bucket>/<prefix>/
CK_DATALAKE_REGION=<region>
CK_DATALAKE_WORKGROUP=<workgroup>
```

The AWS identity it connects as is either a named profile (`CK_DATALAKE_INTERNAL_PROFILE`), such as a single sign-on profile, or, with no profile named, whatever credentials the environment provides. `CK_DATALAKE_ROLE_ARN` adds a role to assume on top of either. Restart R after editing `~/.Renviron`.

`vignette("getting-started", package = "ckdata")` walks through the setup and how to check it, and `?ckdata_settings` documents every setting.

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

## Choosing the database

`lake_tbl()` reads from the marts unless told otherwise. Name another database in the call, or set a default once: the `ckdata.schema` option, or the `CK_DATALAKE_SCHEMA` environment variable, which applies when the option is unset.

```r
lake_tbl("responses", schema = "research")  # this call only
options(ckdata.schema = "research")         # every call that names no schema
```

An environment that may read only the `research` views, such as a research container, sets `CK_DATALAKE_SCHEMA=research`, and its scripts name no schema.

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

## Guides and reference

- `vignette("getting-started", package = "ckdata")`: connecting to the lake.
- `vignette("querying-the-lake", package = "ckdata")`: databases, queries, caching and the modes.
- The same guides and the function reference, online: <https://coursekata.github.io/ckdata-r>, and as source in `vignettes/`.
