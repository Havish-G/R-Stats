########################################################################
# Statistical Analysis Studio (v2 - modular, database-backed)
# Same statistical capability as the original single-file app (EDA,
# hypothesis testing, ANOVA, regression, CLT simulation on any dataset),
# rebuilt with the same architecture pattern as the healthcare project:
# Shiny modules, a SQLite/PostgreSQL database, an audit trail, and
# downloadable per-analysis reports.
#
# First-time setup:
#   Rscript db/init_db.R
#   R -e "shiny::runApp('app.R')"
########################################################################

library(shiny)
library(bslib)
library(ggplot2)
library(dplyr)
library(DT)
library(scales)
library(DBI)

source("R/db_connect.R")
source("R/data_ingestion.R")
source("R/stats_engine.R")
source("R/report_generate.R")

source("modules/mod_data.R")
source("modules/mod_eda.R")
source("modules/mod_hypothesis.R")
source("modules/mod_anova.R")
source("modules/mod_regression.R")
source("modules/mod_clt.R")
source("modules/mod_audit.R")

app_theme <- bs_theme(
  version = 5, bootswatch = "flatly", primary = "#2C5F8A",
  base_font = font_google("Inter"), heading_font = font_google("Inter")
)

ui <- page_navbar(
  title = "Statistical Analysis Studio",
  theme = app_theme,
  id = "nav",

  nav_panel("Home",
    card(card_header("Welcome"), card_body(
      h4("From coursework to a database-backed analytics product"),
      p("This app runs exploratory data analysis, hypothesis tests, ANOVA,",
        "linear regression, and CLT simulations on any uploaded CSV (or a",
        "built-in example dataset). Every saved analysis is persisted to a",
        "database, downloadable as a standalone report, and logged in a",
        "full audit trail - the same product pattern used in the",
        "healthcare risk-screening app in this portfolio."),
      p("Start on ", strong("Data"), " to pick or upload a dataset, then",
        "explore ", strong("EDA"), ", ", strong("Hypothesis Testing"), ", ",
        strong("ANOVA"), ", ", strong("Regression"), ", or the ",
        strong("Distribution & CLT Lab"), ". Use ", strong("Analysis History"),
        " to review everything you've run and re-download any report.")
    ))
  ),
  nav_panel("Data", mod_data_ui("data")),
  nav_panel("Explore (EDA)", mod_eda_ui("eda")),
  nav_panel("Hypothesis Testing", mod_hypothesis_ui("hypothesis")),
  nav_panel("ANOVA", mod_anova_ui("anova")),
  nav_panel("Regression", mod_regression_ui("regression")),
  nav_panel("Distribution & CLT Lab", mod_clt_ui("clt")),
  nav_panel("Analysis History", mod_audit_ui("audit")),
  nav_spacer(),
  nav_item(tags$a("Source & docs", href = "README.md", target = "_blank"))
)

server <- function(input, output, session) {

  con <- get_db_connection()
  onSessionEnded(function() dbDisconnect(con))
  con_getter <- function() con

  log_action(con, user_id = 1L, action = "LOGIN", details = "Session started")

  data_ctx <- mod_data_server("data", con_getter)

  mod_eda_server("eda", con_getter, data_ctx)
  mod_hypothesis_server("hypothesis", con_getter, data_ctx)
  mod_anova_server("anova", con_getter, data_ctx)
  mod_regression_server("regression", con_getter, data_ctx)
  mod_clt_server("clt", con_getter)
  mod_audit_server("audit", con_getter)
}

shinyApp(ui, server)
