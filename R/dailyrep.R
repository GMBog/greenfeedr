#' @name dailyrep
#' @title Download and Report Daily GreenFeed Data
#'
#' @description `dailyrep()` downloads daily data using an application programming interface (API)
#'     and generates a PDF report to verify the correct functionality of GreenFeed unit(s).
#'     This function retrieves data based on the specified parameters, processes it,
#'     and outputs a summary report in PDF format. The report includes essential metrics and plots
#'     to ensure that the GreenFeed units are operating as expected.
#'
#' @param user User name to log in to the GreenFeed system
#' @param pass Password to log in to the GreenFeed system
#' @param exp Study name
#' @param unit The unit number(s) of the GreenFeed. If multiple units, they could be in a vector, list, or character as "1,2"
#' @param start_date Start date of the study
#' @param end_date End date of the study. By default the current date is used
#' @param save_dir Directory to save the output file. By default the current working directory is used
#' @param plot_opt Type of gas to plot: All, or CH4, CO2, O2, H2. By default only CH4 will be processed and reported
#' @param RFID_file File that contains RFID of the animals in the study
#'
#' @return A CSV file with daily data from GreenFeed unit(s) and
#'     a PDF report with a description of the daily records
#'
#' @examplesIf has_credentials()
#' # Please replace "your_username" and "your_password" with your actual GreenFeed credentials.
#' user <- Sys.getenv("API_USER")
#' pass <- Sys.getenv("API_PASS")
#' exp <- "StudyName"
#' unit <- 1
#'
#' # The data range must be fewer than 180 days
#' start_date <- "2023-01-01"
#' end_date <- Sys.Date()
#'
#' save_dir <- tempdir()
#' plot_opt <- "All"
#'
#' # Example without RFID_file (by default NA)
#' dailyrep(user, pass, exp, unit = 1, start_date, end_date, save_dir, plot_opt)
#'
#' @export dailyrep
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

dailyrep <- function(user, pass, exp = NA, unit, start_date, end_date = Sys.Date(),
                     save_dir = getwd(), plot_opt = "CH4", RFID_file = NA) {
  # Ensure Unit is a comma-separated string
  if (is.numeric(unit)) {
    # Convert numeric to character
    unit <- as.character(unit)
  } else if (is.character(unit)) {
    # If it's already a comma-separated string, keep it as is
    if (grepl(",", unit)) {
      unit <- unit
    } else {
      # If it's a single string without commas, keep it as is
      unit <- unit
    }
  } else if (is.list(unit) || is.vector(unit)) {
    # Convert lists or vectors to a single comma-separated string
    unit <- paste(unlist(unit), collapse = ",")
  }

  # Ensure the final output is a single comma-separated string
  unit <- paste(unit, collapse = ",")

  # Check Date format
  start_date <- ensure_date_format(start_date)
  end_date <- ensure_date_format(end_date)

  # First Authenticate to receive token:
  req <- httr::POST("https://portal.c-lockinc.com/api/login", body = list(user = user, pass = pass))
  httr::stop_for_status(req)
  TOK <- trimws(httr::content(req, as = "text"))

  # Now get data using the login token
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


  # Read file with the RFID in the study
  if (!is.na(RFID_file)) {
    if (tolower(tools::file_ext(RFID_file)) == "csv") {
      RFID_file <- readr::read_table(RFID_file, col_types = readr::cols(FarmName = readr::col_character(), RFID = readr::col_character()))
    } else if (tolower(tools::file_ext(RFID_file)) %in% c("xls", "xlsx")) {
      RFID_file <- readxl::read_excel(RFID_file, col_types = c("text", "text", "numeric", "text"))
    } else {
      stop("Unsupported file format.")
    }
  }

  # Create a function to conditionally perform inner join
  conditional_inner_join <- function(df, RFID_file) {
    if (nrow(RFID_file) > 0) {
      inner_join(df, RFID_file, by = "RFID")
    } else {
      df
    }
  }

  # df contains daily GreenFeed data
  df <- df %>%
    # Remove "unknown IDs" and leading zeros from RFID col
    dplyr::filter(RFID != "unknown") %>%
    dplyr::mutate(RFID = gsub("^0+", "", RFID)) %>%
    # Conditionally perform the inner_join if RFID_file exists
    conditional_inner_join(RFID_file) %>%
    dplyr::distinct_at(dplyr::vars(1:5), .keep_all = TRUE) %>%
    # Change columns format
    dplyr::mutate(
      # Extract hours, minutes, and seconds from GoodDataDuration
      GoodDataDuration = round(
        as.numeric(substr(GoodDataDuration, 1, 2)) * 60 + # Hours to minutes
          as.numeric(substr(GoodDataDuration, 4, 5)) + # Minutes
          as.numeric(substr(GoodDataDuration, 7, 8)) / 60, # Seconds to minutes
        2
      ),
      # 'HourOfDay' is a new col contains daytime (extract the time part from StartTime (HH:MM:SS))
      HourOfDay = round(
        as.numeric(substr(substr(StartTime, 12, 19), 1, 2)) +
          as.numeric(substr(substr(StartTime, 12, 19), 4, 5)) / 60,
        2
      )
    ) %>%
    # Remove data with Airflow below the threshold (25 l/s)
    dplyr::filter(AirflowLitersPerSec >= 25)


  # If RFID file is provided, process it for the PDF report
  if (nrow(RFID_file) > 0) {
    RFID_file <- RFID_file %>%
      dplyr::mutate(
        # 'Data' col is a binary (YES = animal has records, NO = animal has no records)
        Gas_Data = ifelse(RFID %in% df$RFID, "Yes", "No")
      )
  }

  # Create PDF report using Rmarkdown
  rmarkdown::render(
    input = system.file("DailyReportsGF.Rmd", package = "greenfeedr"),
    output_file = file.path(save_dir, paste0("/DailyReport_", exp, ".pdf"))
  )
}


#' @title Check for API Credentials

#' @description A function to check if the necessary API credentials are available in the environment.

#' @export
has_credentials <- function() {
  !is.na(Sys.getenv("API_USER", unset = NA)) && !is.na(Sys.getenv("API_PASS", unset = NA))
}
