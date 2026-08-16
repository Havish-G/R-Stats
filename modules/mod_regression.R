# =====================================================================
# modules/mod_regression.R
# Linear regression with an optional interaction term and a live
# prediction form, via R/stats_engine.R::run_regression().
# =====================================================================

mod_regression_ui <- function(id) {
  ns <- NS(id)
  layout_columns(
    col_widths = c(4, 8),
    card(
      card_header("Setup"),
      card_body(
        selectInput(ns("response"), "Response (numeric)", choices = NULL),
        selectInput(ns("predictors"), "Predictors", choices = NULL, multiple = TRUE),
        checkboxInput(ns("interaction"), "Include interaction (first numeric x first categorical predictor)", FALSE),
        hr(),
        uiOutput(ns("predict_inputs")),
        hr(),
        actionButton(ns("save_analysis"), "Save this analysis", class = "btn-primary w-100"),
        uiOutput(ns("save_status")),
        downloadButton(ns("download_report"), "Download report")
      )
    ),
    card(
      card_header("Model results"),
      card_body(
        verbatimTextOutput(ns("reg_summary")),
        plotOutput(ns("reg_diag_plot"), height = 320),
        h5("Live prediction"),
        verbatimTextOutput(ns("reg_prediction"))
      )
    )
  )
}

mod_regression_server <- function(id, con_getter, data_ctx) {
  moduleServer(id, function(input, output, session) {

    observeEvent(data_ctx$data(), {
      df <- data_ctx$data()
      num <- numeric_cols(df); cat <- categorical_cols(df)
      updateSelectInput(session, "response", choices = num)
      updateSelectInput(session, "predictors", choices = c(num, cat))
    })

    reg_output <- reactive({
      req(input$response, length(input$predictors) >= 1)
      run_regression(data_ctx$data(), input$response, input$predictors, input$interaction)
    })

    output$reg_summary <- renderPrint({ req(reg_output()); summary(reg_output()$model) })

    output$reg_diag_plot <- renderPlot({
      req(reg_output())
      m <- reg_output()$model
      par(mfrow = c(1, 2))
      plot(m, which = 1, main = "Residuals vs Fitted")
      plot(m, which = 2, main = "Normal Q-Q")
    })

    output$predict_inputs <- renderUI({
      req(input$predictors)
      df <- data_ctx$data()
      inputs <- lapply(input$predictors, function(p) {
        col <- df[[p]]
        if (is.numeric(col) && !is_categorical(col)) {
          sliderInput(NS(id, paste0("pred_", p)), p, min = min(col, na.rm = TRUE), max = max(col, na.rm = TRUE),
                      value = mean(col, na.rm = TRUE))
        } else {
          selectInput(NS(id, paste0("pred_", p)), p, choices = sort(unique(as.character(col))))
        }
      })
      tagList(h6("Set predictor values:"), inputs)
    })

    prediction_text <- reactive({
      req(input$predictors, reg_output())
      m <- reg_output()$model
      newdata <- as.data.frame(lapply(input$predictors, function(p) {
        val <- input[[paste0("pred_", p)]]
        col <- data_ctx$data()[[p]]
        if (is.numeric(col) && !is_categorical(col)) as.numeric(val) else val
      }))
      names(newdata) <- input$predictors
      pred <- tryCatch(predict(m, newdata = newdata, interval = "prediction"),
                         error = function(e) NULL)
      if (is.null(pred)) {
        "Set all predictor values to see a prediction."
      } else {
        sprintf("Predicted %s: %.3f\n95%% prediction interval: [%.3f, %.3f]",
                input$response, pred[1, "fit"], pred[1, "lwr"], pred[1, "upr"])
      }
    })

    output$reg_prediction <- renderPrint({ cat(prediction_text()) })

    saved_analysis_id <- eventReactive(input$save_analysis, {
      req(reg_output())
      con <- con_getter()
      params <- list(response = input$response, predictors = paste(input$predictors, collapse = ","),
                      interaction = input$interaction)
      save_analysis(con, data_ctx$dataset_id(), "REGRESSION", params, reg_output()$summary, p_value = NA)
    })

    output$save_status <- renderUI({
      req(saved_analysis_id())
      div(class = "alert alert-success mt-2", sprintf("Saved as analysis #%d", saved_analysis_id()))
    })

    output$download_report <- downloadHandler(
      filename = function() sprintf("regression_report_%s.html", format(Sys.time(), "%Y%m%d_%H%M%S")),
      content = function(file) {
        req(saved_analysis_id())
        con <- con_getter()
        generate_analysis_report(con, saved_analysis_id(), data_ctx$dataset_name(), "REGRESSION",
                                   reg_output()$summary, decision = NA, output_file = file)
      }
    )
  })
}
