source(file.path("..", "..", "R", "stats_engine.R"))

test_that("run_one_sample_test drops NA values instead of erroring", {
  x <- c(rnorm(29, mean = 5), NA)
  res <- run_one_sample_test(x, mu0 = 0, alternative = "two.sided", alpha = 0.05, method = "t")
  expect_false(is.na(res$p_value))
  expect_true(res$result$parameter["df"] == 28)  # NA dropped -> 29 obs -> df = 28
})

test_that("run_two_sample_ttest errors when the grouping variable has only 1 level", {
  x <- rnorm(20)
  g <- factor(rep("only_group", 20))
  expect_error(run_two_sample_ttest(x, g), "exactly 2 levels")
})

test_that("run_anova errors when the group variable has only 1 level", {
  df <- data.frame(y = rnorm(20), g = rep("only_group", 20))
  expect_error(run_anova(df, "y", "g"), "at least 2 levels")
})

test_that("run_regression adds an interaction term when requested", {
  df <- data.frame(
    y = 1:40 + rnorm(40, 0, 0.1),
    x1 = 1:40,
    g = rep(c("A", "B"), 20)
  )
  res_no_int <- run_regression(df, "y", c("x1", "g"), interaction = FALSE)
  res_int    <- run_regression(df, "y", c("x1", "g"), interaction = TRUE)

  expect_false(any(grepl(":", names(coef(res_no_int$model)))))
  expect_true(any(grepl("x1:gB|gB:x1", names(coef(res_int$model)))))
})

test_that("run_regression with only categorical predictors doesn't error looking for a numeric one to interact with", {
  df <- data.frame(y = rnorm(30), g1 = rep(c("A", "B"), 15), g2 = rep(c("X", "Y", "Z"), 10))
  res <- run_regression(df, "y", c("g1", "g2"), interaction = TRUE)
  expect_s3_class(res$model, "lm")
})

test_that("simulate_clt produces correctly shaped output for uniform and exponential too", {
  m_unif <- simulate_clt("unif", list(min = 0, max = 10), n = 8, reps = 200)
  expect_equal(dim(m_unif), c(200, 8))
  expect_true(all(m_unif >= 0 & m_unif <= 10))

  m_exp <- simulate_clt("exp", list(rate = 2), n = 6, reps = 150)
  expect_equal(dim(m_exp), c(150, 6))
  expect_true(all(m_exp >= 0))
})

test_that("simulate_clt falls back to sensible defaults when params are empty", {
  m <- simulate_clt("norm", list(), n = 5, reps = 100)
  expect_equal(dim(m), c(100, 5))
  expect_equal(round(mean(m), 0), 0)  # default mean = 0
})

test_that("decision_text at the exact alpha boundary reads as fail-to-reject (strict <)", {
  expect_match(decision_text(0.05, 0.05), "Fail to reject H0")
})
