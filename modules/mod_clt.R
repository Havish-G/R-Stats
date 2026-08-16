# =====================================================================
# modules/mod_clt.R
# Distribution & CLT Lab - simulate the sampling distribution of the
# mean for Normal/Beta/Uniform/Exponential populations, via
# R/stats_engine.R::simulate_clt(). Doesn't depend on the active
# dataset (it's a simulation), so no dataset_id is required to save it -
# saved under a synthetic "Simulation" dataset row instead.
# =====================================================================

mod_clt_ui <- function(id) {
  ns <- NS(id)
  layout_columns(
    col_widths = c(4, 8),
    card(
      card_header("Setup"),
      card_body(
        selectInput(ns("dist"), "Distribution",
                    choices = c("Normal" = "norm", "Beta" = "beta",
                                "Uniform" = "unif", "Exponential" = "exp")),
        conditionalPanel(sprintf("input['%s'] == 'norm'", ns("dist")),
                         numericInput(ns("mean"), "Mean", 0), numericInput(ns("sd"), "SD", 1, min = 0.001)),
        conditionalPanel(sprintf("input['%s'] == 'beta'", ns("dist")),
                         numericInput(ns("shape1"), "Shape1", 2, min = 0.01), numericInput(ns("shape2"), "Shape2", 5, min = 0.01)),
        conditionalPanel(sprintf("input['%s'] == 'unif'", ns("dist")),
                         numericInput(ns("min"), "Min", 0), numericInput(ns("max"), "Max", 1)),
        conditionalPanel(sprintf("input['%s'] == 'exp'", ns("dist")),
                         numericInput(ns("rate"), "Rate", 1, min = 0.001)),
        sliderInput(ns("n"), "Sample size (n) per draw", min = 1, max = 200, value = 5),
        sliderInput(ns("reps"), "Number of simulated samples", min = 100, max = 10000, value = 2000, step = 100),
        hr(),
        actionButton(ns("save_analysis"), "Save this analysis", class = "btn-primary w-100"),
        uiOutput(ns("save_status")),
        downloadButton(ns("download_report"), "Download report")
      )
    ),
    card(
      card_header("Sampling distribution of the mean"),
      card_body(
        plotOutput(ns("pop_plot"), height = 220),
        plotOutput(ns("clt_plot"), height = 320),
        verbatimTextOutput(ns("clt_stats"))
      )
    )
  )
}

mod_clt_server <- function(id, con_getter) {
  moduleServer(id, function(input, output, session) {

    clt_params <- reactive({
      switch(input$dist,
        norm = list(mean = input$mean, sd = input$sd),
        beta = list(shape1 = input$shape1, shape2 = input$shape2),
        unif = list(min = input$min, max = input$max),
        exp  = list(rate = input$rate)
      )
    })

    clt_sample <- reactive({
      simulate_clt(input$dist, clt_params(), input$n, input$reps)
    })

    output$pop_plot <- renderPlot({
      x <- switch(input$dist,
        norm = { xs <- seq(input$mean - 4*input$sd, input$mean + 4*input$sd, length.out = 300)
                 data.frame(x = xs, d = dnorm(xs, input$mean, input$sd)) },
        beta = { xs <- seq(0, 1, length.out = 300)
                 data.frame(x = xs, d = dbeta(xs, input$shape1, input$shape2)) },
        unif = { xs <- seq(input$min, input$max, length.out = 300)
                 data.frame(x = xs, d = dunif(xs, input$min, input$max)) },
        exp  = { xs <- seq(0, qexp(0.999, input$rate), length.out = 300)
                 data.frame(x = xs, d = dexp(xs, input$rate)) }
      )
      ggplot(x, aes(x, d)) + geom_line(color = "#2C5F8A", linewidth = 1) +
        labs(title = "Population distribution", x = "value", y = "density") +
        theme_minimal(base_size = 13)
    })

    clt_stats_text <- reactive({
      m <- rowMeans(clt_sample())
      sprintf("Mean of sample means: %.4f\nSD of sample means (standard error): %.4f\nShapiro-Wilk normality p-value: %.4f\n",
              mean(m), sd(m), tryCatch(shapiro.test(sample(m, min(5000, length(m))))$p.value, error = function(e) NA))
    })

    output$clt_plot <- renderPlot({
      m <- rowMeans(clt_sample())
      df <- data.frame(mean = m)
      ggplot(df, aes(x = mean)) +
        geom_histogram(aes(y = after_stat(density)), bins = 30, fill = "#2C5F8A", color = "white") +
        stat_function(fun = dnorm, args = list(mean = mean(m), sd = sd(m)), color = "firebrick", linewidth = 1) +
        labs(title = sprintf("Sampling distribution of the mean (n = %d per sample)", input$n),
             x = "sample mean", y = "density") +
        theme_minimal(base_size = 14)
    })

    output$clt_stats <- renderPrint({ cat(clt_stats_text()) })

    saved_analysis_id <- eventReactive(input$save_analysis, {
      con <- con_getter()
      sim_dataset_id <- register_dataset(con, "builtin", "Simulation (no external data)",
                                            data.frame(x = numeric(0)))
      params <- c(list(dist = input$dist, n = input$n, reps = input$reps), clt_params())
      save_analysis(con, sim_dataset_id, "CLT", params, clt_stats_text(), p_value = NA)
    })

    output$save_status <- renderUI({
      req(saved_analysis_id())
      div(class = "alert alert-success mt-2", sprintf("Saved as analysis #%d", saved_analysis_id()))
    })

    output$download_report <- downloadHandler(
      filename = function() sprintf("clt_report_%s.html", format(Sys.time(), "%Y%m%d_%H%M%S")),
      content = function(file) {
        req(saved_analysis_id())
        con <- con_getter()
        generate_analysis_report(con, saved_analysis_id(), "Simulation (no external data)", "CLT",
                                   clt_stats_text(), decision = NA, output_file = file)
      }
    )
  })
}
