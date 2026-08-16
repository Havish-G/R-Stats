# =====================================================================
# modules/mod_anova.R
# One-way ANOVA + Tukey HSD, via R/stats_engine.R::run_anova().
# =====================================================================

mod_anova_ui <- function(id) {
  ns <- NS(id)
  layout_columns(
    col_widths = c(4, 8),
    card(
      card_header("Setup"),
      card_body(
        selectInput(ns("response"), "Numeric response", choices = NULL),
        selectInput(ns("group"), "Categorical group (2+ levels)", choices = NULL),
        sliderInput(ns("alpha"), "Significance level (alpha)", min = 0.01, max = 0.20, value = 0.05, step = 0.01),
        hr(),
        actionButton(ns("save_analysis"), "Save this analysis", class = "btn-primary w-100"),
        uiOutput(ns("save_status")),
        downloadButton(ns("download_report"), "Download report")
      )
    ),
    card(
      card_header("Results"),
      card_body(
        plotOutput(ns("anova_plot"), height = 320),
        verbatimTextOutput(ns("anova_summary")),
        h5("Tukey HSD post-hoc comparisons"),
        DTOutput(ns("tukey_table"))
      )
    )
  )
}

mod_anova_server <- function(id, con_getter, data_ctx) {
  moduleServer(id, function(input, output, session) {

    observeEvent(data_ctx$data(), {
      df <- data_ctx$data()
      updateSelectInput(session, "response", choices = numeric_cols(df))
      updateSelectInput(session, "group", choices = categorical_cols(df))
    })

    anova_output <- reactive({
      req(input$response, input$group)
      run_anova(data_ctx$data(), input$response, input$group, input$alpha)
    })

    output$anova_plot <- renderPlot({
      req(input$response, input$group)
      df <- data_ctx$data()
      ggplot(df, aes(x = .data[[input$group]], y = .data[[input$response]])) +
        geom_boxplot(fill = "#2C5F8A", alpha = 0.6) +
        labs(title = paste(input$response, "by", input$group)) +
        theme_minimal(base_size = 14)
    })

    output$anova_summary <- renderPrint({ req(anova_output()); summary(anova_output()$model) })

    output$tukey_table <- renderDT({
      req(anova_output())
      tbl <- as.data.frame(anova_output()$tukey[[1]])
      tbl$comparison <- rownames(tbl)
      tbl <- tbl[, c("comparison", setdiff(names(tbl), "comparison"))]
      datatable(tbl, options = list(dom = "t"), rownames = FALSE) |>
        DT::formatRound(columns = 2:5, digits = 4)
    })

    saved_analysis_id <- eventReactive(input$save_analysis, {
      req(anova_output())
      con <- con_getter()
      params <- list(response = input$response, group = input$group, alpha = input$alpha)
      save_analysis(con, data_ctx$dataset_id(), "ANOVA", params,
                     anova_output()$summary, p_value = anova_output()$p_value)
    })

    output$save_status <- renderUI({
      req(saved_analysis_id())
      div(class = "alert alert-success mt-2", sprintf("Saved as analysis #%d", saved_analysis_id()))
    })

    output$download_report <- downloadHandler(
      filename = function() sprintf("anova_report_%s.html", format(Sys.time(), "%Y%m%d_%H%M%S")),
      content = function(file) {
        req(saved_analysis_id())
        con <- con_getter()
        generate_analysis_report(con, saved_analysis_id(), data_ctx$dataset_name(), "ANOVA",
                                   anova_output()$summary, decision = anova_output()$decision, output_file = file)
      }
    )
  })
}
