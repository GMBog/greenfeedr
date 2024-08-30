#' @name report_gfdata
#' @title Download and Report GreenFeed Data
#'
#' @description `report_gfdata()` generates markdown reports of daily and final GreenFeed data.
#'     If option "daily" is used, data is retrieved from C-Lock server via an application programming interface (API)
#'     and generates a markdown report to with number of animals, records, and gas production of the ongoing study.
#'     But, if option "final" is used, final data should be provided to generates a markdown report
#'     to evaluate all GreenFeed data obtained from the finalized study.
#'
#' @param user User name to log in to the GreenFeed system
#' @param pass Password to log in to the GreenFeed system
#' @param exp Study name or other study identifier. It is used as the file name to report the data
#' @param unit GreenFeed unit number(s). If multiple units, they could be in a vector, list, or character as "1,2"
#' @param start_date Start date of the study
#' @param end_date End date of the study. By default the current date is used
#' @param input_type Input data could be from daily or final report: daily or final
#' @param save_dir Directory to save the output file. By default the current working directory is used
#' @param plot_opt Type of gas to plot: All, or CH4, CO2, O2, H2. By default only CH4 will be processed and reported
#' @param rfid_file File that contains RFID of the animals in the study
#' @param file_path List of files with final report from GreenFeed
#'
#' @return A CSV file with daily GreenFeed data and a PDF report with a description of the daily or final records.
#'
#' @examplesIf has_credentials()
#' # Please replace "your_username" and "your_password" with your actual GreenFeed credentials.
#' user <- Sys.getenv("API_USER")
#' pass <- Sys.getenv("API_PASS")
#'
#' # The data range must be fewer than 180 days
#' # Example without rfid_file (by default NA)
#'
#' report_gfdata(user,
#'   pass,
#'   exp = "StudyName",
#'   unit = 1,
#'   start_date = "2023-01-01",
#'   end_date = Sys.Date(),
#'   input_type = "daily",
#'   save_dir = tempdir(),
#'   plot_opt = "All"
#' )
#'
#' @examples
#' # Create a Final Report in PDF format from the finalized data received from C-Lock Inc.
#' # Note that Unit could be numeric or character (It will use to print in the PDF)
#'
#' # File is a list of reports from C-Lock inc.
#' # it could be one or multiples depend on the number of units
#' file <- list(system.file("extdata", "StudyName_FinalReport.xlsx", package = "greenfeedr"))
#'
#' # By default `report_gfdata()` plot only methane (CH4), but here we defined to plot "All" gases
#'
#' # Is it possible to include a file with Farm IDs to use in the reports
#' # The file structure should be: FarmName | RFID
#'
#' report_gfdata(
#'   user = NA,
#'   pass = NA,
#'   exp = "StudyName",
#'   unit = 1,
#'   start_date = "2024-05-13",
#'   end_date = "2024-05-25",
#'   input_type = "final",
#'   save_dir = tempdir(),
#'   plot_opt = "All",
#'   rfid_file = NA,
#'   file_path = file
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

report_gfdata <- function(user = NA, pass = NA, exp = NA, unit, start_date, end_date = Sys.Date(),
                          input_type, save_dir = getwd(), plot_opt = "CH4", rfid_file = NULL, file_path) {
  # Ensure Unit is a comma-separated string
  if (is.numeric(unit)) {
    ## Convert numeric to character
    unit <- as.character(unit)
  } else if (is.character(unit)) {
    ## If it's already a comma-separated string, keep it as is
    if (grepl(",", unit)) {
      unit <- unit
    } else {
      ## If it's a single string without commas, keep it as is
      unit <- unit
    }
  } else if (is.list(unit) || is.vector(unit)) {
    ## Convert lists or vectors to a single comma-separated string
    unit <- paste(unlist(unit), collapse = ",")
  }

  # Ensure the final output is a single comma-separated string
  unit <- paste(unit, collapse = ",")

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
    print(URL)

    req <- httr::POST(URL, body = list(token = TOK))
    httr::stop_for_status(req)
    a <- httr::content(req, as = "text")
    print(a)

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

    # Save GreenFeed data as a csv file in the specified directory
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

    # Dataframe (df) contains daily GreenFeed data
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

      # df contains finalized GreenFeed data
      df <- df %>%
        ## Remove leading zeros from RFID col to match with IDs
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
