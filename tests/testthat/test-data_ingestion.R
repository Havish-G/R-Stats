source(file.path("..", "..", "R", "data_ingestion.R"))

test_that("is_categorical classifies factors, characters, and low-cardinality numerics", {
  expect_true(is_categorical(factor(c("a", "b"))))
  expect_true(is_categorical(c("a", "b", "c")))
  expect_true(is_categorical(c(1, 1, 2, 2, 3)))          # numeric, <=8 unique values
  expect_false(is_categorical(1:20))                      # numeric, >8 unique values
  expect_false(is_categorical(rnorm(50)))                 # continuous numeric
})

test_that("is_categorical treats Excel-style date/datetime columns as categorical", {
  expect_true(is_categorical(as.Date(c("2024-01-01", "2024-02-01"))))
  expect_true(is_categorical(as.POSIXct(c("2024-01-01 10:00:00", "2024-01-02 11:00:00"))))
})

test_that("numeric_cols and categorical_cols split a mixed data frame correctly", {
  df <- data.frame(
    age = c(20, 30, 40, 50, 60, 70, 80, 90, 100, 110),  # 10 unique -> numeric, not categorical
    group = c("a", "b", "a", "b", "a", "b", "a", "b", "a", "b"),
    flag = c(0, 1, 0, 1, 0, 1, 0, 1, 0, 1)               # 2 unique -> categorical despite being numeric
  )
  expect_setequal(numeric_cols(df), c("age", "flag"))
  expect_setequal(categorical_cols(df), c("group", "flag"))
})

test_that("read_uploaded_csv respects header and delimiter options", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c("a;b", "1;2", "3;4"), tmp)
  df <- read_uploaded_csv(tmp, header = TRUE, sep = ";")
  expect_equal(names(df), c("a", "b"))
  expect_equal(nrow(df), 2)
  unlink(tmp)
})

test_that("read_uploaded_csv handles a file with no header row", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c("1,2", "3,4"), tmp)
  df <- read_uploaded_csv(tmp, header = FALSE, sep = ",")
  expect_equal(nrow(df), 2)
  expect_equal(ncol(df), 2)
  unlink(tmp)
})

test_that("builtin_datasets contains the expected named data frames", {
  expect_true(all(c(
    "Iris (flower measurements)", "PlantGrowth (treatment yields)",
    "Purdue Mobile-Use Survey (hrs)", "ToothGrowth (vitamin C study)", "mtcars (car specs)"
  ) %in% names(builtin_datasets)))
  expect_true(all(sapply(builtin_datasets, is.data.frame)))
  expect_true(all(sapply(builtin_datasets, nrow) > 0))
})
