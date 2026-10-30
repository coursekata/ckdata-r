# ckdata

Query the CourseKata data lake from R.

## Installation

```r
install.packages("pak")
options(repos = c(CRAN = "https://p3m.dev/cran/2026-06-15"))
pak::pak("coursekata/ckdata-r")
```

ckdata needs noctua, its Athena driver, and dbplyr older than 2.6.0, which noctua breaks on. Current CRAN carries neither, so the second line points this R session at a dated snapshot of CRAN that has both. If something later upgrades dbplyr, reinstall ckdata the same way.

pak skips the guides when it installs from GitHub. To read them with `vignette()`, also run `options(pkg.build_vignettes = TRUE)` before installing; building them needs knitr, rmarkdown and pandoc.

## Usage

ckdata connects with settings it reads from environment variables. The [getting-started guide](https://coursekata.github.io/ckdata-r/articles/getting-started.html) sets them up and checks the connection. Then:

```r
library(ckdata)
library(dplyr)

lake_tbl("mart_classes") |>
  count() |>
  collect()
```

`lake_tbl()` returns a lazy dbplyr table in the lake, over a connection ckdata opens and manages. `collect_cached()` is `dplyr::collect()` with a local parquet cache for big pulls.

## Guides and reference

- `vignette("getting-started", package = "ckdata")`: connecting to the lake.
- `vignette("querying-the-lake", package = "ckdata")`: databases, queries, caching, and checking for columns that will change.
- `?ckdata_settings`, `?ckdata_options` and `?ckdata_schema`: every setting and option.
- The same guides and the function reference, online: <https://coursekata.github.io/ckdata-r>, and as source in `vignettes/`.
