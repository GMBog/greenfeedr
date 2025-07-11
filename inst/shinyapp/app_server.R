
# app_server.R

server <- function(input, output, session) {

  ## TAB 1: Downloading Data ####

  # Define reactive values
  rv <- reactiveValues(
    filepath = NULL,
    df_preview = NULL,
    error_message = NULL
  )

  # Run code for download data
  observeEvent(input$download, {
    req(input$user, input$pass, input$unit, input$dates, input$save_dir)

    # Check 'GreenFeed' unit format
    unit <- convert_unit(input$unit, 1)

    # Show a progress bar (start downloading)
    withProgress(message = "Downloading data...", value = 0, {
      tryCatch({
        incProgress(0.1, detail = "Connecting to GreenFeed server...")

        # Authenticate to receive token
        req_auth <- httr::POST("https://portal.c-lockinc.com/api/login", body = list(user = input$user, pass = input$pass))
        httr::stop_for_status(req_auth)
        TOK <- trimws(httr::content(req_auth, as = "text"))

        # Internal function to download and parse
        download_and_parse <- function(type) {
          if (type == "visits") {
            URL <- paste0(
              "https://portal.c-lockinc.com/api/getemissions?d=", type, "&fids=", unit,
              "&st=", input$dates[1], "&et=", input$dates[2], "%2012:00:00&type=2"
            )
          } else {
            URL <- paste0(
              "https://portal.c-lockinc.com/api/getraw?d=", type, "&fids=", unit,
              "&st=", input$dates[1], "&et=", input$dates[2], "%2012:00:00"
            )
          }
          message(URL)
          req_data <- httr::POST(URL, body = list(token = TOK))
          httr::stop_for_status(req_data)
          a <- httr::content(req_data, as = "text")
          perline <- stringr::str_split(a, "\\n")[[1]]
          df <- do.call("rbind", stringr::str_split(perline[3:length(perline)], ","))
          df <- as.data.frame(df)
          df
        }

        # Show a progress bar (continuation)
        incProgress(0.3, detail = "Downloading and parsing data...")
        df <- download_and_parse(input$d)

        # Assign column names
        if (input$d == "visits") {
          colnames(df) <- c(
            "FeederID", "AnimalName", "RFID", "StartTime", "EndTime",
            "GoodDataDuration", "CO2GramsPerDay", "CH4GramsPerDay", "O2GramsPerDay",
            "H2GramsPerDay", "H2SGramsPerDay", "AirflowLitersPerSec", "AirflowCf",
            "WindSpeedMetersPerSec", "WindDirDeg", "WindCf", "WasInterrupted",
            "InterruptingTags", "TempPipeDegreesCelsius", "IsPreliminary", "RunTime"
          )
        } else if (input$d == "feed") {
          colnames(df) <- c(
            "FID", "FeedTime", "CowTag", "CurrentCup", "MaxCups",
            "CurrentPeriod", "MaxPeriods", "CupDelay", "PeriodDelay", "FoodType"
          )
        } else if (input$d == "rfid") {
          colnames(df) <- c(
            "FID", "ScanTime", "CowTag", "InOrOut", "Tray(IfApplicable)"
          )
        } else if (input$d == "cmds") {
          colnames(df) <- c(
            "FID", "CommandTime", "Cmd"
          )
        }

        # Ensure save_dir is an absolute path
        save_dir <- normalizePath(input$save_dir, mustWork = FALSE)
        if (!dir.exists(save_dir)) {
          dir.create(save_dir, recursive = TRUE)
        }
        # Show a progress bar (start saving)
        incProgress(0.2, detail = "Saving file...")

        # Build file_path to save data
        filename <- switch(input$d,
                           "visits" = paste0("GreenFeed_Summarized_Data_", unit, "_", input$dates[1], "_", input$dates[2], ".csv"),
                           "feed"   = paste0("Feedtimes_", unit, "_", input$dates[1], "_", input$dates[2], ".csv"),
                           "rfid"   = paste0("Rfids_", unit, "_", input$dates[1], "_", input$dates[2], ".csv"),
                           "cmds"   = paste0("Commands_", unit, "_", input$dates[1], "_", input$dates[2], ".csv")
        )
        filepath <- file.path(save_dir, filename)
        rv$filepath <- filepath

        # Save the data
        readr::write_csv(df, filepath)

        # Show a progress bar (start data preview)
        incProgress(0.2, detail = "Preparing data preview...")

        # Read preview for summary and preview table
        if (file.exists(filepath) && file.info(filepath)$size > 0) {
          df_preview <- tryCatch(readr::read_csv(filepath, n_max = 100), error = function(e) NULL)
          rv$df_preview <- df_preview
        } else {
          rv$df_preview <- NULL
        }

        # Show a progress bar (end)
        incProgress(0.2, detail = "Done!")

        # Handle error messages
        rv$error_message <- NULL

      }, error = function(e) {
        msg <- as.character(e$message)
        if (grepl("names.*must be the same length as the vector", msg)) {
          rv$error_message <- "No data for the requested:<br>- User<br>- Unit<br>- Period<br>Please check your inputs."
        } else if (grepl("Cannot open file for writing", msg)) {
          rv$error_message <- "Error: Cannot write file.<br>Please check and re-enter a valid save directory."
        } else {
          rv$error_message <- paste("Unexpected error:", msg)
        }
        rv$filepath <- NULL
        rv$df_preview <- NULL
      })
    })
  })

  # Status card
  output$status_card <- renderUI({
    req(input$download)

    # Warning message if errors in the inputs
    if (is.null(rv$filepath) || is.null(rv$df_preview)) {
      div(
        class = "warning-card",
        style = "display: flex; align-items: center; gap: 10px;",
        icon("exclamation-triangle", style = "color:#e65100; font-size:30px;"),
        h4("Data file was not saved or is empty!", style = "margin: 0;")
      )
    } else {

      # Summary of data results
      df <- rv$df_preview
      date_col <- grep("StartTime|Date", names(df), value = TRUE)[1]
      animal_col <- grep("Animal(Name)?|RFID", names(df), value = TRUE)[1]
      tagList(
        div(
          class = "summary-card",
          # Flex row for icon and h4 header
          div(
            style = "display: flex; align-items: center; gap: 10px;",
            icon("check-circle", style = "color:#388e3c; font-size:30px;"),
            h4("Data file saved successfully!", style = "margin: 0;")
          ),
          tags$div(style = "height: 15px;"),
          tags$p(tags$b("Rows:"), nrow(df)),
          tags$p(tags$b("Columns:"), ncol(df)),
          if (!is.null(date_col)) tags$p(
            tags$b("Date range:"),
            as.character(min(as.Date(df[[date_col]], origin = "1970-01-01"), na.rm=TRUE)), "to",
            as.character(max(as.Date(df[[date_col]], origin = "1970-01-01"), na.rm=TRUE))
          ),
          if (!is.null(animal_col)) tags$p(tags$b("Unique IDs:"), length(unique(df[[animal_col]]))),
          tags$p("You can find your file in the directory you specified above.")
        )
      )
    }
  })

  # Error message card
  output$error_message <- renderUI({
    req(rv$error_message)
    div(
      style = "background-color: #fff6f6; border: 2px solid #e74c3c; color: #c0392b; padding: 15px; margin-bottom: 15px; border-radius: 6px;",
      HTML(rv$error_message)
    )
  })

  # Data preview (hidden in a link)
  output$preview <- renderUI({
    req(rv$df_preview)
    # Show a link to press and access data
    tags$details(
      tags$summary(style = "font-weight:bold; text-decoration:underline; cursor:pointer;",
                   "Show/hide data preview"),
      DT::dataTableOutput("preview_table")
    )
  })
  # Table data preview
  output$preview_table <- DT::renderDataTable({
    req(rv$df_preview)
    DT::datatable(head(rv$df_preview, 10), options = list(scrollX = TRUE, pageLength = 10))
  })



  ## TAB 2: Checking Data ####

  # Define reactive values
  rv <- reactiveValues(
    results = NULL,
    error_message = NULL
  )

  # Reactive expression to get the path
  rfid_path <- reactive({
    if (!is.null(input$rfid_file)) input$rfid_file$datapath else NULL
  })

  # Run code to check visitation ('viseat' function)
  observeEvent(input$run_viseat, {
    req(input$dates, input$unit)

    # Check inputs
    unit <- convert_unit(input$unit, 1)

    withProgress(message = 'Running Viseat...', value = 0, {
      tryCatch({
        rv$results <- greenfeedr::viseat(
          user = input$user,
          pass = input$pass,
          unit = unit,
          start_date = input$dates[1],
          end_date = input$dates[2],
          rfid_file = rfid_path()
        )

      # Summary card
      output$report_summary1 <- renderUI({
        req(input$run_viseat > 0)
        df <- rv$results$feedtimes
        unit_col <- "FID"

        # Check if data exist
        if (is.null(df) || !is.data.frame(df) || nrow(df) == 0 || !unit_col %in% names(df)) return(NULL)

        # Get visits per unit
        visits_by_unit <- table(df[[unit_col]])

        # Get number of animals using units
        animal_col <- "CowTag"
        visits_by_animal <- if (animal_col %in% names(df)) table(df[[animal_col]]) else NULL
        n_animals <- if (!is.null(visits_by_animal)) length(visits_by_animal) else "Unknown"

        # Calculate mean visits per animal per day
        visits_per_day_df <- rv$results$visits_per_day
        if (!is.null(visits_per_day_df) && is.data.frame(visits_per_day_df) && nrow(visits_per_day_df) > 0) {
          animal_col <- if ("RFID" %in% names(visits_per_day_df)) "RFID" else if ("FarmName" %in% names(visits_per_day_df)) "FarmName" else NULL
          if (!is.null(animal_col) && "visits" %in% names(visits_per_day_df)) {
            mean_visits_animal_per_day <- median(as.numeric(visits_per_day_df$visits), na.rm = T)
          } else {
            mean_visits_animal_per_day <- "Unknown"
          }
        } else {
          mean_visits_animal_per_day <- "Unknown"
        }

        # Get number of days with visits
        date_col <- "FeedTime"
        visits_by_day <- if (date_col %in% names(df)) table(as.Date(df[[date_col]])) else NULL
        n_days <- if (!is.null(visits_by_day)) length(visits_by_day) else "Unknown"

        # Create summary card
        div(
          class = "summary-card",
          icon("chart-bar", style = "color:#388e3c; font-size:22px; margin-right:6px;"),
          strong("GreenFeed Report Summary"),
          tags$ul(
            tags$li(strong("Animals: "), n_animals),
            tags$li(strong("Days: "), n_days),
            tags$li(
              strong("Total Visits: "),
              tags$ul(
                lapply(seq_along(visits_by_unit), function(i) {
                  tags$li(
                    tags$b("Unit ",names(visits_by_unit)[i]), ": ", visits_by_unit[i]
                  )
                })
              )
            ),
            tags$li(strong("Median Visits per Animal-Day: "), mean_visits_animal_per_day)
          )
        )
      })

      # Plot 1: Visits per Animal
      output$boxplot_animal <- renderPlotly({
        df <- rv$results$visits_per_day
        # Dynamically choose the animal ID column
        animal_col <- if ("RFID" %in% names(df)) "RFID" else if ("FarmName" %in% names(df)) "FarmName" else NULL
        if (is.null(animal_col)) return(NULL)

        p_animal <- ggplot(df, aes(x = factor(.data[[animal_col]]), y = visits)) +
          geom_boxplot(fill = "#43a047", alpha = 0.87) +
          labs(
            title = "Visits Per Animal",
            x = "",
            y = "Visits"
          ) +
          theme_minimal(base_size = 12) +
          theme(
            plot.title = element_text(size = 13, face = "bold", hjust = 0.5, color = "#388e3c"),
            axis.text.x = element_text(angle = 45, hjust = 1, size = 6),
            axis.title.y = element_text(size = 10, face = "bold"),
            axis.title.x = element_text(size = 10, face = "bold"),
            panel.grid.major.x = element_blank(),
            plot.background = element_rect(fill = "transparent", color = NA),
            panel.background = element_rect(fill = "transparent", color = NA),
            legend.background = element_rect(fill = "transparent", color = NA),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank()
          )

        # Plot interactively
        ggplotly(p_animal)
      })

      # Handle error messages
      rv$error_message <- NULL

    }, error = function(e) {
      msg <- as.character(e$message)
      if (grepl("names.*must be the same length as the vector", msg)) {
        rv$error_message <- "No data for the requested:<br>- User<br>- Unit<br>- Period<br>Please check your inputs."
      } else if (grepl("Cannot open file for writing", msg)) {
        rv$error_message <- "Error: Cannot write file.<br>Please check and re-enter a valid save directory."
      } else if (grepl("Unexpected error: Mismatch *unit-foodtype combinations", msg)) {
        rv$error_message <- "Error: Mismatch between number of units and gcup."
      } else {
        rv$error_message <- paste("Unexpected error:", msg)
      }
    })
   })
  })

  # Run code to calculate intakes ('pellin' function)
  observeEvent(input$run_pellin, {
    req(input$gcup, input$unit)

    # Check inputs
    gcup <- as.numeric(strsplit(input$gcup, ",")[[1]])
    unit <- convert_unit(input$unit, 2)

    withProgress(message = 'Running Pellin...', value = 0, {
      tryCatch({
        df <- greenfeedr::pellin(
          user = input$user,
          pass = input$pass,
          unit = unit,
          gcup = gcup,
          start_date = input$dates[1],
          end_date = input$dates[2],
          rfid_file = rfid_path(),
          save_dir = NULL #this argument avoid function to save files directly
        )

      # Summary Card
      output$pellin_summary <- renderUI({
        if (is.null(df) || !is.data.frame(df) || nrow(df) == 0) return(NULL)

        # Calculate summary statistics
        n_animals <- dplyr::n_distinct(df$RFID[!is.na(df$FoodType)])
        n_days <- dplyr::n_distinct(df$Date)
        total_intake <- round(sum(df$PIntake_kg, na.rm = TRUE), 2)
        mean_intake <- round(mean(df$PIntake_kg, na.rm = TRUE), 2)

        div(
          class = "summary-card",
          icon("chart-bar", style = "color:#388e3c; font-size:22px; margin-right:6px;"),
          strong("Pellin Report Summary"),
          tags$ul(
            tags$li(strong("Animals: "), n_animals),
            tags$li(strong("Days: "), n_days),
            tags$li(strong("Mean Pellet Intake per Animal-Day (g): "), mean_intake*1000)
          )
        )
      })

      # Process 'feedtimes' data
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

      # Create summary table
      output$pellin_table <- renderUI({
        table_html <- knitr::kable(summary_df, format = "html") %>%
          kableExtra::kable_styling("striped", full_width = FALSE)
        HTML(table_html)
      })

      # Downloads
      output$download_pellin <- downloadHandler(
        filename = function()
          paste0("PelletIntakes_", unit, "_", input$dates[1], "_", input$dates[2], ".csv"),
        content = function(file) {
          write.csv(df, file, row.names = FALSE)
        }
      )

      # Handle error messages
      rv$error_message <- NULL

    }, error = function(e) {
      msg <- as.character(e$message)
      if (grepl("names.*must be the same length as the vector", msg)) {
        rv$error_message <- "Error: No data for the requested:<br>- User<br>- Unit<br>- Period<br>Please check your inputs."
      } else if (grepl("Cannot open file for writing", msg)) {
        rv$error_message <- "Error: Cannot write file.<br>Please check and re-enter a valid save directory."
      } else if (grepl("Unexpected error: Mismatch *unit-foodtype combinations", msg)){
        rv$error_message <- "Error: Mismatch between number of units and gcup."
      } else {
        rv$error_message <- paste("Unexpected error:", msg)
      }
    })
   })
  })

  # Show error messages
  output$error_message <- renderUI({
    req(rv$error_message)
    div(
      style = "background-color: #fff6f6; border: 2px solid #e74c3c; color: #c0392b; padding: 15px; margin-bottom: 15px; border-radius: 6px;",
      HTML(rv$error_message)
    )
  })


  ## TAB 3: Reporting Data ####

  # Define reactive values
  rv <- reactiveValues(
    report_data = NULL,
    error_message = NULL
  )

  # Run code to report data ('report_gfdata' function)
  observeEvent(input$run_report, {
    req(input$unit, input$user, input$pass, input$dates)

    # Check inputs
    unit <- convert_unit(input$unit, 1)

    # Reactive expression to get the path
    rfid_path <- reactive({
      if (!is.null(input$rfid_file)) input$rfid_file$datapath else NULL
    })

    withProgress(message = "Downloading and processing data...", value = 0, {
      tryCatch({
        # Step 1: Authentication
        req(input$user, input$pass)
        login_req <- httr::POST(
          "https://portal.c-lockinc.com/api/login",
          body = list(user = input$user, pass = input$pass)
        )
        httr::stop_for_status(login_req)
        token <- trimws(httr::content(login_req, as = "text"))
        incProgress(0.2, detail = "Authenticated...")

        # Step 2: Data download
        url <- paste0(
          "https://portal.c-lockinc.com/api/getemissions?d=visits&fids=", unit,
          "&st=", input$dates[1], "&et=", input$dates[2], "%2012:00:00&type=2"
        )
        message(url)
        data_req <- httr::POST(url, body = list(token = token))
        httr::stop_for_status(data_req)
        raw_txt <- httr::content(data_req, as = "text")
        incProgress(0.3, detail = "Data downloaded...")

        # Step 3: Convert to dataframe
        lines <- stringr::str_split(raw_txt, "\n")[[1]]
        df <- do.call("rbind", stringr::str_split(lines[3:length(lines)], ","))
        df <- as.data.frame(df)
        colnames(df) <- c(
          "FeederID", "AnimalName", "RFID", "StartTime", "EndTime", "GoodDataDuration",
          "CO2GramsPerDay", "CH4GramsPerDay", "O2GramsPerDay", "H2GramsPerDay", "H2SGramsPerDay",
          "AirflowLitersPerSec", "AirflowCf", "WindSpeedMetersPerSec", "WindDirDeg", "WindCf",
          "WasInterrupted", "InterruptingTags", "TempPipeDegreesCelsius", "IsPreliminary", "RunTime"
        )
        incProgress(0.2, detail = "Data parsed...")

        # Step 4: Process RFID file
        rfid_df <- if (!is.null(rfid_path)) process_rfid_data(rfid_path) else NULL

        # Step 5: Clean and process data
        df <- df %>%
          dplyr::filter(RFID != "unknown") %>%
          dplyr::mutate(RFID = gsub("^0+", "", RFID)) %>%
          { if (!is.null(rfid_df) && nrow(rfid_df) > 0) inner_join(., rfid_df, by = "RFID") else . } %>%
          dplyr::distinct_at(dplyr::vars(1:5), .keep_all = TRUE) %>%
          dplyr::mutate(
            GoodDataDuration = round(
              as.numeric(substr(GoodDataDuration, 1, 2)) * 60 +
                as.numeric(substr(GoodDataDuration, 4, 5)) +
                as.numeric(substr(GoodDataDuration, 7, 8)) / 60,
              2
            ),
            HourOfDay = round(
              as.numeric(substr(substr(StartTime, 12, 19), 1, 2)) +
                as.numeric(substr(substr(StartTime, 12, 19), 4, 5)) / 60,
              2
            )
          ) %>%
          dplyr::filter(AirflowLitersPerSec >= 25)

        cols_to_convert <- c("CH4GramsPerDay", "CO2GramsPerDay", "O2GramsPerDay", "H2GramsPerDay")
        df[cols_to_convert] <- lapply(df[cols_to_convert], as.numeric)
        incProgress(0.3, detail = "Data cleaned...")

        rv$report_data <- df

        # Handle error messages
        rv$error_message <- NULL

      }, error = function(e) {
        msg <- as.character(e$message)
        if (grepl("names.*must be the same length as the vector", msg)) {
          rv$error_message <- "No data for the requested:<br>- User<br>- Unit<br>- Period<br>Please check your inputs."
        } else if (grepl("Cannot open file for writing", msg)) {
          rv$error_message <- "Error: Cannot write file.<br>Please check and re-enter a valid save directory."
        } else if (grepl("Unexpected error: Mismatch *unit-foodtype combinations", msg)) {
          rv$error_message <- "Error: Mismatch between number of units and gcup."
        } else {
          rv$error_message <- paste("Unexpected error:", msg)
        }
      })
    })
  })

  # Summary Card
  output$report_summary <- renderUI({
    df <- rv$report_data
    if (is.null(df) || nrow(df) == 0) return(NULL)

    date_col <- "StartTime"
    animal_col <- "RFID"
    n_days <- dplyr::n_distinct(as.Date(df$StartTime))
    n_animals <- if (animal_col %in% names(df)) length(unique(df[[animal_col]])) else "Unknown"
    div(
      class = "summary-card",
      icon("chart-bar", style = "color:#388e3c; font-size:22px; margin-right:6px;"),
      strong("GreenFeed Report Summary"),
      tags$ul(
        tags$li(strong("Animals: "), n_animals),
        tags$li(strong("Days: "), n_days),
        tags$li(strong("Total Records: "), nrow(df)),
      )
    )
  })

  # Create collapsible data preview
  output$report_preview <- renderUI({
    df <- rv$report_data
    if (is.null(df) || nrow(df) == 0) return(NULL)
    tags$details(
      tags$summary(style = "font-weight:bold; text-decoration:underline; cursor:pointer;",
                   "Show/hide processed data table"),
      DT::dataTableOutput("report_table")
    )
  })

  # Show data table
  output$report_table <- DT::renderDataTable({
    df <- rv$report_data
    if (is.null(df) || nrow(df) == 0) return(NULL)
    DT::datatable(head(df, 100), options = list(scrollX = TRUE, pageLength = 10))
  })

  # Grid to Choose the Plot
  output$chosen_plot <- renderUI({
    df <- rv$report_data
    if (is.null(df) || nrow(df) == 0) return(NULL)
    plotname <- input$which_plot
    if (is.null(plotname)) return(NULL)
    plotlyOutput(plotname, height = "400px")
  })

  # Plot 1: Records per Day
  output$plot_1 <- renderPlotly({
    df <- rv$report_data
    if (is.null(df) || nrow(df) == 0) {
      return(plotly_empty(type="scatter", mode="markers") %>% layout(title="No data for Records Per Day"))
    }

    df_count <- as.data.frame(table(as.Date(df$StartTime)))
    colnames(df_count) <- c("Date", "Records")

    df_count$Date <- as.Date(df_count$Date)

    p <- ggplot(df_count, aes(x = Date, y = Records)) +
      geom_col(fill = "#43a047", width = 0.7, alpha = 0.87) +
      labs(
        title = "Records Per Day",
        subtitle = paste0("From ", min(df_count$Date), " to ", max(df_count$Date)),
        x = "",
        y = "Number of Records"
      ) +
      scale_x_date(date_breaks = "1 day", date_labels = "%d-%b") +
      theme_minimal(base_size = 12) +
      theme(
        plot.title = element_text(size = 13, face = "bold", hjust = 0.5, color = "#388e3c"),
        plot.subtitle = element_text(size = 11, color = "#424242", hjust = 0.5),
        axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
        axis.title.y = element_text(size = 10, face = "bold"),
        panel.grid.major.x = element_blank(),
        # Make ggplot backgrounds transparent
        plot.background = element_rect(fill = "transparent", color = NA),
        panel.background = element_rect(fill = "transparent", color = NA),
        legend.background = element_rect(fill = "transparent", color = NA),
        # Remove grid lines
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank()
      )
    ggplotly(p, tooltip = c("x", "y"))
  })

  # Plot 2: Records per Animal
  output$plot_2 <- renderPlotly({
    df <- rv$report_data
    if (is.null(df) || nrow(df) == 0) {
      return(plotly_empty(type="scatter", mode="markers") %>% layout(title="No data for Total Records Per Animal/Farm"))
    }

    # Try to read the RFID file
    rfid_file <- input$rfid_file
    rfid_df <- NULL
    if (!is.null(rfid_file)) {
      ext <- tools::file_ext(rfid_file$datapath)
      rfid_df <- tryCatch({
        if (tolower(ext) %in% c("xls", "xlsx")) {
          readxl::read_excel(rfid_file$datapath)
        } else if (tolower(ext) == "csv") {
          read.csv(rfid_file$datapath)
        } else NULL
      }, error = function(e) NULL)
    }

    group_var <- if (!is.null(rfid_df) && is.data.frame(rfid_df) && nrow(rfid_df) > 0) "FarmName" else "RFID"

    df <- df %>%
      dplyr::mutate(
        CH4GramsPerDay = as.numeric(CH4GramsPerDay),
        GoodDataDuration = as.numeric(GoodDataDuration)
      ) %>%
      dplyr::filter(!is.na(CH4GramsPerDay), !is.na(GoodDataDuration))

    if(nrow(df) == 0) {
      return(plotly_empty(type="scatter", mode="markers") %>% layout(title="No valid data for Animals"))
    }

    farmname_order <- df %>%
      dplyr::mutate(day = as.Date(EndTime),
                    label = !!rlang::sym(group_var)) %>%
      dplyr::group_by(label, day) %>%
      dplyr::summarise(
        n = dplyr::n(),
        daily_CH4 = weighted.mean(CH4GramsPerDay, GoodDataDuration, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::group_by(label) %>%
      dplyr::summarise(
        n = sum(n),
        daily_CH4 = mean(daily_CH4, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::arrange(desc(daily_CH4)) %>%
      dplyr::pull(label)

    plotdf <- df %>%
      dplyr::mutate(day = as.Date(EndTime),
                    label = !!rlang::sym(group_var)) %>%
      dplyr::group_by(label, day) %>%
      dplyr::summarise(
        n = dplyr::n(),
        daily_CH4 = weighted.mean(CH4GramsPerDay, GoodDataDuration, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::group_by(label) %>%
      dplyr::summarise(
        n = sum(n),
        daily_CH4 = mean(daily_CH4, na.rm = TRUE),
        .groups = "drop"
      )

    if(nrow(plotdf) == 0) {
      return(plotly_empty(type="scatter", mode="markers") %>% layout(title="No valid data for Animals"))
    }

    p <- plotdf %>%
      ggplot(aes(
        x = factor(label, levels = farmname_order),
        y = n,
        fill = daily_CH4,
        text = paste(
          "ID: ", label,
          "<br>Total Records: ", n,
          "<br>Mean CH₄: ", signif(daily_CH4, 3)
        )
      )) +
      geom_bar(stat = "identity", position = position_dodge(), color = "white", width = 0.7) +
      scale_fill_gradient(low = "#43a047", high = "#388e3c", name = "Mean CH₄") +
      labs(
        title = "Total Records Per Animal",
        x = "",
        y = "Total Records"
      ) +
      theme_minimal(base_size = 12) +
      theme(
        plot.title = element_text(size = 13, face = "bold", hjust = 0.5, color = "#388e3c"),
        plot.subtitle = element_text(size = 11, color = "#424242", hjust = 0.5),
        axis.text.x = element_blank(),
        axis.title.y = element_text(size = 10, face = "bold"),
        legend.position = "none",
        # Make ggplot backgrounds transparent
        plot.background = element_rect(fill = "transparent", color = NA),
        panel.background = element_rect(fill = "transparent", color = NA),
        legend.background = element_rect(fill = "transparent", color = NA),
        # Remove grid lines
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank()
      )

    ggplotly(p, tooltip = "text")
  })

  # Plot 3: Gas Production Across the Day (user selects gases to plot, default = ch4)
  output$plot_3 <- renderPlotly({
    df <- rv$report_data
    if (is.null(df) || nrow(df) == 0) {
      return(plotly_empty(type="scatter", mode="markers") %>% layout(title="No data for Gas Production Across The Day"))
    }

    # Use UI input for selected gases, default to "ch4" if none selected
    plot_opt <- input$plot3_gas
    if (is.null(plot_opt) || length(plot_opt) == 0) plot_opt <- "ch4"

    # Generate the combined plot (function must be defined in your server or sourced)
    generate_combined_plot <- function(df, plot_opt) {
      # Convert to lowercase to avoid case sensitivity issues
      plot_opt <- tolower(plot_opt)

      if ("all" %in% plot_opt) {
        options_selected <- c("ch4", "o2", "co2", "h2")
      } else {
        options_selected <- plot_opt
      }

      # Normalize the data
      df_normalized <- df %>%
        dplyr::mutate(
          Normalized_CH4 = scale(CH4GramsPerDay),
          Normalized_CO2 = scale(CO2GramsPerDay),
          Normalized_O2 = scale(O2GramsPerDay),
          Normalized_H2 = scale(H2GramsPerDay)
        )

      # Create a base plot
      combined_plot <- ggplot(df_normalized[df_normalized$HourOfDay <= 23, ], aes(x = HourOfDay)) +
        labs(
          title = "Gas Production Across The Day",
          x = "",
          y = "Normalized Gas Value",
          color = "Gas type"
        ) +
        theme_minimal(base_size = 12) +
        theme(
          plot.title = element_text(size = 13, face = "bold", hjust = 0.5, color = "#388e3c"),
          plot.subtitle = element_text(size = 11, color = "#424242", hjust = 0.5),
          axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
          axis.title.y = element_text(size = 10, face = "bold"),
          legend.position = "none",
          # Make ggplot backgrounds transparent
          plot.background = element_rect(fill = "transparent", color = NA),
          panel.background = element_rect(fill = "transparent", color = NA),
          legend.background = element_rect(fill = "transparent", color = NA),
          # Remove grid lines
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank()
        ) +
        scale_x_continuous(
          breaks = seq(0, 23),
          labels = c(
            "12 AM", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11",
            "12 PM", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"
          )
        )

      # Initialize empty lists for points and smooth lines
      points_list <- list()
      smooth_list <- list()

      # Loop through selected options to add points and smooth lines
      for (gas in options_selected) {
        if (gas == "ch4") {
          points_list <- c(points_list, list(geom_point(aes(y = Normalized_CH4), color = "#E0E0E0")))
          smooth_list <- c(smooth_list, list(geom_smooth(aes(y = Normalized_CH4, color = "ch4"), se = FALSE)))
        }
        if (gas == "co2") {
          points_list <- c(points_list, list(geom_point(aes(y = Normalized_CO2), color = "#E0E0E0")))
          smooth_list <- c(smooth_list, list(geom_smooth(aes(y = Normalized_CO2, color = "co2"), se = FALSE)))
        }
        if (gas == "o2") {
          points_list <- c(points_list, list(geom_point(aes(y = Normalized_O2), color = "#E0E0E0")))
          smooth_list <- c(smooth_list, list(geom_smooth(aes(y = Normalized_O2, color = "o2"), se = FALSE)))
        }
        if (gas == "h2") {
          points_list <- c(points_list, list(geom_point(aes(y = Normalized_H2), color = "#E0E0E0")))
          smooth_list <- c(smooth_list, list(geom_smooth(aes(y = Normalized_H2, color = "h2"), se = FALSE)))
        }
      }

      # Add points and smooth lines to the combined plot
      combined_plot <- combined_plot + do.call("list", points_list)
      combined_plot <- combined_plot + do.call("list", smooth_list)

      # Add a manual color scale with gas names
      combined_plot <- combined_plot +
        scale_color_manual(
          values = c(
            "ch4" = "#388e3c",
            "co2" = "#1976d2",
            "o2"  = "#8B5742",
            "h2"  = "#8B4789"
          )
        )

      # Check for valid options
      valid_options <- c("all", "ch4", "co2", "o2", "h2")
      if (!all(options_selected %in% valid_options)) {
        stop("Invalid plot option selected.")
      }

      return(combined_plot)
    }
    p <- generate_combined_plot(df, plot_opt)

    # Convert to plotly for interactivity
    ggplotly(p)
  })


  # TAB 4: Processing Data ####

  # Reactive value to store eval results
  eval_param_result <- reactiveVal(NULL)

  observeEvent(input$run_eval_param, {
    req(input$gf_file, input$dates)

    # Read data file: preliminary (.csv) and finalized (.xlsx)
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

    # Evaluate all the combination of parameters to process data
    result <- NULL
    withProgress(message = "⏳ Evaluating all possible combination of parameters...", value = 0, {
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
    })

    eval_param_result(result)

    # Render table of evaluation results
    output$eval_section_title <- renderUI({
      req(eval_param_result())
      h4("Evaluation of Parameter Combinations:")
    })

    output$eval_param_table <- renderTable({
      req(eval_param_result())
      eval_param_result()
    })

    # Define format of the table
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

  # Reactive value to store proccessed results
  processed_result <- reactiveVal(NULL)

  observeEvent(input$run_process, {
    req(input$gf_file, input$dates, input$param1, input$param2)

    # Read data file: preliminary (.csv) and finalized (.xlsx)
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

    # Process data using the parameters chosen
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

    # Provide summary using the weekly data
    weekly <- result$weekly_data

    gas_names <- names(weekly)[grepl("CH4|CO2|O2|H2", names(weekly))]
    gas_stats <- vapply(gas_names, function(gas) {
      vals <- weekly[[gas]]
      mean_val <- mean(vals, na.rm = TRUE)
      sd_val <- sd(vals, na.rm = TRUE)
      cv_val <- if (!is.na(mean_val) && mean_val != 0) sd_val / mean_val * 100 else NA
      c(mean = mean_val, sd = sd_val, cv = cv_val)
    }, FUN.VALUE = c(mean = 0, sd = 0, cv = 0))

    gas_display_name <- function(names_vec) {
      # Replace GramsPerDay with (g/d)
      names_vec <- gsub("GramsPerDay", " (g/d)", names_vec)
      # Replace LitersPerDay with (L/d)
      names_vec <- gsub("LitersPerDay", " (L/d)", names_vec)
      names_vec
    }

    gas_df <- data.frame(
      Gas = gas_display_name(gas_names),
      Mean = round(gas_stats["mean", ], 2),
      SD = round(gas_stats["sd", ], 2),
      CV = round(gas_stats["cv", ], 1),
      stringsAsFactors = FALSE
    )

    # Render table of processed results
    output$proc_section_title <- renderUI({
      req(processed_result())
      h4("Data Summary:")
    })

    output$proc_summary_table <- renderTable({
      req(gas_df)
      gas_df
    }, digits = 2)

    # Options to download
    ## Filtered data
    output$download_filtered <- downloadHandler(
      filename = function() { "filtered_data.csv" },
      content = function(file) {
        write.csv(processed_result()$filtered_data, file, row.names = FALSE)
      }
    )

    ## Daily average data
    output$download_daily <- downloadHandler(
      filename = function() { "daily_data.csv" },
      content = function(file) {
        write.csv(processed_result()$daily_data, file, row.names = FALSE)
      }
    )

    ## Weekly average data
    output$download_weekly <- downloadHandler(
      filename = function() { "weekly_data.csv" },
      content = function(file) {
        write.csv(processed_result()$weekly_data, file, row.names = FALSE)
      }
    )

  })



}

shinyApp(ui, server)
