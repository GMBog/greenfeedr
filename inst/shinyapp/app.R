
# Load libraries
library(dplyr)
library(ggplot2)
library(greenfeedr)
library(readr)
library(readxl)
library(shiny)

# Increase max upload size to 100 MB
options(shiny.maxRequestSize = 100 * 1024^2)

ui <- fluidPage(
  titlePanel("greenfeedr app"),
  tabsetPanel(
    tabPanel("Download Data",
             sidebarLayout(
               sidebarPanel(
                 textInput("user", "Username:"),
                 passwordInput("pass", "Password:"),
                 selectInput("d", "Data Values:", choices = c("visits", "feed", "rfid", "cmds")),
                 selectInput("type", "Data Type:", choices = c("finalized" = 1, "preliminary" = 2), selected = 2),
                 textInput("exp", "Study Name (used as filename):", placeholder = "MyStudyName"),
                 textInput("unit", "GreenFeed Unit(s):", placeholder = "e.g. 304,305"),
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date()),
                 textInput("save_dir", "Save Directory:", placeholder = "e.g. /Users/Downloads/"),
                 actionButton("download", "Download Data")
               ),
               mainPanel(
                 verbatimTextOutput("status"),
                 tableOutput("preview")
               )
             )
    ),

    tabPanel("Generate Report",
             sidebarLayout(
               sidebarPanel(
                 selectInput("input_type", "Data Type:", choices = c("preliminary", "finalized")),
                 textInput("exp", "Study Name:", placeholder = "MyStudyName"),
                 textInput("unit", "GreenFeed Unit(s):", placeholder = "e.g. 304, 305"),
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date()),
                 selectInput("plot_opt", "Gases to Plot:", choices = c("All", "CH4", "CO2", "O2", "H2"), selected = "CH4"),
                 fileInput("rfid_file", "Upload RFID file (optional):"),
                 conditionalPanel(
                   condition = "input.input_type == 'preliminary'",
                   textInput("user", "Username:"),
                   passwordInput("pass", "Password:")
                 ),
                 conditionalPanel(
                   condition = "input.input_type == 'finalized'",
                   fileInput("file_path", "Upload Final Report File", multiple = TRUE)
                 ),
                 textInput("save_dir", "Save Directory:", placeholder = "e.g. /Users/Downloads/"),
                 actionButton("run_report", "Generate Report")
               ),
               mainPanel(
                 verbatimTextOutput("report_status")
               )
             )
    ),

    tabPanel("Process Data",
             sidebarLayout(
               sidebarPanel(
                 fileInput("gf_file", "Upload GreenFeed Data:"),
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date()),
                 numericInput("param1", "N records/day (param1):", value = 2, min = 1),
                 numericInput("param2", "N days/week (param2):", value = 3, min = 1),
                 numericInput("min_time", "Min. minutes per record:", value = 2),
                 checkboxInput("transform", "Transform gases to L/d?", value = FALSE),
                 numericInput("cutoff", "Outlier SD cutoff:", value = 3, min = 1),
                 actionButton("run_process", "Process Data")
               ),
               mainPanel(
                 verbatimTextOutput("proc_summary"),
                 br(),
                 h4("Download Processed Files:"),
                 fluidRow(
                   column(4, downloadButton("download_filtered", "Filtered Data")),
                   column(4, downloadButton("download_daily", "Daily Data")),
                   column(4, downloadButton("download_weekly", "Weekly Data"))
                 )
               )
             )
    ),

    tabPanel("Compare Data",
             sidebarLayout(
               sidebarPanel(
                 fileInput("prelim_file", "Upload Preliminary Data:", accept = ".csv"),
                 fileInput("final_file", "Upload Finalized Data:", accept = c(".xls", ".xlsx")),
                 dateRangeInput("compare_dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date()),
                 actionButton("run_compare", "Compare Data")
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

    unit <- convert_unit(input$unit,1)

    output$status <- renderText("Downloading data...")

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

      output$status <- renderText("✅ Data downloaded successfully.")

      }, error = function(e) {
      output$status <- renderText(paste("❌ Error:", e$message))
      output$preview <- renderTable(NULL)
    })
  })

  # TAB 2: Generate GreenFeed Report
  observeEvent(input$run_report, {
    req(input$exp, input$unit)

    unit <- convert_unit(input$unit,1)
    rfid <- if (!is.null(input$rfid_file)) input$rfid_file$datapath else NULL
    files <- if (!is.null(input$file_path)) input$file_path$datapath else NULL

    output$report_status <- renderText("Generating report...")

    tryCatch({
      greenfeedr::report_gfdata(
        input_type = input$input_type,
        exp = input$exp,
        unit = unit,
        start_date = input$dates[1],
        end_date = input$dates[2],
        save_dir = input$save_dir,
        plot_opt = input$plot_opt,
        rfid_file = rfid,
        user = if (input$input_type == "preliminary") input$user else NA,
        pass = if (input$input_type == "preliminary") input$pass else NA,
        file_path = files
      )

      output$report_status <- renderText("✅ Report generated successfully.")

    }, error = function(e) {
      output$report_status <- renderText(paste("❌ Error:", e$message))
    })
  })

  # TAB 3: Process Data
  processed_result <- reactiveVal(NULL)

  observeEvent(input$run_process, {
    req(input$gf_file, input$proc_dates, input$param1, input$param2)

    df <- tryCatch(
      readr::read_csv(input$gf_file$datapath),
      error = function(e) {
        output$proc_summary <- renderText(paste("❌ Failed to read file:", e$message))
        return(NULL)
      }
    )

    if (is.null(df)) return()

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
}

shinyApp(ui, server)
