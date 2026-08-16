# =====================================================================
# modules/mod_eda.R
# Exploratory data analysis: summaries, histograms, boxplots, and a
# correlation matrix - identical behavior to the original single-file
# app, plus a "Save analysis" button that persists the run and unlocks
# a report download (new in this modular version).
# =====================================================================

mod_eda_ui <- function(id) {
  ns <- NS(id)
  layout_columns(
    col_widths = c(3, 9),
    card(
      card_header("Options"),
      card_body(
        selectInput(ns("numeric_var"), "Numeric variable", choices = NULL),
        selectInput(ns("group_var"), "Group by (optional)", choices = NULL),
        radioButtons(ns("plot_type"), "Plot type",
                     choices = c("Histogram" = "hist", "Boxplot" = "box", "Correlation matrix" = "corr")),
        hr(),
        actionButton(ns("save_analysis"), "Save this analysis", class = "btn-primary w-100"),
        uiOutput(ns("save_status")),
        downloadButton(ns("download_report"), "Download report")
      )
    ),
    card(
      card_header("Visualization"),
      card_body(
        plotOutput(ns("eda_plot"), height = 420),
        verbatimTextOutput(ns("eda_summary"))
      )
    )
  )
}

mod_eda_server <- function(id, con_getter, data_ctx) {
  moduleServer(id, function(input, output, session) {

    observeEvent(data_ctx$data(), {
      df <- data_ctx$data()
      updateSelectInput(session, "numeric_var", choices = numeric_cols(df))
      updateSelectInput(session, "group_var", choices = c("None" = "", categorical_cols(df)))
    })

    output$eda_plot <- renderPlot({
      req(input$numeric_var)
      df <- data_ctx$data()

      if (input$plot_type == "corr") {
        nums <- df[, numeric_cols(df), drop = FALSE]
        validate(need(ncol(nums) >= 2, "Need at least 2 numeric columns for a correlation matrix."))
        pairs(nums, pch = 20, main = "Pairwise scatterplots")
        return(invisible())
      }

      grp <- if (!is.null(input$group_var) && input$group_var != "") safe_factor(df[[input$group_var]]) else NULL

      if (input$plot_type == "hist") {
        p <- ggplot(df, aes(x = .data[[input$numeric_var]])) +
          geom_histogram(bins = 20, fill = "#2C5F8A", color = "white") +
          labs(title = paste("Histogram of", input$numeric_var), x = input$numeric_var, y = "Count") +
          theme_minimal(base_size = 14)
        if (!is.null(grp)) p <- p + facet_wrap(~ .data[[input$group_var]])
        p
      } else {
        if (!is.null(grp)) {
          ggplot(df, aes(x = .data[[input$group_var]], y = .data[[input$numeric_var]])) +
            geom_boxplot(fill = "#2C5F8A", alpha = 0.6) +
            labs(title = paste("Boxplot of", input$numeric_var, "by", input$group_var)) +
            theme_minimal(base_size = 14)
        } else {
          ggplot(df, aes(y = .data[[input$numeric_var]])) +
            geom_boxplot(fill = "#2C5F8A", alpha = 0.6) +
            labs(title = paste("Boxplot of", input$numeric_var)) +
            theme_minimal(base_size = 14)
        }
      }
    })

    eda_summary_text <- reactive({
      req(input$numeric_var)
      paste(capture.output(print(summary(data_ctx$data()[[input$numeric_var]]))), collapse = "\n")
    })

    output$eda_summary <- renderPrint({
      cat(eda_summary_text())
    })

    saved_analysis_id <- eventReactive(input$save_analysis, {
      con <- con_getter()
      params <- list(numeric_var = input$numeric_var, group_var = input$group_var, plot_type = input$plot_type)
      save_analysis(con, data_ctx$dataset_id(), "EDA", params, eda_summary_text(), p_value = NA)
    })

    output$save_status <- renderUI({
      req(saved_analysis_id())
      div(class = "alert alert-success mt-2", sprintf("Saved as analysis #%d", saved_analysis_id()))
    })

    output$download_report <- downloadHandler(
      filename = function() sprintf("eda_report_%s.html", format(Sys.time(), "%Y%m%d_%H%M%S")),
      content = function(file) {
        req(saved_analysis_id())
        con <- con_getter()
        generate_analysis_report(con, saved_analysis_id(), data_ctx$dataset_name(), "EDA",
                                   eda_summary_text(), decision = NA, output_file = file)
      }
    )
  })
}
