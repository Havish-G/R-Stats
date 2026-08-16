source(file.path("..", "..", "R", "stats_engine.R"))

test_that("run_one_sample_test returns a decision consistent with the p-value", {
  set.seed(1)
  x <- rnorm(30, mean = 5, sd = 1)
  res <- run_one_sample_test(x, mu0 = 0, alternative = "two.sided", alpha = 0.05, method = "t")
  expect_true(res$p_value < 0.05)
  expect_match(res$decision, "Reject H0")
})

test_that("run_two_sample_ttest errors on more than 2 groups", {
  set.seed(1)
  x <- rnorm(30)
  g <- factor(sample(c("a", "b", "c"), 30, replace = TRUE))
  expect_error(run_two_sample_ttest(x, g), "exactly 2 levels")
})

test_that("run_anova flags a significant difference when group means differ a lot", {
  set.seed(1)
  df <- data.frame(
    y = c(rnorm(20, 0), rnorm(20, 10)),
    g = rep(c("A", "B"), each = 20)
  )
  res <- run_anova(df, "y", "g", alpha = 0.05)
  expect_true(res$p_value < 0.05)
  expect_s3_class(res$tukey, "TukeyHSD")
})

test_that("run_regression fits a model and reports the requested predictors", {
  df <- data.frame(y = 1:20 + rnorm(20, 0, 0.1), x1 = 1:20, g = rep(c("A", "B"), 10))
  res <- run_regression(df, "y", c("x1", "g"), interaction = FALSE)
  expect_s3_class(res$model, "lm")
  expect_true(all(c("x1", "gB") %in% names(coef(res$model))))
})

test_that("simulate_clt returns a reps x n matrix for each supported distribution", {
  m <- simulate_clt("norm", list(mean = 0, sd = 1), n = 5, reps = 100)
  expect_equal(dim(m), c(100, 5))
  m2 <- simulate_clt("beta", list(shape1 = 2, shape2 = 5), n = 4, reps = 50)
  expect_equal(dim(m2), c(50, 4))
  expect_error(simulate_clt("not_a_dist"), "Unsupported distribution")
})

test_that("decision_text matches the alpha comparison", {
  expect_match(decision_text(0.01, 0.05), "Reject H0")
  expect_match(decision_text(0.5, 0.05), "Fail to reject H0")
  expect_match(decision_text(NA, 0.05), "Not enough data")
})
