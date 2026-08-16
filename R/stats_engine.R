# =====================================================================
# R/stats_engine.R
# Pure, testable statistical functions - the same routines the original
# single-file app ran inline inside renderPlot()/renderPrint() blocks,
# pulled out here so they're unit-testable and reusable (mirrors
# R/predict.R in the healthcare project: one place the "model" logic
# lives, called from a thin Shiny layer).
# =====================================================================

decision_text <- function(p, alpha) {
  if (is.na(p)) return("Not enough data to compute a p-value.")
  if (p < alpha) {
    sprintf("p-value (%.4f) < alpha (%.2f) -> Reject H0. Statistically significant evidence against the null hypothesis.", p, alpha)
  } else {
    sprintf("p-value (%.4f) >= alpha (%.2f) -> Fail to reject H0. Not enough evidence against the null hypothesis.", p, alpha)
  }
}

#' One-sample t-test or Wilcoxon signed-rank test.
run_one_sample_test <- function(x, mu0, alternative = "two.sided", alpha = 0.05, method = "t") {
  x <- x[!is.na(x)]
  result <- if (method == "wilcox") {
    wilcox.test(x, mu = mu0, alternative = alternative)
  } else {
    t.test(x, mu = mu0, alternative = alternative, conf.level = 1 - alpha)
  }
  list(
    result   = result,
    p_value  = result$p.value,
    decision = decision_text(result$p.value, alpha),
    summary  = paste(capture.output(print(result)), collapse = "\n")
  )
}

#' Two-sample (independent) t-test.
run_two_sample_ttest <- function(x, group, alternative = "two.sided", alpha = 0.05) {
  group <- droplevels(as.factor(group))
  if (nlevels(group) != 2) stop("Two-sample t-test requires a grouping variable with exactly 2 levels.")
  result <- t.test(x ~ group, alternative = alternative, conf.level = 1 - alpha)
  list(
    result   = result,
    p_value  = result$p.value,
    decision = decision_text(result$p.value, alpha),
    summary  = paste(capture.output(print(result)), collapse = "\n")
  )
}

#' One-way ANOVA + Tukey HSD post-hoc comparisons.
run_anova <- function(df, response, group, alpha = 0.05) {
  df[[group]] <- as.factor(df[[group]])
  if (nlevels(df[[group]]) < 2) stop("Group variable needs at least 2 levels.")
  model <- aov(as.formula(paste0("`", response, "` ~ `", group, "`")), data = df)
  tukey <- TukeyHSD(model, conf.level = 1 - alpha)
  p_overall <- summary(model)[[1]][["Pr(>F)"]][1]
  list(
    model    = model,
    tukey    = tukey,
    p_value  = p_overall,
    decision = decision_text(p_overall, alpha),
    summary  = paste(capture.output(print(summary(model))), collapse = "\n")
  )
}

#' Build and fit a linear model, with an optional single interaction term
#' between the first numeric and first categorical predictor.
run_regression <- function(df, response, predictors, interaction = FALSE) {
  for (p in predictors) if (is.character(df[[p]])) df[[p]] <- as.factor(df[[p]])

  term <- paste0("`", predictors, "`", collapse = " + ")
  if (isTRUE(interaction)) {
    num_p <- predictors[sapply(df[predictors], is.numeric)]
    cat_p <- predictors[sapply(df[predictors], is.factor)]
    if (length(num_p) >= 1 && length(cat_p) >= 1) {
      term <- paste0(term, " + `", num_p[1], "`:`", cat_p[1], "`")
    }
  }
  formula <- as.formula(paste0("`", response, "` ~ ", term))
  model <- lm(formula, data = df)
  list(
    model   = model,
    formula = formula,
    summary = paste(capture.output(print(summary(model))), collapse = "\n")
  )
}

#' Simulate the sampling distribution of the mean for CLT demonstrations.
#' Returns a reps x n matrix of draws (rowMeans gives the sample means).
simulate_clt <- function(dist = "norm", params = list(), n = 5, reps = 2000) {
  switch(dist,
    norm = matrix(rnorm(n * reps, params$mean %||% 0, params$sd %||% 1), nrow = reps),
    beta = matrix(rbeta(n * reps, params$shape1 %||% 2, params$shape2 %||% 5), nrow = reps),
    unif = matrix(runif(n * reps, params$min %||% 0, params$max %||% 1), nrow = reps),
    exp  = matrix(rexp(n * reps, params$rate %||% 1), nrow = reps),
    stop("Unsupported distribution: ", dist)
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a
