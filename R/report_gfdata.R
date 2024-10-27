#' @name report_gfdata
#' @title Download and Report 'GreenFeed' Data
#'
#' @description Generates a PDF report of daily and finalized 'GreenFeed' data.
#'     The report includes: number of animals using 'GreenFeed' and plots with distribution of records and gas production.
#'     If the daily option is used, the data is retrieved from the 'C-Lock Inc.' server through an 'API',
#'     otherwise the data processed by 'C-Lock Inc.' must be provided to generate the report.
#'
#' @param input_type a character string representing type of data (options: "daily" and "final")
#' @param exp a character string representing study name or other study identifier. It is used as file name to save the data
#' @param unit numeric or character vector, or a list representing one or more 'GreenFeed' unit numbers
#' @param start_date a character string representing the start date of the study (format: "mm/dd/yyyy")
#' @param end_date a character string representing the end date of the study (format: "mm/dd/yyyy")
#' @param save_dir a character string representing the directory to save the output file
#' @param plot_opt a character string representing the gas(es) to plot (options: "All", "CH4", "CO2", "O2", "H2")
#' @param rfid_file a character string representing the file with individual IDs. The order should be Visual ID (col1) and RFID (col2)
#' @param user a character string representing the user name to logging into 'GreenFeed' system. If input_type is "final", this parameter is ignored
#' @param pass a character string representing password to logging into 'GreenFeed' system. If input_type is "final", this parameter is ignored
#' @param file_path A list of file paths containing the final report(s) from the 'GreenFeed' system. If input_type is "final", this parameter is ignored
#'
#' @return A CSV file with daily 'GreenFeed' data and a PDF report with a description of the daily or finalized data
#'
#' @examplesIf has_credentials()
#' # Please replace "your_username" and "your_password" with your actual 'GreenFeed' credentials.
#' user <- Sys.getenv("API_USER")
#' pass <- Sys.getenv("API_PASS")
#'
#' # The data range must be fewer than 180 days
#' # Example without rfid_file (by default NA)
#'
#' report_gfdata(
#'   input_type = "daily",
#'   exp = "StudyName",
#'   unit = 1,
#'   start_date = "2023-01-01",
#'   end_date = Sys.Date(),
#'   save_dir = tempdir(),
#'   plot_opt = "All"
#' )
#'
#' @export report_gfdata
#'
#' @import dplyr
#' @importFrom dplyr %>%
#' @import httr
#' @import lubridate
#' @import readr
#' @import readxl
#' @import rmarkdown
#' @import stringr
#' @import utils

utils::globalVariables(c("GoodDataDuration", "StartTime", "AirflowLitersPerSec", "Gas_Data"))

