# =====================================================================
# modules/mod_hypothesis.R
# One-sample / two-sample t-tests and the one-sample Wilcoxon test,
# using R/stats_engine.R so the actual test logic is unit-tested and
# shared, not re-implemented inline.
# =====================================================================

mod_hypothesis_ui <- function(id) {
  ns <- NS(id)
  layout_columns(
    col_widths = c(4, 8),
    card(
      card_header("Setup"),
      card_body(
        selectInput(ns("numeric_var"), "Numeric variable", choices = NULL),
        selectInput(ns("group_var"), "Grouping variable (optional, for 2-sample test)", choices = NULL),
        radioButtons(ns("test_type"), "Test type",
                     choices = c("One-sample t-test" = "one_t",
                                 "Two-sample t-test" = "two_t",
                                 "Wilcoxon (one-sample)" = "wilcox")),
        conditionalPanel(sprintf("input['%s'] != 'two_t'", ns("test_type")),
                         numericInput(ns("mu0"), "Hypothesized value (mu0)", value = 0)),
        radioButtons(ns("alternative"), "Alternative hypothesis",
                     choices = c("two-sided" = "two.sided", "less" = "less", "greater" = "greater")),
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
        verbatimTextOutput(ns("test_result")),
        textOutput(ns("test_decision")),
        plotOutput(ns("test_plot"), height = 320)
      )
    )
  )
}

mod_hypothesis_server <- function(id, con_getter, data_ctx) {
  moduleServer(id, function(input, output, session) {

    observeEvent(data_ctx$data(), {
      df <- data_ctx$data()
      updateSelectInput(session, "numeric_var", choices = numeric_cols(df))
      updateSelectInput(session, "group_var", choices = c("None" = "", categorical_cols(df)))
    })

    test_output <- reactive({
      req(input$numeric_var)
      df <- data_ctx$data()
      x <- df[[input$numeric_var]]

      if (input$test_type == "one_t") {
        run_one_sample_test(x, input$mu0, input$alternative, input$alpha, method = "t")
      } else if (input$test_type == "wilcox") {
        run_one_sample_test(x, input$mu0, input$alternative, input$alpha, method = "wilcox")
      } else {
        req(input$group_var, input$group_var != "")
        run_two_sample_ttest(x, df[[input$group_var]], input$alternative, input$alpha)
      }
    })

    output$test_result <- renderPrint({ req(test_output()); print(test_output()$result) })
    output$test_decision <- renderText({ req(test_output()); test_output()$decision })

    output$test_plot <- renderPlot({
      req(input$numeric_var)
      df <- data_ctx$data()
      if (input$test_type == "two_t" && !is.null(input$group_var) && input$group_var != "") {
        ggplot(df, aes(x = .data[[input$group_var]], y = .data[[input$numeric_var]])) +
          geom_boxplot(fill = "#2C5F8A", alpha = 0.6) + theme_minimal(base_size = 14)
      } else {
        ggplot(df, aes(x = .data[[input$numeric_var]])) +
          geom_histogram(bins = 20, fill = "#2C5F8A", color = "white") +
          geom_vline(xintercept = input$mu0, color = "firebrick", linetype = "dashed", linewidth = 1) +
          labs(subtitle = "Dashed line = hypothesized value (mu0)") +
          theme_minimal(base_size = 14)
      }
    })

    saved_analysis_id <- eventReactive(input$save_analysis, {
      req(test_output())
      con <- con_getter()
      params <- list(numeric_var = input$numeric_var, group_var = input$group_var,
                      test_type = input$test_type, mu0 = input$mu0,
                      alternative = input$alternative, alpha = input$alpha)
      save_analysis(con, data_ctx$dataset_id(), "HYPOTHESIS", params,
                     test_output()$summary, p_value = test_output()$p_value)
    })

    output$save_status <- renderUI({
      req(saved_analysis_id())
      div(class = "alert alert-success mt-2", sprintf("Saved as analysis #%d", saved_analysis_id()))
    })

    output$download_report <- downloadHandler(
      filename = function() sprintf("hypothesis_report_%s.html", format(Sys.time(), "%Y%m%d_%H%M%S")),
      content = function(file) {
        req(saved_analysis_id())
        con <- con_getter()
        generate_analysis_report(con, saved_analysis_id(), data_ctx$dataset_name(), "HYPOTHESIS",
                                   test_output()$summary, decision = test_output()$decision, output_file = file)
      }
    )
  })
}
