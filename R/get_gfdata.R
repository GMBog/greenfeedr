#' @name get_gfdata
#' @title Download Preliminary 'GreenFeed' Data via 'API'
#'
#' @description Downloads preliminary 'GreenFeed' data from the 'C-Lock Inc.' server via an 'API'.
#'     Retrieves data based on specified parameters (login, date range, and units), and
#'     provides a CSV file with the 'GreenFeed' preliminary data.
#'
#' @param user a character string representing the user name to logging into 'GreenFeed' system
#' @param pass a character string representing password to logging into 'GreenFeed' system
#' @param exp a character string representing study name or other study identifier. It is used as file name to save the data
#' @param unit numeric or character vector, or a list representing one or more 'GreenFeed' unit numbers
#' @param start_date a character string representing the start date of the study (format: "mm/dd/yyyy")
#' @param end_date a character string representing the end date of the study (format: "mm/dd/yyyy")
#' @param save_dir a character string representing the directory to save the output file
#'
#' @return A CSV file with preliminary 'GreenFeed' data in the specified directory
#'
#' @examplesIf has_credentials()
#' # Please replace "your_username" and "your_password" with your actual 'GreenFeed' credentials.
#' # Example with units as a vector
#'
#' get_gfdata(
#'    user = "your_username",
#'    pass = "your_password",
#'    exp = "StudyName",
#'    unit = c(304, 305),
#'    start_date = "2024-01-01",
#'    end_date = Sys.Date(),
#'    save_dir = tempdir()
#'    )
#'
#' @export get_gfdata
#'
#' @import httr
#' @import readr
#' @import stringr

get_gfdata <- function(user, pass, exp = NA, unit,
                       start_date, end_date = Sys.Date(), save_dir = tempdir()) {
  # Ensure unit is a comma-separated string
  unit <- convert_unit(unit)

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
  message(URL)

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

  message("Downloading complete.")
}
