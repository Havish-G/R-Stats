# =====================================================================
# modules/mod_data.R
# Shiny module: choose a dataset (built-in example or CSV upload).
# Registers the dataset in the `datasets` table the first time it's
# loaded and exposes the active data frame + its dataset_id to every
# other module.
# =====================================================================

max_upload_mb <- 25
options(shiny.maxRequestSize = max_upload_mb * 1024^2)

mod_data_ui <- function(id) {
  ns <- NS(id)
  layout_columns(
    col_widths = c(4, 8),
    card(
      card_header("Choose a dataset"),
      card_body(
        radioButtons(ns("data_source"), NULL,
                     choices = c("Built-in example" = "builtin", "Upload my own CSV" = "upload"),
                     selected = "builtin"),
        conditionalPanel(
          sprintf("input['%s'] == 'builtin'", ns("data_source")),
          selectInput(ns("builtin_choice"), "Example dataset", choices = names(builtin_datasets))
        ),
        conditionalPanel(
          sprintf("input['%s'] == 'upload'", ns("data_source")),
          fileInput(ns("upload_file"), "Upload CSV", accept = c(".csv")),
          checkboxInput(ns("upload_header"), "First row is a header", TRUE),
          selectInput(ns("upload_sep"), "Delimiter", choices = c("Comma" = ",", "Semicolon" = ";", "Tab" = "\t"))
        ),
        hr(),
        uiOutput(ns("data_summary_text"))
      )
    ),
    card(
      card_header("Preview"),
      card_body(DTOutput(ns("data_preview")))
    )
  )
}

#' @return a list of reactives: $data (data frame), $dataset_id (integer)
mod_data_server <- function(id, con_getter) {
  moduleServer(id, function(input, output, session) {

    active_data <- reactive({
      if (input$data_source == "builtin") {
        req(input$builtin_choice)
        builtin_datasets[[input$builtin_choice]]
      } else {
        req(input$upload_file)
        df <- tryCatch(
          read_uploaded_csv(input$upload_file$datapath, input$upload_header, input$upload_sep),
          error = function(e) NULL
        )
        validate(need(!is.null(df), "Could not parse the uploaded file. Check delimiter/header settings."))
        df
      }
    })

    dataset_name <- reactive({
      if (input$data_source == "builtin") input$builtin_choice else input$upload_file$name
    })

    dataset_id <- reactive({
      con <- con_getter()
      register_dataset(con, input$data_source, dataset_name(), active_data())
    })

    observeEvent(dataset_id(), {
      con <- con_getter()
      log_action(con, user_id = 1L, action = "LOAD_DATASET", entity = "datasets",
                 entity_id = dataset_id(), details = dataset_name())
    })

    output$data_preview <- renderDT({
      datatable(active_data(), options = list(pageLength = 8, scrollX = TRUE))
    })

    output$data_summary_text <- renderUI({
      df <- active_data()
      tagList(
        p(strong("Rows: "), nrow(df), strong(" Columns: "), ncol(df)),
        p(strong("Numeric columns: "), paste(numeric_cols(df), collapse = ", ")),
        p(strong("Categorical columns: "), paste(categorical_cols(df), collapse = ", "))
      )
    })

    list(data = active_data, dataset_id = dataset_id, dataset_name = dataset_name)
  })
}
