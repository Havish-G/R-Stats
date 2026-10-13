# =====================================================================
# R/db_connect.R
# Central DB connection helper - same pattern as the healthcare project.
# Swap the SQLite branch for the PostgreSQL branch to move from a local
# demo to a production-like demo with zero changes elsewhere in the app.
# =====================================================================

library(DBI)
library(jsonlite)

#' @param backend "sqlite" (default, local demo) or "postgres" (prod-like demo)
get_db_connection <- function(backend = Sys.getenv("APP_DB_BACKEND", "sqlite")) {
  if (backend == "postgres") {
    DBI::dbConnect(
      RPostgres::Postgres(),
      dbname   = Sys.getenv("PGDATABASE", "stats_studio"),
      host     = Sys.getenv("PGHOST", "localhost"),
      port     = as.integer(Sys.getenv("PGPORT", "5432")),
      user     = Sys.getenv("PGUSER", "postgres"),
      password = Sys.getenv("PGPASSWORD", "")
    )
  } else {
    DBI::dbConnect(RSQLite::SQLite(), file.path("db", "stats_studio.sqlite"))
  }
}

#' Write one row to audit_log. Safe to call from any module.
log_action <- function(con, user_id = 1L, action, entity = NA, entity_id = NA, details = NA) {
  DBI::dbExecute(con,
    "INSERT INTO audit_log (user_id, action, entity, entity_id, details) VALUES (?, ?, ?, ?, ?)",
    params = list(user_id, action, entity, entity_id, details)
  )
}

#' Register a dataset the first time it's loaded (built-in or uploaded),
#' or reuse the existing row for a built-in dataset selected again.
register_dataset <- function(con, source, name, df) {
  # Defensive guard: never let a malformed `df` reach dbExecute() and
  # crash the session with an opaque DBI parameter-binding error. NROW()/
  # NCOL() (not nrow()/ncol()) are used deliberately - they always return
  # a safe length-1 integer (0 for anything non-tabular), whereas
  # nrow()/ncol() can return NULL for non-data.frame input, which breaks
  # parameter binding.
  if (!is.data.frame(df)) df <- as.data.frame(df)
  if (NROW(df) == 0) {
    stop("register_dataset() was given an empty or invalid data frame for '", name, "' - nothing to register.")
  }

  if (source == "builtin") {
    existing <- DBI::dbGetQuery(con,
      "SELECT dataset_id FROM datasets WHERE source = 'builtin' AND name = ? ORDER BY loaded_at DESC LIMIT 1",
      params = list(name))
    if (NROW(existing) > 0) return(existing$dataset_id[1])
  }
  num_cols <- names(df)[sapply(df, is.numeric)]
  cat_cols <- names(df)[sapply(df, function(x) is.factor(x) || is.character(x))]
  DBI::dbExecute(con,
    "INSERT INTO datasets (source, name, n_rows, n_cols, numeric_cols, categorical_cols) VALUES (?, ?, ?, ?, ?, ?)",
    params = list(source, name, NROW(df), NCOL(df),
                   paste(num_cols, collapse = ","), paste(cat_cols, collapse = ","))
  )
  DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
}

#' Save one analysis run (EDA/hypothesis/ANOVA/regression/CLT) and log it.
#' @return the new analysis_id
save_analysis <- function(con, dataset_id, analysis_type, parameters_list,
                           result_summary, p_value = NA, user_id = 1L) {
  DBI::dbExecute(con,
    "INSERT INTO analyses (dataset_id, analysis_type, parameters, result_summary, p_value) VALUES (?, ?, ?, ?, ?)",
    params = list(dataset_id, analysis_type,
                   jsonlite::toJSON(parameters_list, auto_unbox = TRUE),
                   result_summary, p_value)
  )
  aid <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
  log_action(con, user_id = user_id, action = paste0("RUN_", analysis_type),
             entity = "analyses", entity_id = aid,
             details = substr(result_summary, 1, 200))
  aid
}
