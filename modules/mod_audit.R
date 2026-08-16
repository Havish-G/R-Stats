# =====================================================================
# modules/mod_audit.R
# Shiny module: analysis history + audit log - the compliance/ops view,
# mirroring modules/mod_audit.R in the healthcare project. Doubles as a
# "saved work" browser: every analysis saved from the other four tabs
# shows up here with its dataset, parameters, and timestamp.
# =====================================================================

mod_audit_ui <- function(id) {
  ns <- NS(id)
  layout_columns(
    col_widths = c(7, 5),
    card(
      card_header("Analysis history"),
      card_body(
        selectInput(ns("type_filter"), "Filter by analysis type",
                    choices = c("All", "EDA", "HYPOTHESIS", "ANOVA", "REGRESSION", "CLT")),
        DTOutput(ns("analyses_table"))
      )
    ),
    card(
      card_header("Audit log (dataset loads, analyses run, reports generated)"),
      card_body(
        selectInput(ns("action_filter"), "Filter by action",
                    choices = c("All", "LOGIN", "LOAD_DATASET", "RUN_EDA", "RUN_HYPOTHESIS",
                                "RUN_ANOVA", "RUN_REGRESSION", "RUN_CLT", "GENERATE_REPORT")),
        DTOutput(ns("audit_table"))
      )
    )
  )
}

mod_audit_server <- function(id, con_getter) {
  moduleServer(id, function(input, output, session) {

    output$analyses_table <- renderDT({
      con <- con_getter()
      q <- "SELECT a.analysis_id, d.name AS dataset, a.analysis_type, a.p_value, a.created_at
            FROM analyses a LEFT JOIN datasets d ON a.dataset_id = d.dataset_id"
      if (input$type_filter != "All") {
        q <- paste0(q, sprintf(" WHERE a.analysis_type = '%s'", input$type_filter))
      }
      q <- paste0(q, " ORDER BY a.created_at DESC LIMIT 200")
      df <- DBI::dbGetQuery(con, q)
      datatable(df, options = list(pageLength = 8, scrollX = TRUE)) |>
        DT::formatRound(columns = "p_value", digits = 4)
    })

    output$audit_table <- renderDT({
      con <- con_getter()
      q <- "SELECT log_id, user_id, action, entity, entity_id, details, created_at FROM audit_log"
      if (input$action_filter != "All") {
        q <- paste0(q, sprintf(" WHERE action = '%s'", input$action_filter))
      }
      q <- paste0(q, " ORDER BY created_at DESC LIMIT 500")
      df <- DBI::dbGetQuery(con, q)
      datatable(df, options = list(pageLength = 10, scrollX = TRUE))
    })
  })
}
