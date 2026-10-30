#' Settings that connect ckdata to the lake
#'
#' ckdata opens its Athena connection from environment variables, the first time a session calls
#' [lake_tbl()]. Set them in `~/.Renviron` for your own machine, or have the environment that runs
#' R set them, such as a container or a scheduled job. They name where the lake is and who you
#' connect as; none of them is a secret. Whoever gives you access to the lake gives you their
#' values. `vignette("getting-started", package = "ckdata")` walks through the setup.
#'
#' @section Required:
#' - `CK_DATALAKE_S3_STAGING_DIR`: the S3 location Athena writes query results to, such as
#'   `s3://<bucket>/<prefix>/`. A workgroup that enforces its own result location overrides it.
#' - `CK_DATALAKE_REGION`: the AWS region the lake is in, such as `us-west-2`.
#' - `CK_DATALAKE_WORKGROUP`: the Athena workgroup queries run in.
#'
#' If one is unset, [lake_tbl()] stops with an error that names it.
#'
#' @section Optional:
#' - `CK_DATALAKE_INTERNAL_PROFILE`: the AWS profile to connect as, from `~/.aws/config`, such as
#'   a single sign-on profile. It applies to ckdata alone, so other AWS tools on the machine keep
#'   their own settings.
#' - `CK_DATALAKE_ROLE_ARN`: an IAM role to assume before connecting, for an identity that cannot
#'   query the lake itself but may assume a role that can, such as a container whose own role may
#'   assume a reader role in the lake's account.
#' - `CK_DATALAKE_SCHEMA`: the database [lake_tbl()] reads from when the call names none, read on
#'   every call. The `ckdata.schema` option takes precedence; see [ckdata_options].
#'
#' An empty value counts as unset.
#'
#' @section Credentials:
#' With `CK_DATALAKE_INTERNAL_PROFILE` set, ckdata connects as that profile, unless
#' `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are both set, which take precedence over any
#' profile. Without a profile, the AWS SDK's default chain applies, in order: those environment
#' variables, the profile `AWS_PROFILE` names (or `default`), container credentials, including a web
#' identity token, and finally the instance's role.
#'
#' With `CK_DATALAKE_ROLE_ARN` set, ckdata first finds credentials the same way, then uses them to
#' assume that role and connects as the role. The assumed credentials expire an hour after the
#' connection opens and ckdata does not renew them. In the last 15 minutes each query warns that the
#' connection will expire, and after the hour every query fails with an expired-token error until R
#' restarts. The variable is not `AWS_ROLE_ARN`, which the web identity step reads for the identity
#' ckdata starts from.
#'
#' @section When settings take effect:
#' The connection opens on the first [lake_tbl()] call and is reused for the rest of the session,
#' so a change to any setting but `CK_DATALAKE_SCHEMA` takes effect after R restarts. R reads
#' `~/.Renviron` only when it starts.
#'
#' @name ckdata_settings
NULL
