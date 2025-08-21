# app_server.R

server <- function(input, output, session) {

#### ---------------------- TAB 1: DOWNLOADING DATA ----------------------- ####

  # Define reactive values
  rv <- reactiveValues(
    data = NULL,
    df_preview = NULL,
    error_message_download = NULL
  )

  # Run code for download data from the C-Lock server
  observeEvent(input$load_data, {
    req(input$user, input$pass, input$unit, input$dates)
    unit <- convert_unit(input$unit, 1)

    withProgress(message = "🕐 Loading Data", value = 0, {
      df <- tryCatch({
        incProgress(0.1, detail = "Connecting to the C-Lock server...")
        # Download function defined in utils.R
        download_data(input$user,
                      input$pass,
                      input$d,
                      type = 2,
                      unit,
                      input$dates[1],
                      input$dates[2])
      }, error = function(e) {
        NULL
      })

      incProgress(0.2, detail = "Done!")

      # Show error ONLY for "no valid data retrieved" (i.e., NULL or only 1 row)
      if (is.null(df) || !is.data.frame(df) || nrow(df) <= 1) {
        rv$error_message_download <- "<b>Please check your inputs</b>
                                <br>
                                <br>We couldn't retrieve valid data for the following reasons:
                                <br>- User/Password
                                <br>- Unit(s)
                                <br>- Period (should not exceed 6 months)"
        rv$data <- NULL
        rv$df_preview <- NULL
        return()
      } else {
        rv$data <- df
        rv$df_preview <- head(df, 100)
        rv$error_message_download <- NULL
      }
    })
  })

  # Conditional on loading data show download button
  output$download_ui <- renderUI({
    if (!is.null(rv$data)) {
      downloadButton("download_data", "Download Data")
    }
    # else returns NULL (button hidden)
  })

  # Download handler lets user choose where to save
  output$download_data <- downloadHandler(
    filename = function() {
      # Build file_path to save data
      unit <- gsub("[,\\s]+", "_", input$unit)
      switch(input$d,
             "visits" = paste0("GreenFeed_Summarized_Data_", unit, "_", input$dates[1], "_", input$dates[2], ".csv"),
             "feed"   = paste0("Feedtimes_", unit, "_", input$dates[1], "_", input$dates[2], ".csv"),
             "rfid"   = paste0("Rfids_", unit, "_", input$dates[1], "_", input$dates[2], ".csv"),
             "cmds"   = paste0("Commands_", unit, "_", input$dates[1], "_", input$dates[2], ".csv")
      )
    },
    content = function(file) {
      req(rv$data)
      readr::write_csv(rv$data, file)
    }
  )

  # Summary card
  output$summary_card_download <- renderUI({
    req(input$load_data)
    df <- rv$data

    if (!is.null(df) && is.data.frame(df) && nrow(df) > 0 && is.null(rv$error_message1)) {
      # Select ID col and get unique IDs (removing NA and unknown ones)
      animal_col <- grep("RFID|CowTag", names(df), value = TRUE)[1]
      unique_ids <- if (!is.null(animal_col)) {
        length(unique(df[[animal_col]][!is.na(df[[animal_col]]) & df[[animal_col]] != "unknown"]))
      } else {
        "N/A"
      }
      # Select the Date col and get number of days requested
      date_col <- grep("StartTime|FeedTime|ScanTime|CommandTime", names(df), value = TRUE)[1]
      n_days <- if (!is.null(date_col)) length(unique(as.Date(df[[date_col]]))) else "Unknown"

      div(
        class = "summary-card",
        style = "background: #e8f5e9; border-radius: 7px; padding: 18px; margin-bottom: 10px; box-shadow: 0 2px 6px #eee;",
        icon("chart-bar", style = "color:#388e3c; font-size:22px; margin-right:6px;"),
        strong("GreenFeed Data Summary"),
        tags$ul(
          tags$li(strong("IDs: "), unique_ids),
          tags$li(strong("Days: "), n_days),
          tags$li(strong("Dimensions: "), nrow(df), "rows x ", ncol(df), "columns")
        )
      )
    } else {
      NULL
    }
  })

  # Data preview (hidden in a link)
  output$preview <- renderUI({
    req(rv$df_preview)
    # Show a link to press and access data
    tagList(
      tags$details(
        tags$summary(style = "font-weight:bold; text-decoration:underline; cursor:pointer;",
                     "Show/Hide Data Preview"),
        DT::dataTableOutput("preview_table")
      ),
      div(
        style = "color: #888; font-size: 13px; margin-top: 12px; margin-bottom: 10px;",
        "Please Note: Data generated is preliminary and has not been reviewed by the C-Lock Team."
      )
    )
  })

  # Table data preview
  output$preview_table <- DT::renderDataTable({
    req(rv$df_preview)
    DT::datatable(head(rv$df_preview, 100), options = list(scrollX = TRUE, pageLength = 5))
  })

  # Error message format
  output$error_message_download <- renderUI({
    print(rv$error_message_download)
    req(rv$error_message_download)
    div(
      style = "background-color: #fff6f6;
               border: 2px solid #e74c3c;
               color: #c0392b;
               padding: 15px;
               margin-bottom: 15px;
               border-radius: 6px;",
      HTML(rv$error_message_download)
    )
  })


#### ---------------------- TAB 2: CHECKING DATA -------------------------- ####

  # Define reactive values
  rv <- reactiveValues(
    viseat_result = NULL,
    pellin_result = NULL,
    error_message_viseat = NULL,
    error_message_pellin = NULL
  )

  # Run code to check visitation ('viseat' function)
  observeEvent(input$run_viseat, {
    req(input$dates, input$unit)

    # Check unit input
    unit <- convert_unit(input$unit, 1)

    # Get RFID file path
    rfid_path <- if (!is.null(input$rfid_file1)) input$rfid_file1$datapath else NULL

    withProgress(message = '🏃🏻‍♂️ Running Viseat', value = 0, {
      result <- NULL
      incProgress(0.1, detail = "Connecting to the C-Lock server...")
      tryCatch({
        result <- greenfeedr::viseat(
          user = input$user,
          pass = input$pass,
          unit = unit,
          start_date = input$dates[1],
          end_date = input$dates[2],
          rfid_file = rfid_path
        )
      }, error = function(e) {
        rv$error_message_viseat <- paste0("Unexpected error: ", e$message)
        result <<- NULL
      })

      incProgress(0.2, detail = "Done!")

      # Show error ONLY for "no valid data retrieved" (i.e., NULL or only 1 row)
      if (is.null(result) || !is.data.frame(result$feedtimes) || nrow(result$feedtimes) <= 1) {
        rv$error_message_viseat <- "<b>Please check your inputs</b>
                                  <br>
                                  <br>We couldn't retrieve valid data for the following reasons:
                                  <br>- User/Password
                                  <br>- Unit(s)
                                  <br>- Period (should not exceed 6 months)"
        rv$viseat_result <- NULL
        return()
      } else {
        rv$viseat_result <- result
        rv$error_message_viseat <- NULL
      }
    })
  })

  # Summary card
  output$summary_card_viseat <- renderUI({
    req(input$run_viseat > 0)

    df <- rv$viseat_result$feedtimes
    if (is.null(df) || nrow(df) == 0) return(NULL)

    # Number of animals visiting the units
    animal_col <- "CowTag"
    n_animals <- if (animal_col %in% names(df)) length(unique(df[[animal_col]])) else "Unknown"

    # Number of days with visits in the units
    date_col <- "FeedTime"
    n_days <- dplyr::n_distinct(as.Date(df[[date_col]]))

    # Number of visits per unit
    unit_col <- "FID"
    visits_by_unit <- table(df[[unit_col]])

    # Number of visits per animal per day
    min_visits <- min(as.numeric(rv$viseat_result$visits_per_day$visits), na.rm = TRUE)
    median_visits <- median(as.numeric(rv$viseat_result$visits_per_day$visits), na.rm = TRUE)
    max_visits <- max(as.numeric(rv$viseat_result$visits_per_day$visits), na.rm = TRUE)

    # Get the vector of IDs from the result
    animals_wout_visits <- rv$viseat_result$animals_wout_visits$animal_id

    # Create summary card
    div(
      class = "summary-card",
      style = "background: #e8f5e9; border-radius: 7px; padding: 18px; margin-bottom: 10px; box-shadow: 0 2px 6px #eee;",
      icon("chart-bar", style = "color:#388e3c; font-size:22px; margin-right:6px;"),
      strong("Visitation Report Summary"),
      tags$ul(
        tags$li(strong("IDs: "), n_animals),
        tags$li(strong("Days: "), n_days),
        # Only include this if there are missing IDs
        if (!is.null(animals_wout_visits) && length(animals_wout_visits) > 0) {
          tags$li(
            strong("IDs not visiting GreenFeed unit(s): "),
            paste(animals_wout_visits, collapse = ", ")
          )
        },
        tags$li(
          strong("Total Visits: "),
          tags$ul(
            lapply(seq_along(visits_by_unit), function(i) {
              tags$li(
                tags$b("Unit ", names(visits_by_unit)[i]), ": ", visits_by_unit[i]
              )
            })
          )
        ),
        tags$li(strong("Visits per Animal-Day: ")),
        tags$ul(
          tags$li(strong("Min: "), min_visits),
          tags$li(strong("Median: "), median_visits),
          tags$li(strong("Max: "), max_visits)
        )
      )
    )
  })

  # Plot 2.1: Visits per Animal
  output$plot2_1 <- renderPlotly({
    df <- rv$viseat_result$visits_per_day

    # Dynamically choose the animal ID column
    animal_col <- if ("RFID" %in% names(df)) "RFID" else if ("FarmName" %in% names(df)) "FarmName" else NULL
    if (is.null(animal_col)) return(NULL)

    p1 <- ggplot(df, aes(x = factor(.data[[animal_col]]), y = visits)) +
          geom_boxplot(fill = "#A1D99B", alpha = 0.70) +
          labs(
            title = "Visits Per Animal",
            x = "",
            y = "Visits"
          ) +
          theme_minimal(base_size = 12) +
          theme(
            plot.title = element_text(size = 13, face = "bold", hjust = 0.5, color = "#388e3c"),
            axis.text.x = element_text(angle = 90, hjust = 1, size = 6),
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
        ggplotly(p1)
      })

  # Plot 2.2: Visits per Day-Unit
  output$plot2_2 <- renderPlotly({
    df <- rv$viseat_result$feedtimes

    # Safely get columns
    date_col <- "FeedTime"
    unit_col <- "FID"
    if (!all(c(date_col, unit_col) %in% names(df))) return(NULL)

        # Parse dates if not already
        df[[date_col]] <- as.Date(df[[date_col]])

        # Aggregate visits per day per unit
        agg_df <- df %>%
          dplyr::group_by(.data[[date_col]], .data[[unit_col]]) %>%
          dplyr::summarise(visits = dplyr::n(), .groups = "drop")

        # Define the palette of colours (increase if needed)
        palette <- c("#A1D99B", "#31A354", "#238B45", "#006D2C", "#00441B")
        # Define the barplot with labels and colors per unit
        p2 <- ggplot(
          agg_df,
          aes(x = .data[[date_col]], y = visits, fill = factor(.data[[unit_col]]),
            text = paste0(
              "Date: ", .data[[date_col]],"\n",
              "Unit: ", .data[[unit_col]],"\n",
              "Visits: ", visits)
          )) +
          geom_col(position = position_dodge(width = 0.8), width = 0.7) +
          scale_fill_manual(values = palette) +
          labs(
            title = "Visits Per Day (by Unit)",
            x = "",
            y = "Visits",
            fill = "Unit"
          ) +
          theme_minimal(base_size = 12) +
          theme(
            plot.title = element_text(size = 13, face = "bold", hjust = 0.5, color = "#388e3c"),
            axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
            axis.title.y = element_text(size = 10, face = "bold"),
            panel.grid.major.x = element_blank(),
            plot.background = element_rect(fill = "transparent", color = NA),
            panel.background = element_rect(fill = "transparent", color = NA),
            legend.background = element_rect(fill = "transparent", color = NA),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            legend.position = "none"
          )

        ggplotly(p2, tooltip = "text")
      })

  # Error message format
  output$error_message_viseat <- renderUI({
    req(rv$error_message_viseat)
    div(
      style = "background-color: #fff6f6;
               border: 2px solid #e74c3c;
               color: #c0392b;
               padding: 15px;
               margin-bottom: 15px;
               border-radius: 6px;",
      HTML(rv$error_message_viseat)
    )
  })


  # Run code to calculate intakes ('pellin' function)
  observeEvent(input$run_pellin, {
    req(input$gcup, input$unit)

    # Check gcup and unit inputs
    gcup <- as.numeric(strsplit(input$gcup, ",")[[1]])
    unit <- convert_unit(input$unit, 2)

    # Get RFID file path
    rfid_path <- if (!is.null(input$rfid_file1)) input$rfid_file1$datapath else NULL

    withProgress(message = '🏃‍♀️ Running Pellin', value = 0, {
      result <- NULL
      incProgress(0.1, detail = "Connecting to the C-Lock server...")
      tryCatch({
        result <- greenfeedr::pellin(
          user = input$user,
          pass = input$pass,
          unit = unit,
          gcup = gcup,
          start_date = input$dates[1],
          end_date = input$dates[2],
          save_dir = NULL,
          rfid_file = rfid_path
        )
      }, error = function(e) {
        if (grepl("Mismatch.*unit-foodtype", e$message)) {
          rv$error_message_pellin <<- "<b>Please check your input</b>
                                      <br>
                                      <br>There is a mismatch between number of units and gcup"
        } else {
          rv$error_message_pellin <<- paste("Unexpected error:", e$message)
        }
        result <<- NULL
      })

      # Show error ONLY for "no valid data retrieved" (i.e., NULL or only 1 row)
      if (!is.data.frame(result) || nrow(result) <= 1) {
        rv$error_message_pellin <- "<b>Please check your inputs.</b>
                                 <br>
                                 <br>We couldn't retrieve valid data for the following reasons:
                                 <br>- User/Password
                                 <br>- Unit(s)
                                 <br>- Period (should not exceed 6 months)"
        rv$pellin_result <- NULL
        return()
      } else {
        rv$pellin_result <- result
        rv$error_message_pellin <- NULL
      }

      incProgress(0.2, detail = "Done!")
    })
  })

  # Summary card
  output$summary_card_pellin <- renderUI({
    df <- rv$pellin_result
    if (is.null(df) || !is.data.frame(df) || nrow(df) == 0) return(NULL)

    # Calculate summary statistics
    n_animals <- dplyr::n_distinct(df$RFID[!is.na(df$FoodType)])
    n_days <- dplyr::n_distinct(df$Date)
    total_intake <- round(sum(df$PIntake_kg, na.rm = TRUE), 2)
    mean_intake <- round(mean(df$PIntake_kg, na.rm = TRUE), 2)

    div(
      class = "summary-card",
      style = "background: #e8f5e9; border-radius: 7px; padding: 18px; margin-bottom: 10px; box-shadow: 0 2px 6px #eee;",
      icon("chart-bar", style = "color:#388e3c; font-size:22px; margin-right:6px;"),
      strong("Intakes Report Summary"),
      tags$ul(
        tags$li(strong("IDs: "), n_animals),
        tags$li(strong("Days: "), n_days),
        tags$li(strong("Average Pellet Intake per Animal-Day (g): "), mean_intake*1000)
      )
    )
  })

  # Summary table for pellin results
  output$pellin_table <- renderUI({
    df <- rv$pellin_result
    if (is.null(df) || !is.data.frame(df) || nrow(df) == 0) return(NULL)

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
    table_html <- knitr::kable(summary_df, format = "html") %>%
      kableExtra::kable_styling("striped", full_width = FALSE)
    HTML(table_html)
  })

  # Download handler
  output$download_pellin_ui <- renderUI({
    if (is.null(rv$error_message_pellin)) {
      downloadButton("download_pellin", "Download Pellin Result")
    }
    # If there's an error, nothing is returned so the button is hidden
  })

  output$download_pellin <- downloadHandler(
    filename = function() {
      unit <- gsub("[,\\s]+", "_", input$unit)
      paste0("PelletIntakes_", unit, "_", input$dates[1], "_", input$dates[2], ".csv")
    },
    content = function(file) {
      write.csv(rv$pellin_result, file, row.names = FALSE)
    }
  )

  # Error message format
  output$error_message_pellin <- renderUI({
    req(rv$error_message_pellin)
    div(
      style = "background-color: #fff6f6;
               border: 2px solid #e74c3c;
               color: #c0392b;
               padding: 15px;
               margin-bottom: 15px;
               border-radius: 6px;",
      HTML(rv$error_message_pellin)
    )
  })


#### ---------------------- TAB 3: REPORTING DATA ------------------------- ####

  # Define reactive values
  rv <- reactiveValues(
    report_data = NULL,
    error_message_report = NULL
  )

  # Run code to report data ('report_gfdata' function)
  observeEvent(input$run_report, {
    req(input$unit, input$user, input$pass, input$dates)

    # Check unit input
    unit <- convert_unit(input$unit, 1)

    # Get RFID file path
    rfid_path <- if (!is.null(input$rfid_file2)) input$rfid_file2$datapath else NULL

    withProgress(message = "🕐 Processing Data", value = 0, {
      df <- tryCatch({
        incProgress(0.1, detail = "Connecting to the C-Lock server...")
          # Download function defined in utils.R
          download_data(input$user,
                        input$pass,
                        d = "visits",
                        type = 2,
                        unit,
                        input$dates[1],
                        input$dates[2])
        }, error = function(e) {
          NULL
        })

        # Show error ONLY for "no valid data retrieved" (i.e., NULL or only 1 row)
        if (is.null(df) || !is.data.frame(df) || nrow(df) <= 1) {
          rv$error_message_report <- "<b>Please check your inputs</b>
                                      <br>
                                      <br>We couldn't retrieve valid data for the following reasons:
                                      <br>- User/Password
                                      <br>- Unit(s)
                                      <br>- Period (should not exceed 6 months)"
          rv$report_data <- NULL
          return()
        } else {
          rv$report_data <- df
          rv$error_message_report <- NULL
        }

        # Read and process RFID file
        rfid_df <- if (!is.null(rfid_path)) process_rfid_data(rfid_path) else NULL

        # Clean and process data
        incProgress(0.3, detail = "Data cleaning")
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

        incProgress(0.4, detail = "Done!")
        rv$report_data <- df

    })
  })

  # Summary card
  output$summary_card_report <- renderUI({
    df <- rv$report_data
    if (is.null(df) || nrow(df) == 0) return(NULL)

    date_col <- "StartTime"
    animal_col <- "RFID"
    n_days <- dplyr::n_distinct(as.Date(df$StartTime))
    n_animals <- if (animal_col %in% names(df)) length(unique(df[[animal_col]])) else "Unknown"

    # Calculate records per animal per day
    records_animal_day <- df %>%
      dplyr::mutate(day = lubridate::day(StartTime)) %>%
      dplyr::group_by(RFID, day) %>%
      dplyr::summarise(n = dplyr::n(), .groups = "drop")

    # Calculate min, median, and max
    min_records <- min(records_animal_day$n)
    median_records <- median(records_animal_day$n)
    max_records <- max(records_animal_day$n)

    div(
      class = "summary-card",
      style = "background: #e8f5e9; border-radius: 7px; padding: 18px; margin-bottom: 10px; box-shadow: 0 2px 6px #eee;",
      icon("chart-bar", style = "color:#388e3c; font-size:22px; margin-right:6px;"),
      strong("GreenFeed Report Summary"),
      tags$ul(
        tags$li(strong("IDs: "), n_animals),
        tags$li(strong("Days: "), n_days),
        tags$li(strong("Total Records: "), nrow(df)),
        tags$li(strong("Records per Animal-Day:")),
        tags$ul(
          tags$li(strong("Min: "), min_records),
          tags$li(strong("Median: "), median_records),
          tags$li(strong("Max: "), max_records)
        )
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
    DT::datatable(head(df, 100), options = list(scrollX = TRUE, pageLength = 5))
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
        x = "",
        y = "Number of Records"
      ) +
      theme_minimal(base_size = 12) +
      theme(
        plot.title = element_text(size = 13, face = "bold", hjust = 0.5, color = "#388e3c"),
        axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
        axis.title.y = element_text(size = 10, face = "bold"),
        panel.grid.major.x = element_blank(),
        plot.background = element_rect(fill = "transparent", color = NA),
        panel.background = element_rect(fill = "transparent", color = NA),
        legend.background = element_rect(fill = "transparent", color = NA),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank()
      )

    ggplotly(p, tooltip = c("x", "y"))
  })

  # Plot 2: Records per Animal
  output$plot_2 <- renderPlotly({
    df <- rv$report_data
    if (is.null(df) || nrow(df) == 0) {
      return(plotly_empty(type="scatter", mode="markers") %>%
               layout(title="No data for Total Records Per Animal/Farm"))
    }

    # Try to read the RFID file
    rfid_file <- input$rfid_file2
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
      return(plotly_empty(type="scatter", mode="markers") %>%
               layout(title="No valid data for Animals"))
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
        daily_CO2 = weighted.mean(CO2GramsPerDay, GoodDataDuration, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::group_by(label) %>%
      dplyr::summarise(
        n = sum(n),
        daily_CH4 = mean(daily_CH4, na.rm = TRUE),
        daily_CO2 = mean(daily_CO2, na.rm = TRUE),
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
          "<br>Records: ", n,
          "<br>Ratio CO2:CH4: ", signif(daily_CO2/daily_CH4, 3)
        )
      )) +
      geom_bar(stat = "identity", position = position_dodge(), color = "white", width = 0.7) +
      scale_fill_gradient(low = "#43a047", high = "#388e3c", name = "Mean CH₄") +
      labs(
        title = "Records Per Animal",
        x = "",
        y = "Number of Records"
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

  # Plot 3: Gas Production Across the Day
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

      # Normalize the data and reshape to long format for easier plotting
      df_long <- df %>%
        dplyr::mutate(
          Norm_CH4 = as.numeric(scale(CH4GramsPerDay)),
          Norm_CO2 = as.numeric(scale(CO2GramsPerDay)),
          Norm_O2 = as.numeric(scale(O2GramsPerDay)),
          Norm_H2 = as.numeric(scale(H2GramsPerDay))
        ) %>%
        dplyr::select(HourOfDay, Norm_CH4, Norm_CO2, Norm_O2, Norm_H2) %>%
        tidyr::pivot_longer(
          cols = starts_with("Norm_"),
          names_to = "gas",
          values_to = "norm_value"
        ) %>%
        dplyr::mutate(
          gas = dplyr::recode(gas,
                              "Norm_CH4" = "ch4",
                              "Norm_CO2" = "co2",
                              "Norm_O2"  = "o2",
                              "Norm_H2"  = "h2"
          )
        ) %>%
        dplyr::filter(gas %in% options_selected, HourOfDay <= 23) %>%
        dplyr::mutate(
          text = paste0("Hour: ", round(HourOfDay,1),
                        "<br>Norm ", toupper(gas), ": ", round(norm_value, 2))
        )

      color_map <- c(
        "ch4" = "#388e3c",
        "co2" = "#1976d2",
        "o2"  = "#8B5742",
        "h2"  = "#8B4789"
      )

      p <- ggplot(df_long, aes(x = HourOfDay, y = norm_value, group = gas)) +
        geom_point(aes(text = text), color = "#E0E0E0") +
        geom_smooth(aes(color = gas), se = FALSE) +
        scale_color_manual(values = color_map) +
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
          plot.background = element_rect(fill = "transparent", color = NA),
          panel.background = element_rect(fill = "transparent", color = NA),
          legend.background = element_rect(fill = "transparent", color = NA),
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


      valid_options <- c("all", "ch4", "co2", "o2", "h2")
      if (!all(options_selected %in% valid_options)) {
        stop("Invalid plot option selected.")
      }

      return(p)
    }

    p <- generate_combined_plot(df, plot_opt)
    ggplotly(p, tooltip = "text")
  })

  # Error message format
  output$error_message_report <- renderUI({
    req(rv$error_message_report)
    div(
      style = "background-color: #fff6f6;
               border: 2px solid #e74c3c;
               color: #c0392b;
               padding: 15px;
               margin-bottom: 15px;
               border-radius: 6px;",
      HTML(rv$error_message_report)
    )
  })


#### ---------------------- TAB 4: PROCESSING DATA ------------------------ ####

  # Define reactive values
  rv <- reactiveValues(
    uploaded_data = NULL,
    eval_param_result = NULL,
    processed_result = NULL,
    error_message_eval = NULL,
    error_message_process = NULL
  )

  # Read and store uploaded 'GreenFeed' data
  observeEvent(input$gf_file1, {
    ext <- tools::file_ext(input$gf_file1$name)
    data <- tryCatch({
      if (tolower(ext) %in% c("xls", "xlsx")) {
        readxl::read_excel(input$gf_file1$datapath)
      } else if (tolower(ext) == "csv") {
        readr::read_csv(input$gf_file1$datapath, show_col_types = FALSE)
      } else {
        stop("Unsupported file type. Please upload a .csv, .xls, or .xlsx file.")
      }
    }, error = function(e) {
      rv$error_message_eval <- paste0("Error: ", e$message)
      NULL
    })
    rv$uploaded_data <- data
  })

  # Evaluate parameters
  observeEvent(input$run_eval_param, {
    req(rv$uploaded_data, input$dates, input$gas)

    df <- rv$uploaded_data
    df <- df[!is.na(df$RFID) & df$RFID != "unknown", ]

    withProgress(message = "⏳ Evaluating parameters", value = 0.1, {
      result <- tryCatch({
        incProgress(0.1, detail = "It could take a while...")
        greenfeedr::eval_gfparam(
          data = df,
          start_date = input$dates[1],
          end_date = input$dates[2],
          gas = input$gas
        )
      }, error = function(e) {
        rv$error_message_eval <- paste0("Error: ", e$message)
        NULL
      })

      rv$eval_param_result <- result

      # Check for all zeros in column 4 and 5
      if (!is.null(rv$eval_param_result) && ncol(rv$eval_param_result) >= 5) {
        df_check <- rv$eval_param_result
        zero_col4 <- all(df_check[[4]] == 0)
        zero_col5 <- all(df_check[[5]] == 0)
        if (zero_col4 && zero_col5) {
          rv$error_message_eval <- "Error: No records found in the selected date range.
                                    <br> Please check your file and date selection."
          rv$eval_param_result <- NULL
        }
      }
    })
  })

  # Summary card
  output$summary_card_eval <- renderUI({
    df <- rv$uploaded_data
    df <- df[!is.na(df$RFID) & df$RFID != "unknown", ]

    if (is.null(df) || nrow(df) == 0) return(NULL)

    # Check number of days
    date_col <- if ("StartTime" %in% names(df)) {
      "StartTime"
    } else if ("Start Time" %in% names(df)) {
      "Start Time"
    } else {
      NULL
    }
    n_days <- dplyr::n_distinct(as.Date(df[[date_col]]))

    # Check number of IDs
    animal_col <- "RFID"
    n_animals <- if (animal_col %in% names(df)) length(unique(df[[animal_col]])) else "Unknown"

    # Calculate records per animal per day
    df$day <- lubridate::day(df[[date_col]])
    records_animal_day <- df %>%
      #dplyr::mutate(day = lubridate::day(df[[date_col]])) %>%
      dplyr::group_by(RFID, day) %>%
      dplyr::summarise(n = dplyr::n(), .groups = "drop")

    # Calculate min, median, and max
    min_records <- min(records_animal_day$n)
    median_records <- median(records_animal_day$n)
    max_records <- max(records_animal_day$n)

    div(
      class = "summary-card",
      style = "background: #e8f5e9; border-radius: 7px; padding: 18px; margin-bottom: 10px; box-shadow: 0 2px 6px #eee;",
      icon("chart-bar", style = "color:#388e3c; font-size:22px; margin-right:6px;"),
      strong("GreenFeed Data Summary"),
      tags$ul(
        tags$li(strong("IDs: "), n_animals),
        tags$li(strong("Days: "), n_days),
        tags$li(strong("Total Records: "), nrow(df))
      )
    )
  })

  # Render parameter evaluation table
  output$eval_param_table <- DT::renderDataTable({
    req(rv$eval_param_result)
    df <- rv$eval_param_result
    if ("param1" %in% names(df)) df$param1 <- as.character(df$param1)
    if ("param2" %in% names(df)) df$param2 <- as.character(df$param2)
    if ("min_time" %in% names(df)) df$min_time <- as.character(df$min_time)
    names(df) <- c("Param1", "Param2", "Min_time", "N Records", "N Animals",
                   "Mean", "SD", "CV")[seq_len(ncol(df))]
    DT::datatable(
      df,
      options = list(
        pageLength = 5,
        autoWidth = FALSE,
        scrollX = TRUE
      ),
      filter = "top",
      rownames = FALSE
    ) %>%
      DT::formatStyle(
        columns = names(df),
        'text-align' = 'center'
      )
  })

  # Error message
  output$error_message_eval <- renderUI({
    req(rv$error_message_eval)
    div(
      style = "background-color: #fff6f6;
               border: 2px solid #e74c3c;
               color: #c0392b;
               padding: 15px;
               margin-bottom: 15px;
               border-radius: 6px;",
      HTML(rv$error_message_eval)
    )
  })

  # Process data
  observeEvent(input$run_process, {
    req(rv$uploaded_data, input$dates, input$param1, input$param2, input$min_time, input$cutoff)

    withProgress(message = "⏳ Processing data...", value = 0,{
    result <- tryCatch({
      greenfeedr::process_gfdata(
        data = rv$uploaded_data,
        start_date = input$dates[1],
        end_date = input$dates[2],
        param1 = input$param1,
        param2 = input$param2,
        min_time = input$min_time,
        transform = input$transform,
        cutoff = input$cutoff
      )
    }, error = function(e) {
      output$error_message_process <- renderText(paste("❌ Processing error:", e$message))
      return(NULL)
    })
    rv$processed_result <- result
  })
})

  # Render processed summary table
  output$summary_card_process <- renderUI({
    req(rv$processed_result)
    if (is.null(rv$processed_result$weekly_data)) return()
    weekly <- rv$processed_result$weekly_data

    gas_names <- names(weekly)[grepl("CH4|CO2|O2|H2", names(weekly))]
    gas_stats <- vapply(gas_names, function(gas) {
      vals <- weekly[[gas]]
      mean_val <- mean(vals, na.rm = TRUE)
      sd_val <- sd(vals, na.rm = TRUE)
      cv_val <- if (!is.na(mean_val) && mean_val != 0) sd_val / mean_val * 100 else NA
      c(mean = mean_val, sd = sd_val, cv = cv_val)
    }, FUN.VALUE = c(mean = 0, sd = 0, cv = 0))

    gas_display_name <- function(names_vec) {
      names_vec <- gsub("GramsPerDay", " (g/d)", names_vec)
      names_vec <- gsub("LitersPerDay", " (L/d)", names_vec)
      names_vec
    }

    tags$div(
      class = "summary-card",
      style = "background: #e8f5e9; border-radius: 7px; padding: 18px; margin-bottom: 10px; box-shadow: 0 2px 6px #eee;",
      icon("flask", style = "color:#388e3c; font-size:22px; margin-right:6px;"),
      strong("Processed Gas Data Summary"),
      tags$table(
        style = "width:100%; margin-top:12px; background: #e8f5e9; border-radius: 5px; border-collapse: collapse;",
        tags$thead(
          tags$tr(
            tags$th("Gas"),
            tags$th("Mean"),
            tags$th("SD"),
            tags$th("CV (%)")
          )
        ),
        tags$tbody(
          lapply(seq_along(gas_names), function(i) {
            round_digits <- if (grepl("H2", gas_names[i])) 3 else 1
            tags$tr(
              tags$td(gas_display_name(gas_names[i])),
              tags$td(round(gas_stats["mean", i], round_digits)),
              tags$td(round(gas_stats["sd", i], round_digits)),
              tags$td(round(gas_stats["cv", i], 1))
            )
          })
        )
      )
    )
  })

  # Download handlers
  output$download_filtered <- downloadHandler(
    filename = function() { "GreenFeed_Filtered_Data.csv" },
    content = function(file) {
      write.csv(rv$processed_result$filtered_data, file, row.names = FALSE)
    }
  )
  output$download_daily <- downloadHandler(
    filename = function() { "GreenFeed_Daily_Data.csv" },
    content = function(file) {
      write.csv(rv$processed_result$daily_data, file, row.names = FALSE)
    }
  )
  output$download_weekly <- downloadHandler(
    filename = function() { "GreenFeed_Weekly_Data.csv" },
    content = function(file) {
      write.csv(rv$processed_result$weekly_data, file, row.names = FALSE)
    }
  )

  # Error message format
  output$error_message_process <- renderUI({
    req(rv$error_message_process)
    div(
      style = "background-color: #fff6f6;
               border: 2px solid #e74c3c;
               color: #c0392b;
               padding: 15px;
               margin-bottom: 15px;
               border-radius: 6px;",
      HTML(rv$error_message_process)
    )
  })



#### ---------------------- TAB 5: ANALYZING DATA ------------------------- ####

  # Define reactive values
  rv <- reactiveValues(
    uploaded_df = NULL,
    processed_df = NULL,
    tukey_sig_df = NULL,
    error_message_analysis = NULL
  )

  # Read and store uploaded 'GreenFeed' data
  observeEvent(input$gf_file2, {
    ext <- tools::file_ext(input$gf_file2$name)
    data <- tryCatch({
      if (tolower(ext) %in% c("xls", "xlsx")) {
        readxl::read_excel(input$gf_file2$datapath)
      } else if (tolower(ext) == "csv") {
        readr::read_csv(input$gf_file2$datapath, show_col_types = FALSE)
      } else {
        stop("Unsupported file type. Please upload a .csv, .xls, or .xlsx file.")
      }
    }, error = function(e) {
      rv$error_message_analysis <- paste0("Error: ", e$message)
      NULL
    })
    rv$uploaded_df <- data
  })

  # Read RFID/Groups data
  rfid_df <- reactive({
    req(input$rfid_file3)
    process_rfid_data(input$rfid_file3$datapath)
  })

  observeEvent(input$run_analysis, {
    req(rv$uploaded_df, input$dates, input$param1, input$param2, input$min_time, input$cutoff)

    df <- rv$uploaded_df
    df <- df[!is.na(df$RFID) & df$RFID != "unknown", ]

    # Process GreenFeed data using the set of parameters defined by the user
    withProgress(message = "⏳ Analyzing data...", value = 0.1, {
    result <- tryCatch({
      greenfeedr::process_gfdata(
        data = df,
        start_date = input$dates[1],
        end_date = input$dates[2],
        param1 = input$param1,
        param2 = input$param2,
        min_time = input$min_time,
        cutoff = input$cutoff
      )
    }, error = function(e) {
      rv$error_message_analysis <- paste0("Error: ", e$message)
      NULL
    })

    # Get daily data
    if (!is.null(result) && !is.null(rfid_df()) && !is.null(result$daily_data)) {
    daily_df <- result$daily_data

    # Join daily GreenFeed data and Group info
    joined_df <- dplyr::left_join(rfid_df(), daily_df, by = "RFID")
    rv$processed_df <- joined_df

    # Compute a Tukey HSD Post-hoc test between groups
    gases <- c("CO2GramsPerDay", "CH4GramsPerDay", "O2GramsPerDay", "H2GramsPerDay")
    tukey_sig_df <- NULL

    for (gas in gases) {
      df_test <- joined_df[!is.na(joined_df[[gas]]) & !is.na(joined_df$Group), ]
      if (length(unique(df_test$Group)) > 1) {
        aov_res <- aov(df_test[[gas]] ~ df_test$Group)
        tukey_res <- TukeyHSD(aov_res)
        sig <- as.data.frame(tukey_res$`df_test$Group`)
        sig$Comparison <- rownames(sig)
        sig$Gas <- gas
        sig <- sig[sig$`p adj` < 0.05, c("Gas", "Comparison", "p adj")]
        if (nrow(sig) > 0) {
          tukey_sig_df <- bind_rows(tukey_sig_df, sig)
          }
        }
      }
    rv$tukey_sig_df <- tukey_sig_df

    } else {
      rv$tukey_sig_df <- NULL
      print("Either result, rfid_df, or result$daily_data is NULL")
      }
    })
  })

  # Summary card display format
  output$summary_card_analysis <- renderUI({
    req(rv$processed_df)

    # Calculate number of groups and animals
    n_groups <- rv$processed_df %>% dplyr::pull(Group) %>% unique() %>% length()
    n_animals <- rv$processed_df %>% dplyr::pull(RFID) %>% unique() %>% length()

    div(
      style = "background: #e8f5e9; border-radius: 7px; padding: 18px; margin-bottom: 10px; box-shadow: 0 2px 6px #eee;",
      icon("chart-bar", style = "color:#388e3c; font-size:22px; margin-right:6px;"),
      strong("Group Analysis Summary"),
      tags$ul(
        tags$li(strong("IDs: "), n_animals),
        tags$li(strong("Groups: "), n_groups)
      )
    )
  })

  # Render group summary table
  output$group_summary_table <- renderTable({
    req(rv$processed_df)

    # Summary records and gases per group/treatment
    group_summary <- rv$processed_df %>%
      dplyr::group_by(Group) %>%
      dplyr::summarise(
        N_Records = sum(n, na.rm = TRUE),
        Animals = n_distinct(RFID),
        Avg_CO2 = mean(CO2GramsPerDay, na.rm = TRUE),
        SD_CO2 = sd(CO2GramsPerDay, na.rm = TRUE),
        Avg_CH4 = mean(CH4GramsPerDay, na.rm = TRUE),
        SD_CH4 = sd(CH4GramsPerDay, na.rm = TRUE),
        Avg_O2 = mean(O2GramsPerDay, na.rm = TRUE),
        SD_O2 = sd(O2GramsPerDay, na.rm = TRUE),
        Avg_H2 = mean(H2GramsPerDay, na.rm = TRUE),
        SD_H2 = sd(H2GramsPerDay, na.rm = TRUE),
        .groups = "drop"
      )
  })

  # Update choices for selectInput based on available gases
  observe({
    req(rv$tukey_sig_df)
    updateRadioButtons(
      session,
      "selected_gas",
      choices = gsub("GramsPerDay", "", unique(rv$tukey_sig_df$Gas))
    )
  })

  # Render filtered Tukey table
  output$tukey_table <- renderTable({
    req(rv$tukey_sig_df)
    df <- rv$tukey_sig_df

    df$Gas <- gsub("GramsPerDay", "", df$Gas)
    df$p_value <- signif(df$`p adj`, 4)

    df <- df[, c("Gas", "Comparison", "p_value")]
    names(df) <- c("Gas", "Group Comparison", "Adjusted p-value")

    # Filter by selected gas
    req(input$selected_gas)
    df <- df[df$Gas == input$selected_gas, ]
    df
  })

  # Error message display format
  output$error_message_analysis <- renderUI({
    req(rv$error_message_analysis)
    div(
      style = "background-color: #fff6f6; border: 2px solid #e74c3c; color: #c0392b; padding: 15px; margin-bottom: 15px; border-radius: 6px;",
      HTML(rv$error_message_analysis)
    )
  })



}
