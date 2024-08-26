#' @name get_gfdata
#' @title Download Daily GreenFeed Data via API
#'
#' @description `get_gfdata()` downloads from C-Lock server daily GreenFeed data
#'     via an application programming interface (API). This function
#'     retrieves data based on specified parameters such as login information,
#'     date range and units, providing an Excel file with GreenFeed data.
#'
#' @param user User name to log in to the GreenFeed system
#' @param pass Password to log in to the GreenFeed system
#' @param exp Study name or other study identifier. It is used as the file name to save the data
#' @param unit GreenFeed unit number(s). If multiple units, they could be in a vector, list, or character as "1,2"
#' @param start_date Start date of the study
#' @param end_date End date of the study. By default the current date is used
#' @param save_dir Directory to save the output file. By default the current working directory is used
#'
#' @return An Excel file with daily data from GreenFeed unit(s)
#'
#' @examplesIf has_credentials()
#' # Please replace "your_username" and "your_password" with your actual GreenFeed credentials.
#' user <- Sys.getenv("API_USER")
#' pass <- Sys.getenv("API_PASS")
#' exp <- "StudyName"
#' start_date <- "2023-01-01"
#' end_date <- Sys.Date()
#' save_dir <- tempdir()
#'
#' # Example with multiple units as a comma-separated string
#' unit <- "304,305"
#' get_gfdata(user, pass, exp, unit, start_date, end_date, save_dir)
#'
#' # Example with a single unit as a numeric value
#' unit <- 304
#' get_gfdata(user, pass, exp, unit, start_date, end_date, save_dir)
#'
#' # Example with units as a vector
#' unit <- c(304, 305)
#' get_gfdata(user, pass, exp, unit, start_date, end_date, save_dir)
#'
#' @export get_gfdata
#'
#' @import httr
#' @import readr
#' @import stringr

get_gfdata <- function(user, pass, exp = NA , unit,
                       start_date, end_date = Sys.Date(), save_dir = getwd()) {
  # Ensure unit is a comma-separated string
  if (is.numeric(unit)) {
    unit <- as.character(unit)
  } else if (is.character(unit)) {
    if (grepl(",", unit)) {
      unit <- strsplit(unit, ",")[[1]]
    }
  } else if (is.list(unit) || is.vector(unit)) {
    unit <- paste(unit, collapse = ",")
  }
  # Check the format of unit because it will use in the URL
  unit <- as.character(unit)

  # Check date format
  start_date <- ensure_date_format(start_date)
  end_date <- ensure_date_format(end_date)

  # Authenticate to receive token
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

  # Split the lines
  perline <- stringr::str_split(a, "\\n")[[1]]

  # Split the commas into a data frame, while getting rid of the "Parameters" line and the headers line
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

  # Save your data as a data file in .csv format
  readr::write_excel_csv(df, file = paste0(save_dir, "/", exp, "_GFdata.csv"))
}
