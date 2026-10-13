test_that("database initializes with expected tables", {
  test_db <- tempfile(fileext = ".sqlite")
  con <- DBI::dbConnect(RSQLite::SQLite(), test_db)
  on.exit({ DBI::dbDisconnect(con); unlink(test_db) })

  schema <- readLines(file.path("..", "..", "db", "schema.sql"))
  statements <- strsplit(paste(schema, collapse = "\n"), ";")[[1]]
  statements <- trimws(statements); statements <- statements[nzchar(statements)]
  for (stmt in statements) DBI::dbExecute(con, stmt)

  tables <- DBI::dbListTables(con)
  expect_true(all(c("datasets", "analyses", "users", "audit_log") %in% tables))
})

test_that("register_dataset reuses the same row for a repeated built-in dataset", {
  source(file.path("..", "..", "R", "db_connect.R"))
  test_db <- tempfile(fileext = ".sqlite")
  con <- DBI::dbConnect(RSQLite::SQLite(), test_db)
  on.exit({ DBI::dbDisconnect(con); unlink(test_db) })

  schema <- readLines(file.path("..", "..", "db", "schema.sql"))
  statements <- strsplit(paste(schema, collapse = "\n"), ";")[[1]]
  statements <- trimws(statements); statements <- statements[nzchar(statements)]
  for (stmt in statements[!grepl("^INSERT", statements)]) DBI::dbExecute(con, stmt)

  id1 <- register_dataset(con, "builtin", "Iris (flower measurements)", iris)
  id2 <- register_dataset(con, "builtin", "Iris (flower measurements)", iris)
  expect_equal(id1, id2)

  id3 <- register_dataset(con, "upload", "my_upload.csv", iris)
  expect_false(id3 == id1)
})

test_that("save_analysis inserts into analyses and logs a RUN_ action", {
  source(file.path("..", "..", "R", "db_connect.R"))
  test_db <- tempfile(fileext = ".sqlite")
  con <- DBI::dbConnect(RSQLite::SQLite(), test_db)
  on.exit({ DBI::dbDisconnect(con); unlink(test_db) })

  schema <- readLines(file.path("..", "..", "db", "schema.sql"))
  statements <- strsplit(paste(schema, collapse = "\n"), ";")[[1]]
  statements <- trimws(statements); statements <- statements[nzchar(statements)]
  for (stmt in statements[!grepl("^INSERT", statements)]) DBI::dbExecute(con, stmt)

  dsid <- register_dataset(con, "builtin", "Iris (flower measurements)", iris)
  aid <- save_analysis(con, dsid, "EDA", list(numeric_var = "Sepal.Length"), "summary text", p_value = NA)

  analyses <- DBI::dbGetQuery(con, "SELECT * FROM analyses")
  expect_equal(nrow(analyses), 1)
  expect_equal(analyses$analysis_id, aid)

  log <- DBI::dbGetQuery(con, "SELECT * FROM audit_log WHERE action = 'RUN_EDA'")
  expect_equal(nrow(log), 1)
})