report_gfdata <- function(input_type, exp = NA, unit, start_date, end_date = Sys.Date(),
                          save_dir = tempdir(), plot_opt = "CH4", rfid_file = NULL,
                          user = NA, pass = NA, file_path) {
  # Ensure unit is a comma-separated string
  unit <- convert_unit(unit)

  # Check Date format
  start_date <- ensure_date_format(start_date)
  end_date <- ensure_date_format(end_date)

  # Convert input_type to lowercase to ensure case-insensitivity
  input_type <- tolower(input_type)

  # Ensure input_type is valid
  valid_inputs <- c("final", "daily")
  if (!(input_type %in% valid_inputs)) {
    stop(paste("Invalid input_type. Choose one of:", paste(valid_inputs, collapse = ", ")))
  }


  if (input_type == "daily") {
    # First Authenticate to receive token:
    req <- httr::POST("https://portal.c-lockinc.com/api/login", body = list(user = user, pass = pass))
    httr::stop_for_status(req)
    TOK <- trimws(httr::content(req, as = "text"))

    # Get data using the login token
    URL <- paste0(
      "https://portal.c-lockinc.com/api/getemissions?d=visits&fids=", unit,
      "&st=", start_date, "&et=", end_date, "%2012:00:00"
    )
    message(URL)

    req <- httr::POST(URL, body = list(token = TOK))
    httr::stop_for_status(req)
    a <- httr::content(req, as = "text")
    message(a)

    # Split the lines
    perline <- stringr::str_split(a, "\\n")[[1]]

    # Split the commas into a dataframe, while getting rid of the "Parameters" line and the headers line
    df <- do.call("rbind", stringr::str_split(perline[3:length(perline)], ","))
    df <- as.data.frame(df)
    colnames(df) <- c(
      "FeederID",
      "AnimalName",
      "RFID",
      "StartTime",
      "EndTime",
      "GoodDataDuration",
      "CO2GramsPerDay",
      "CH4GramsPerDay",
      "O2GramsPerDay",
      "H2GramsPerDay",
      "H2SGramsPerDay",
      "AirflowLitersPerSec",
      "AirflowCf",
      "WindSpeedMetersPerSec",
      "WindDirDeg",
      "WindCf",
      "WasInterrupted",
      "InterruptingTags",
      "TempPipeDegreesCelsius",
      "IsPreliminary",
      "RunTime"
    )

    # Check if the directory exists, if not, create it
    if (!dir.exists(save_dir)) {
      dir.create(save_dir, recursive = TRUE)
    }

    # Save 'GreenFeed' data as a csv file in the specified directory
    readr::write_excel_csv(df, file = paste0(save_dir, "/", exp, "_GFdata.csv"))


    # Process the rfid data
    rfid_file <- process_rfid_data(rfid_file)

    # Create a function to conditionally perform inner join
    conditional_inner_join <- function(df, rfid_file) {
      if (!is.null(rfid_file) && nrow(rfid_file) > 0) {
        inner_join(df, rfid_file, by = "RFID")
      } else {
        df
      }
    }

    # Dataframe (df) contains daily 'GreenFeed' data
    df <- df %>%
      ## Remove "unknown IDs" and leading zeros from RFID col
      dplyr::filter(RFID != "unknown") %>%
      dplyr::mutate(RFID = gsub("^0+", "", RFID)) %>%
      ## Conditionally perform the inner_join if rfid_file exists
      conditional_inner_join(rfid_file) %>%
      dplyr::distinct_at(dplyr::vars(1:5), .keep_all = TRUE) %>%
      ## Change columns format
      dplyr::mutate(
        ## Extract hours, minutes, and seconds from GoodDataDuration
        GoodDataDuration = round(
          as.numeric(substr(GoodDataDuration, 1, 2)) * 60 + # Hours to minutes
            as.numeric(substr(GoodDataDuration, 4, 5)) + # Minutes
            as.numeric(substr(GoodDataDuration, 7, 8)) / 60, # Seconds to minutes
          2
        ),
        ## 'HourOfDay' is a new col contains daytime (extract the time part from StartTime (HH:MM:SS))
        HourOfDay = round(
          as.numeric(substr(substr(StartTime, 12, 19), 1, 2)) +
            as.numeric(substr(substr(StartTime, 12, 19), 4, 5)) / 60,
          2
        )
      ) %>%
      ## Remove data with Airflow below the threshold (25 l/s)
      dplyr::filter(AirflowLitersPerSec >= 25)


    # If rfid file is provided, process it for the PDF report
    if (!is.null(rfid_file) && nrow(rfid_file) > 0) {
      rfid_file <- rfid_file %>%
        dplyr::mutate(
          ## 'Data' col is a binary (YES = animal has records, NO = animal has no records)
          Gas_Data = ifelse(RFID %in% df$RFID, "Yes", "No")
        )
    }

    # Create PDF report using Rmarkdown
    rmarkdown::render(
      input = system.file("DailyReportsGF.Rmd", package = "greenfeedr"),
      output_file = file.path(save_dir, paste0("/DailyReport_", exp, ".pdf"))
    )
  } else {
    # Function to read and process each file
    process_file <- function(file_path) {
      df <- readxl::read_excel(file_path, col_types = c("text", "text", "numeric", rep("date", 3), rep("numeric", 12), "text", rep("numeric", 6)))
      names(df)[1:14] <- c(
        "RFID",
        "AnimalName",
        "FeederID",
        "StartTime",
        "EndTime",
        "GoodDataDuration",
        "HourOfDay",
        "CO2GramsPerDay",
        "CH4GramsPerDay",
        "O2GramsPerDay",
        "H2GramsPerDay",
        "H2SGramsPerDay",
        "AirflowLitersPerSec",
        "AirflowCf"
      )

      # df contains finalized 'GreenFeed' data
      df <- df %>%
        ## Remove "unknown IDs" and leading zeros from RFID col
        dplyr::filter(RFID != "unknown") %>%
        dplyr::mutate(
          RFID = gsub("^0+", "", RFID),
          ## Extract hours, minutes, and seconds from GoodDataDuration
          GoodDataDuration = round(
            as.numeric(substr(GoodDataDuration, 12, 13)) * 60 + # Hours to minutes
              # as.numeric(substr(GoodDataDuration, 1, 2)) * 60 +  # Hours to minutes
              as.numeric(substr(GoodDataDuration, 15, 16)) + # Minutes
              # as.numeric(substr(GoodDataDuration, 4, 5)) +
              as.numeric(substr(GoodDataDuration, 18, 19)) / 60, # Seconds to minutes
            # as.numeric(substr(GoodDataDuration, 7, 8)) / 60,
            2
          )
        ) %>%
        ## Remove data with Airflow below the threshold (25 l/s) and data in the time range selected
        dplyr::filter(
          AirflowLitersPerSec >= 25,
          as.Date(StartTime) >= as.Date(start_date) & as.Date(StartTime) <= as.Date(end_date)
        )

      return(df)
    }

    # Combine all final report files into one data frame
    df <- do.call(rbind, lapply(file_path, process_file))

    # Process the rfid data
    rfid_file <- process_rfid_data(rfid_file)

    # If rfid file is provided then perform inner join
    if (!is.null(rfid_file) && is.data.frame(rfid_file) && nrow(rfid_file) > 0) {
      df <- dplyr::inner_join(df, rfid_file, by = "RFID")
    }

    # Create PDF report using Rmarkdown
    rmarkdown::render(
      input = system.file("FinalReportsGF.Rmd", package = "greenfeedr"),
      output_file = file.path(save_dir, paste0("FinalReport_", exp, ".pdf"))
    )
  }

  message("Report created and saved to ", save_dir)
}
