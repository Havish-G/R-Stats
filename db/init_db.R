# =====================================================================
# db/init_db.R
# Creates (or resets) the local SQLite database from schema.sql.
# Unlike the healthcare project, no reference dataset is preloaded into
# a data table here - datasets are registered in `datasets` on demand as
# users load them from the app (built-in example or upload), since this
# app's whole point is working on whatever dataset is active.
#
# Usage:  Rscript db/init_db.R            # keep existing db if present
#         Rscript db/init_db.R --reset    # drop & recreate everything
# =====================================================================

library(DBI)
library(RSQLite)

args    <- commandArgs(trailingOnly = TRUE)
reset   <- "--reset" %in% args
db_path <- file.path("db", "stats_studio.sqlite")

if (reset && file.exists(db_path)) {
  file.remove(db_path)
  message("Existing database removed (--reset).")
}

con <- dbConnect(RSQLite::SQLite(), db_path)
on.exit(dbDisconnect(con), add = TRUE)

schema_sql <- paste(readLines("db/schema.sql"), collapse = "\n")
statements <- strsplit(schema_sql, ";")[[1]]
statements <- trimws(statements)
statements <- statements[nzchar(statements)]

for (stmt in statements) {
  tryCatch(dbExecute(con, stmt), error = function(e) {
    message("Skipping (likely already applied): ", substr(stmt, 1, 60))
  })
}

message("Database ready at: ", normalizePath(db_path))
