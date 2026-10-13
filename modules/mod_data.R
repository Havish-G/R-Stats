# =====================================================================
# modules/mod_data.R
# Shiny module: choose a dataset (built-in example, CSV upload, or Excel
# upload). Registers the dataset in the `datasets` table the first time
# it's loaded and exposes the active data frame + its dataset_id to
# every other module.
# =====================================================================

library(readxl)

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
                     choices = c("Built-in example" = "builtin", "Upload my own file" = "upload"),
                     selected = "builtin"),
        conditionalPanel(
          sprintf("input['%s'] == 'builtin'", ns("data_source")),
          selectInput(ns("builtin_choice"), "Example dataset", choices = names(builtin_datasets))
        ),
        conditionalPanel(
          sprintf("input['%s'] == 'upload'", ns("data_source")),
          fileInput(ns("upload_file"), "Upload CSV or Excel (.csv, .xlsx, .xls)",
                    accept = c(".csv", ".xlsx", ".xls")),
          uiOutput(ns("upload_options"))
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

    file_ext <- reactive({
      req(input$upload_file)
      tolower(tools::file_ext(input$upload_file$name))
    })

    # Show CSV-specific options (header/delimiter) or an Excel sheet
    # selector, depending on what kind of file was actually uploaded.
    output$upload_options <- renderUI({
      req(input$upload_file)
      if (file_ext() %in% c("xlsx", "xls")) {
        sheets <- tryCatch(readxl::excel_sheets(input$upload_file$datapath),
                            error = function(e) character(0))
        shiny::validate(need(length(sheets) > 0, "Could not read sheet names from this Excel file - it may be corrupted or password-protected."))
        selectInput(session$ns("upload_sheet"), "Sheet", choices = sheets)
      } else {
        tagList(
          checkboxInput(session$ns("upload_header"), "First row is a header", TRUE),
          selectInput(session$ns("upload_sep"), "Delimiter", choices = c("Comma" = ",", "Semicolon" = ";", "Tab" = "\t"))
        )
      }
    })

    active_data <- reactive({
      if (input$data_source == "builtin") {
        req(input$builtin_choice)
        builtin_datasets[[input$builtin_choice]]
      } else {
        req(input$upload_file)
        ext <- file_ext()

        df <- tryCatch({
          if (ext %in% c("xlsx", "xls")) {
            req(input$upload_sheet)
            as.data.frame(readxl::read_excel(input$upload_file$datapath, sheet = input$upload_sheet))
          } else {
            # Only req() on upload_sep (a string, never legitimately
            # falsy once rendered). Do NOT req() on upload_header - it's
            # a checkbox, and req() treats FALSE as "not ready yet" and
            # silently blocks, which would wrongly stop a user from ever
            # reading a file with header = FALSE.
            req(input$upload_sep)
            read_uploaded_csv(input$upload_file$datapath, isTRUE(input$upload_header), input$upload_sep)
          }
        }, error = function(e) NULL)

        # NROW() (not nrow()) on purpose: nrow() returns NULL for anything
        # that isn't strictly a data.frame/matrix, and in R >= 4.3, `&&`
        # errors hard on a zero-length operand instead of just warning -
        # NROW() always returns a safe length-1 integer (0 for NULL/non-
        # tabular input), so this validate() can't itself crash the
        # session regardless of what tryCatch above actually produced.
        ok <- is.data.frame(df) && NROW(df) > 0
        shiny::validate(need(ok,
          "Could not parse the uploaded file. For Excel files, confirm the right sheet is selected; for CSV, check the header/delimiter settings match the file."))
        df
      }
    })

    dataset_name <- reactive({
      if (input$data_source == "builtin") input$builtin_choice else input$upload_file$name
    })

    # dataset_id is deliberately wrapped in tryCatch: register_dataset()
    # can legitimately fail (empty file, unreadable sheet, etc.), and a
    # raw stop() propagating out of a reactive consumed by observeEvent()
    # kills the whole Shiny session (the "greying out" disconnect) rather
    # than showing a normal error message. Catching it here turns any
    # failure into a visible, recoverable notification instead of a crash.
    dataset_id <- reactive({
      con <- con_getter()
      tryCatch(
        register_dataset(con, input$data_source, dataset_name(), active_data()),
        error = function(e) {
          showNotification(
            paste("Could not register dataset:", conditionMessage(e)),
            type = "error", duration = 10
          )
          NA_integer_
        }
      )
    })

    observeEvent(dataset_id(), {
      req(!is.na(dataset_id()))
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
