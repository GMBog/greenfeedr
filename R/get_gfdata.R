#' @name get_gfdata
#' @title Download Preliminary and Raw 'GreenFeed' Data via 'API'
#'
#' @description Downloads preliminary and raw 'GreenFeed' data from the 'C-Lock Inc.' server via an 'API'.
#'     Retrieves data based on specified parameters (login, date range, and units), and
#'     provides a CSV file with the 'GreenFeed' preliminary data.
#'
#' @param user a character string representing the user name to logging into 'GreenFeed' system
#' @param pass a character string representing password to logging into 'GreenFeed' system
#' @param d a character string representing data to download (opts: "visits", "feed", "rfid", "cmds")
#' @param type a numeric representing the type of data to retrieve (1=finalized and 2=preliminary)
#' @param exp a character string representing study name or other study identifier. It is used as file name to save the data
#' @param unit numeric or character vector, or a list representing one or more 'GreenFeed' unit numbers
#' @param start_date a character string representing the start date of the study (format: "DD-MM-YY" or "YYYY-MM-DD")
#' @param end_date a character string representing the end date of the study (format: "DD-MM-YY" or "YYYY-MM-DD")
#' @param save_dir a character string representing the directory to save the output file
#'
#' @return A CSV file with the specified data (visits or raw) saved in the provided directory.
#'
#' @examplesIf has_credentials()
#' # Please replace "your_username" and "your_password" with your actual 'GreenFeed' credentials.
#' # By default, the function downloads the preliminary 'GreenFeed' data,
#' # if raw data is needed use options: "feed", "rfid", or "cmds"
#'
#' get_gfdata(
#'   user = "your_username",
#'   pass = "your_password",
#'   d = "visits",
#'   type = 2,
#'   exp = "StudyName",
#'   unit = c(304, 305),
#'   start_date = "2024-01-01",
#'   end_date = Sys.Date(),
#'   save_dir = tempdir()
#' )
#'
#' @export get_gfdata
#'
#' @import httr
#' @import readr
#' @import stringr

get_gfdata <- function(user, pass, d = "visits", type = 2, exp = NA, unit,
                       start_date, end_date = Sys.Date(), save_dir = tempdir()) {
  # Ensure unit is a comma-separated string
  unit <- convert_unit(unit,1)

  # Check date format
  start_date <- ensure_date_format(start_date)
  end_date <- ensure_date_format(end_date)

  # Ensure d argument is valid
  valid_inputs <- c("visits", "feed", "rfid", "cmds")
  if (!(d %in% valid_inputs)) {
    stop(paste("Invalid argument. Choose one of:", paste(valid_inputs, collapse = ", ")))
  }

  # Download data (using internal function in 'utils.R')
  df <- download_data(user, pass, d, type, unit, start_date, end_date)

  # Ensure save_dir is an absolute path
  save_dir <- normalizePath(save_dir, mustWork = FALSE)

  # Check if the directory exists, and create it if necessary
  if (!dir.exists(save_dir)) {
    dir.create(save_dir, recursive = TRUE)
  }

  # Save your data as a data file in .csv format
  if (d == "visits") {
    readr::write_excel_csv(df, file = paste0(save_dir, "/", exp, "_GFdata.csv"))
  } else if (d == "feed") {
    readr::write_excel_csv(df, file = paste0(save_dir, "/", exp, "_feedtimes.csv"))
  } else if (d == "rfid") {
    readr::write_excel_csv(df, file = paste0(save_dir, "/", exp, "_rfids.csv"))
  } else if (d == "cmds") {
    readr::write_excel_csv(df, file = paste0(save_dir, "/", exp, "_commands.csv"))
  }

  message("Downloading complete.")
}
