
# Load libraries
library(dplyr)
library(DT)
library(ggplot2)
library(greenfeedr)
library(readr)
library(readxl)
library(shiny)

# Increase max upload size to 100 MB
options(shiny.maxRequestSize = 100 * 1024^2)

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      /* Make tab titles green */
      .nav-tabs > li > a {
        color: #006400 !important;  /* dark green */
        font-weight: bold;
      }

      /* Make active tab title green */
      .nav-tabs > li.active > a,
      .nav-tabs > li.active > a:focus,
      .nav-tabs > li.active > a:hover {
        color: #006400 !important;
        font-weight: bold;
      }

      /* Make all normal body text green */
      body, .main-panel, .form-group label, .control-label {
        color: #006400;
      }
      /* Logo at top right corner */
      .logo-top-right {
        position: absolute;
        top: 10px;
        right: 10px;
        z-index: 9999;
      }
  "))
  ),
  div(class = "logo-top-right",
      tags$img(src = "GFSticker.png", width = "75px")  # adjust width as needed
  ),

  titlePanel("greenfeedr app"),
  tabsetPanel(
    tabPanel("Downloading",
             sidebarLayout(
               sidebarPanel(
                 textInput("user", "Username:"),
                 passwordInput("pass", "Password:"),
                 selectInput("d", "Data Values:", choices = c("visits", "feed", "rfid", "cmds")),
                 selectInput("type", "Data Type:", choices = c("preliminary" = 2, "finalized" = 1), selected = 2),
                 textInput("exp", "Study Name:", placeholder = "MyStudyName"),
                 textInput("unit", "GreenFeed Unit(s):", placeholder = "e.g. 55 or 100,101"),
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date() - 1),
                 textInput("save_dir", "Save Directory:", placeholder = "e.g. /Users/Downloads/"),
                 actionButton("download", "Run")
               ),
               mainPanel(
                 verbatimTextOutput("status"),
                 tableOutput("preview")
               )
             )
    ),

    tabPanel("Reporting",
             sidebarLayout(
               sidebarPanel(
                 textInput("user", "Username:"),
                 passwordInput("pass", "Password:"),
                 textInput("exp", "Study Name:", placeholder = "MyStudyName"),
                 selectInput("input_type", "Data Type:", choices = c("preliminary", "finalized")),
                 textInput("unit", "GreenFeed Unit(s):", placeholder = "e.g. 55 or 100,101"),
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date() - 1),
                 selectInput("plot_opt", "Gases to Plot:", choices = c("All", "CH4", "CO2", "O2", "H2"), selected = "All"),
                 fileInput("rfid_file", "Upload RFID file (optional):"),
                 textInput("save_dir", "Save Directory:", placeholder = "e.g. /Users/Downloads/"),
                 actionButton("run_report", "Run")
               ),
               mainPanel(
                 verbatimTextOutput("report_status"),
                 br(),
                 h4("Plots from GreenFeed Report"),
                 plotOutput("plot_records"),
                 plotOutput("plot_dailyCH4"),
                 plotOutput("plot_dailyCO2"),
                 plotOutput("plot_dailyO2"),
                 plotOutput("plot_dailyH2")
               )
             )
    ),

    tabPanel("Checking",
             sidebarLayout(
               sidebarPanel(
                 textInput("user", "Username:"),
                 passwordInput("pass", "Password:"),
                 textInput("unit", "GreenFeed Unit(s):", placeholder = "e.g. 55 or 100,101"),
                 textInput("gcup", "Grams per Cup:", placeholder = "e.g. 34 or 34,35"),
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date() - 1),
                 fileInput("rfid_file", "Upload RFID file (optional):"),
                 fileInput("feedtimes_file", "Upload Feedtimes file (optional):"),
                 textInput("save_dir", "Save Directory:", placeholder = "e.g. /Users/Downloads/"),
                 actionButton("run_pellin", "Run Pellin"),
                 actionButton("run_viseat", "Run Viseat")
               ),
               mainPanel(
                 verbatimTextOutput("pellin_status"),
                 uiOutput("pellin_table"),
                 br(), hr(), br(),
                 textOutput("viseat_status"),
                 plotOutput("unit_plot"),
                 fluidRow(
                   column(6, downloadButton("download_day", "Download Visits per Day")),
                   column(6, downloadButton("download_animal", "Download Visits per Animal"))
                 )
               )
             )
    ),

    tabPanel("Processing",
             sidebarLayout(
               sidebarPanel(
                 fileInput("gf_file", "Upload GreenFeed Data:"),
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date() - 1),
                 actionButton("run_eval_param", "🔍 Evaluate Parameters"),
                 br(), hr(),
                 numericInput("param1", "N records/day (param1):", value = 2, min = 1),
                 numericInput("param2", "N days/week (param2):", value = 3, min = 1),
                 numericInput("min_time", "Min. minutes per record:", value = 2),
                 checkboxInput("transform", "Transform gases to L/d?", value = FALSE),
                 numericInput("cutoff", "Outlier SD cutoff:", value = 3, min = 1),
                 actionButton("run_process", "Run")
               ),
               mainPanel(
                 br(), hr(),
                 h4("Evaluation of Parameter Combinations:"),
                 DTOutput("eval_param_table"),
                 br(), hr(),
                 verbatimTextOutput("proc_summary"),
                 h4("Download Processed Files:"),
                 fluidRow(
                   column(4, downloadButton("download_filtered", "Filtered Data")),
                   column(4, downloadButton("download_daily", "Daily Data")),
                   column(4, downloadButton("download_weekly", "Weekly Data"))
                 )
               )
             )
    ),

    tabPanel("Comparing",
             sidebarLayout(
               sidebarPanel(
                 fileInput("prelim_file", "Upload Preliminary Data:", accept = ".csv"),
                 fileInput("final_file", "Upload Finalized Data:", accept = c(".xls", ".xlsx")),
                 dateRangeInput("compare_dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date()),
                 actionButton("run_compare", "Run")
               ),
               mainPanel(
                 verbatimTextOutput("compare_summary"),
                 fluidRow(
                   column(6, plotOutput("ch4_plot")),
                   column(6, plotOutput("co2_plot"))
                 )
               )
             )
    )

  )
)

