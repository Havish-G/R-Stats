# =====================================================================
# R/data_ingestion.R
# Built-in example datasets + helpers for classifying columns as
# numeric/categorical. Ported from the original single-file
# Statistical Analysis Studio app, unchanged in behavior.
# =====================================================================

purdue_hours <- c(3.06, 3.35, 2.36, 2.86, 3.23, 3.41, 3.78, 3.28, 4.21, 3.12,
                   3.33, 2.75, 2.56, 2.25, 4.20, 2.01, 3.84, 3.08, 3.88, 2.09,
                   4.04, 2.11, 4.22, 4.30)

builtin_datasets <- list(
  "Iris (flower measurements)"      = datasets::iris,
  "PlantGrowth (treatment yields)"  = datasets::PlantGrowth,
  "Purdue Mobile-Use Survey (hrs)"  = data.frame(daily_hours = purdue_hours),
  "ToothGrowth (vitamin C study)"   = datasets::ToothGrowth,
  "mtcars (car specs)"              = datasets::mtcars
)

is_categorical <- function(x) {
  is.factor(x) || is.character(x) || (is.numeric(x) && length(unique(x)) <= 8)
}

numeric_cols <- function(df) names(df)[sapply(df, is.numeric)]
categorical_cols <- function(df) names(df)[sapply(df, is_categorical)]

safe_factor <- function(x) as.factor(x)

#' Read an uploaded CSV file with the user's chosen header/delimiter options.
read_uploaded_csv <- function(path, header = TRUE, sep = ",") {
  read.csv(path, header = header, sep = sep)
}
