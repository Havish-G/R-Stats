# =====================================================================
# R/report_generate.R
# Renders reports/report_template.Rmd into a downloadable HTML file for
# any saved analysis (EDA, hypothesis test, ANOVA, regression, or CLT
# simulation). Mirrors R/report_generate.R in the healthcare project.
# =====================================================================

library(rmarkdown)
source("R/db_connect.R")

#' @param analysis_id the row just saved via save_analysis()
#' @param dataset_name display name of the dataset analyzed
#' @param analysis_type one of EDA/HYPOTHESIS/ANOVA/REGRESSION/CLT
#' @param result_summary the printed statistical output
#' @param decision optional plain-language decision sentence (NA for EDA/CLT)
generate_analysis_report <- function(con, analysis_id, dataset_name, analysis_type,
                                       result_summary, decision = NA,
                                       output_file, user_id = 1L) {

  rmarkdown::render(
    input       = "reports/report_template.Rmd",
    output_file = output_file,
    output_format = "html_document",
    params = list(
      analysis_id     = analysis_id,
      dataset_name    = dataset_name,
      analysis_type   = analysis_type,
      result_summary  = result_summary,
      decision        = decision,
      generated_at    = Sys.time()
    ),
    envir = new.env()
  )

  log_action(con, user_id = user_id, action = "GENERATE_REPORT", entity = "analyses",
             entity_id = analysis_id, details = paste("Report file:", basename(output_file)))

  output_file
}