server <- function(input, output, session) {

  # TAB 1: Download GreenFeed Data
  observeEvent(input$download, {
  req(input$user, input$pass, input$unit, input$exp)

  unit <- convert_unit(input$unit, 1)
  output$status <- renderText("📥 Downloading data...")

  tryCatch({
    file <- greenfeedr::get_gfdata(
      user = input$user,
      pass = input$pass,
      d = input$d,
      type = as.numeric(input$type),
      exp = input$exp,
      unit = unit,
      start_date = input$dates[1],
      end_date = input$dates[2],
      save_dir = input$save_dir
    )

    # Check if the file exists or is valid
    if (is.null(file) || !file.exists(file)) {
      output$status <- renderText("⚠️ No valid data retrieved.")
      output$preview <- renderTable(NULL)
    } else {
      output$status <- renderText("✅ Data downloaded successfully.")
      # Optional: Show preview if needed
      # output$preview <- renderTable(read.csv(file))
    }

  }, error = function(e) {
    output$status <- renderText(paste("❌ Error:", e$message))
    output$preview <- renderTable(NULL)
   })
  })


  # TAB 2: Generate GreenFeed Report
  report_data <- reactiveVal()

  observeEvent(input$run_report, {
    req(input$exp, input$unit)

    unit <- convert_unit(input$unit, 1)
    rfid <- if (!is.null(input$rfid_file)) input$rfid_file$datapath else NULL
    files <- if (!is.null(input$file_path)) input$file_path$datapath else NULL

    output$report_status <- renderText("Generating report...")

    tryCatch({
      # Call the report function and capture the returned dataframe
      df <- greenfeedr::report_gfdata(
        input_type = input$input_type,
        exp = input$exp,
        unit = unit,
        start_date = input$dates[1],
        end_date = input$dates[2],
        save_dir = NULL,           # pass NULL or tempdir() if your function requires a directory but you don't want to save
        plot_opt = input$plot_opt,
        rfid_file = rfid,
        user = if (input$input_type == "preliminary") input$user else NA,
        pass = if (input$input_type == "preliminary") input$pass else NA,
        file_path = files
      )

      # Assign returned dataframe to reactiveVal for plotting
      report_data(df)

      output$report_status <- renderText("✅ Report generated successfully.")

    }, error = function(e) {
      output$report_status <- renderText(paste("❌ Error:", e$message))
      report_data(NULL)
    })
  })

  # Reactive plots for GreenFeed report
  output$plot_records <- renderPlot({
    req(report_data())
    greenfeedr::plot_records_per_day(report_data())
  })

  output$plot_dailyCH4 <- renderPlot({
    req(report_data())
    if (input$plot_opt %in% c("All", "CH4")) {
      greenfeedr::plot_gas_daily(report_data(), gas = "CH4")
    }
  })

  output$plot_dailyCO2 <- renderPlot({
    req(report_data())
    if (input$plot_opt %in% c("All", "CO2")) {
      greenfeedr::plot_gas_daily(report_data(), gas = "CO2")
    }
  })

  output$plot_dailyO2 <- renderPlot({
    req(report_data())
    if (input$plot_opt %in% c("All", "O2")) {
      greenfeedr::plot_gas_daily(report_data(), gas = "O2")
    }
  })

  output$plot_dailyH2 <- renderPlot({
    req(report_data())
    if (input$plot_opt %in% c("All", "H2")) {
      greenfeedr::plot_gas_daily(report_data(), gas = "H2")
    }
  })


  # TAB 3: Process Data
  processed_result <- reactiveVal(NULL)

  observeEvent(input$run_process, {
    req(input$gf_file, input$dates, input$param1, input$param2)

    df <- tryCatch({
      ext <- tools::file_ext(input$gf_file$name)
      cat("File extension detected:", ext, "\n")
      if (tolower(ext) %in% c("xls", "xlsx")) {
        readxl::read_excel(input$gf_file$datapath)
      } else if (tolower(ext) == "csv") {
        readr::read_csv(input$gf_file$datapath, show_col_types = FALSE)
      } else {
        stop("Unsupported file type. Please upload a .csv, .xls, or .xlsx file.")
      }
    }, error = function(e) {
      output$proc_summary <- renderText(paste("❌ Error reading file:", e$message))
      return(NULL)
    })

    if (is.null(df)) return()

    output$proc_summary <- renderText({
      paste("✅ File read successfully. Rows:", nrow(df), "Columns:", ncol(df))
    })

    result <- tryCatch({
      greenfeedr::process_gfdata(
        data = df,
        start_date = input$dates[1],
        end_date = input$dates[2],
        param1 = input$param1,
        param2 = input$param2,
        min_time = input$min_time,
        transform = input$transform,
        cutoff = input$cutoff
      )
    }, error = function(e) {
      output$proc_summary <- renderText(paste("❌ Processing error:", e$message))
      return(NULL)
    })

    if (is.null(result)) return()

    # Save to reactive value
    processed_result(result)

    weekly <- result$weekly_data

    gas_names <- names(weekly)[grepl("CH4|CO2|O2|H2", names(weekly))]
    gas_summary <- lapply(gas_names, function(gas) {
      vals <- weekly[[gas]]
      mean_val <- round(mean(vals, na.rm = TRUE), 2)
      sd_val <- round(sd(vals, na.rm = TRUE), 2)
      cv_val <- round(sd_val / mean_val * 100, 1)
      paste0(gas, " = ", mean_val, " ± ", sd_val, " [CV% = ", cv_val, "]")
    }) |> unlist()

    output$proc_summary <- renderText({
      paste("✅ Processing complete.\n\nSummary of gases (weekly):\n", paste(gas_summary, collapse = "\n"))
    })

    output$download_filtered <- downloadHandler(
      filename = function() { "filtered_data.csv" },
      content = function(file) {
        write.csv(processed_result()$filtered_data, file, row.names = FALSE)
      }
    )

    output$download_daily <- downloadHandler(
      filename = function() { "daily_data.csv" },
      content = function(file) {
        write.csv(processed_result()$daily_data, file, row.names = FALSE)
      }
    )

    output$download_weekly <- downloadHandler(
      filename = function() { "weekly_data.csv" },
      content = function(file) {
        write.csv(processed_result()$weekly_data, file, row.names = FALSE)
      }
    )

  })

  # Reactive value to store eval results
  eval_param_result <- reactiveVal(NULL)

  observeEvent(input$run_eval_param, {
    req(input$gf_file, input$dates)

    df <- tryCatch({
      ext <- tools::file_ext(input$gf_file$name)
      if (tolower(ext) %in% c("xls", "xlsx")) {
        readxl::read_excel(input$gf_file$datapath)
      } else if (tolower(ext) == "csv") {
        readr::read_csv(input$gf_file$datapath, show_col_types = FALSE)
      } else {
        stop("Unsupported file type. Please upload a .csv, .xls, or .xlsx file.")
      }
    }, error = function(e) {
      output$proc_summary <- renderText(paste("❌ Error reading file:", e$message))
      return(NULL)
    })


    if (is.null(df)) return()

    result <- tryCatch({
      greenfeedr::eval_gfparam(
        data = df,
        start_date = format(input$dates[1], "%d/%m/%Y"),
        end_date = format(input$dates[2], "%d/%m/%Y")
      )
    }, error = function(e) {
      output$proc_summary <- renderText(paste("❌ Evaluation error:", e$message))
      return(NULL)
    })

    eval_param_result(result)

    output$eval_param_table <- renderTable({
      req(eval_param_result())
      eval_param_result()
    })

    output$eval_param_table <- renderDT({
      req(eval_param_result())
      datatable(
        eval_param_result(),
        options = list(
          pageLength = 5,
          autoWidth = FALSE,
          scrollX = TRUE
        ),
        filter = "top",
        rownames = FALSE
      )
    })

  })


  # TAB 4: Compare Data
  observeEvent(input$run_compare, {
    req(input$prelim_file, input$final_file, input$compare_dates)

    prelim_path <- input$prelim_file$datapath
    final_path <- input$final_file$datapath

    result <- tryCatch({
      compare_gfdata(
        prelimrep = prelim_path,
        finalrep = final_path,
        start_date = input$compare_dates[1],
        end_date = input$compare_dates[2]
      )
    }, error = function(e) {
      output$compare_summary <- renderText(paste("❌ Comparison error:", e$message))
      return(NULL)
    })

    if (is.null(result)) return()

    output$compare_summary <- renderText({
      paste0("✅ Comparison done.\n\n",
             nrow(result$out_final), " records were removed from the finalized data.\n",
             nrow(result$out_prelim), " records were added to the finalized data.")
    })

    # Use the returned combined data for plots directly
    output$ch4_plot <- renderPlot({
      ggplot(result$data, aes(x = group, y = CH4GramsPerDay, fill = group)) +
        geom_boxplot() +
        stat_summary(fun = mean, geom = "text",
                     aes(label = round(after_stat(y), 0)),
                     vjust = -0.6, size = 4, color = "black") +
        scale_fill_manual(values = c("D" = "#9FA8DA", "F" = "#A5D6A7")) +
        scale_x_discrete(labels = c("D" = "Prelim data", "F" = "Final report")) +
        theme_classic() +
        labs(y = "CH4 (g/d)", x = NULL) +
        theme(legend.position = "none")
    })

    output$co2_plot <- renderPlot({
      ggplot(result$data, aes(x = group, y = CO2GramsPerDay, fill = group)) +
        geom_boxplot() +
        stat_summary(fun = mean, geom = "text",
                     aes(label = round(after_stat(y), 0)),
                     vjust = -0.9, size = 4, color = "black") +
        scale_fill_manual(values = c("D" = "#9FA8DA", "F" = "#A5D6A7")) +
        scale_x_discrete(labels = c("D" = "Prelim data", "F" = "Final report")) +
        theme_classic() +
        labs(y = "CO2 (g/d)", x = NULL) +
        theme(legend.position = "none")
    })
  })



  # TAB 5: Checking visits
  unit_converted <- reactive({
    req(input$unit)
    list(
      pellin = convert_unit(input$unit, 2),
      viseat = convert_unit(input$unit, 1)
    )
  })

  rfid_path <- reactive({
    if (!is.null(input$rfid_file)) input$rfid_file$datapath else NULL
  })

  feedtimes_path <- reactive({
    if (!is.null(input$feedtimes_file)) input$feedtimes_file$datapath else NULL
  })

  save_dir_path <- reactive({
    if (input$save_dir == "") tempdir() else input$save_dir
  })

  # ───── Run pellin() for pellet intake calculation ─────
  observeEvent(input$run_pellin, {
    req(input$gcup)

    gcup <- as.numeric(strsplit(input$gcup, ",")[[1]])
    if (any(is.na(gcup))) {
      output$pellin_status <- renderText("❌ Error: Invalid 'gcup' input. Must be numeric (e.g., 34 or 34,35).")
      output$pellin_table <- renderUI(NULL)
      return()
    }

    output$pellin_status <- renderText("Running pellin()...")

    tryCatch({
      df <- greenfeedr::pellin(
        user = input$user,
        pass = input$pass,
        unit = unit_converted()$pellin,
        gcup = gcup,
        start_date = input$dates[1],
        end_date = input$dates[2],
        rfid_file = rfid_path(),
        file_path = feedtimes_path(),
        save_dir = save_dir_path()
      )

      summary_df <- df %>%
        dplyr::filter(!is.na(FoodType)) %>%
        dplyr::group_by(FoodType) %>%
        dplyr::summarise(
          Animals = dplyr::n_distinct(RFID),
          Days = dplyr::n_distinct(Date),
          Total_Intake_kg = round(sum(PIntake_kg, na.rm = TRUE), 2),
          Mean_Intake_kg = round(mean(PIntake_kg, na.rm = TRUE), 2),
          .groups = "drop"
        )

      output$pellin_status <- renderText(
        paste0("✅ Pellet intakes processed successfully. File saved in: ", save_dir_path())
      )

      output$pellin_table <- renderUI({
        table_html <- knitr::kable(summary_df, format = "html") %>%
          kableExtra::kable_styling("striped", full_width = FALSE)
        HTML(table_html)
      })

    }, error = function(e) {
      output$pellin_status <- renderText(paste("❌ Error:", e$message))
      output$pellin_table <- renderUI(NULL)
    })
  })

  # ───── Run viseat() for checking visits ─────
  observeEvent(input$run_viseat, {
    req(input$dates)

    output$viseat_status <- renderText("Running viseat()...")

    tryCatch({
      results <- greenfeedr::viseat(
        user = input$user,
        pass = input$pass,
        unit = unit_converted()$viseat,
        start_date = input$dates[1],
        end_date = input$dates[2],
        rfid_file = rfid_path(),
        file_path = feedtimes_path()
      )

      # Plot: TAG reads per unit
      plot_data <- results$feedtimes %>%
        dplyr::group_by(FID) %>%
        dplyr::summarise(n = n()) %>%
        ggplot(aes(x = as.factor(FID), y = n, fill = as.factor(FID))) +
        geom_bar(stat = "identity", position = position_dodge()) +
        geom_text(aes(label = n),
                  vjust = 1.9, color = "black", size = 3.8,
                  position = position_dodge(0.9)) +
        labs(title = "TAG reads per unit", x = "Units", y = "Frequency", fill = "Unit") +
        theme_classic()

      output$unit_plot <- renderPlot({ plot_data })

      # Downloads
      output$download_day <- downloadHandler(
        filename = function() paste0("visits_per_day_", Sys.Date(), ".csv"),
        content = function(file) {
          write.csv(results$visits_per_day, file, row.names = FALSE)
        }
      )

      output$download_animal <- downloadHandler(
        filename = function() paste0("visits_per_animal_", Sys.Date(), ".csv"),
        content = function(file) {
          write.csv(results$visits_per_animal, file, row.names = FALSE)
        }
      )

      output$viseat_status <- renderText("✅ GreenFeed visits processed successfully.")

    }, error = function(e) {
      output$viseat_status <- renderText(paste("❌ Error:", e$message))
    })
  })


}

shinyApp(ui, server)
