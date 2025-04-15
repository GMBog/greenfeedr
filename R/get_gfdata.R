#' @name get_gfdata
#' @title Download Preliminary and Raw 'GreenFeed' Data via 'API'
#'
#' @description Downloads preliminary and raw 'GreenFeed' data from the 'C-Lock Inc.' server via an 'API'.
#'     Retrieves data based on specified parameters (login, date range, and units), and
#'     provides a CSV file with the 'GreenFeed' preliminary data.
#'
#' @param user a character string representing the user name to logging into 'GreenFeed' system
#' @param pass a character string representing password to logging into 'GreenFeed' system
#' @param d a character string representing data type to download (opts: "visits", "feed", "rfid", "cmds")
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

  # Authenticate to receive token
  req <- httr::POST("https://portal.c-lockinc.com/api/login", body = list(user = user, pass = pass))
  httr::stop_for_status(req)
  TOK <- trimws(httr::content(req, as = "text"))

  # Internal function to download and parse
  download_and_parse <- function(type) {
    if (d == "visits") {
      URL <- paste0(
        "https://portal.c-lockinc.com/api/getemissions?d=", d, "&fids=", unit,
        "&st=", start_date, "&et=", end_date, "%2012:00:00&type=", type
      )
    } else {
      URL <- paste0(
        "https://portal.c-lockinc.com/api/getraw?d=", d, "&fids=", unit,
        "&st=", start_date, "&et=", end_date, "%2012:00:00"
      )
    }
    message(URL)

    req <- httr::POST(URL, body = list(token = TOK))
    httr::stop_for_status(req)
    a <- httr::content(req, as = "text")
    perline <- stringr::str_split(a, "\\n")[[1]]
    df <- do.call("rbind", stringr::str_split(perline[3:length(perline)], ","))
    df <- as.data.frame(df)
    return(df)
  }

  # Try first with selected type
  df <- tryCatch({
    df <- download_and_parse(type)
    if (nrow(df) <= 1 && d == "visits" && type == 1) {
      message("No finalized data. Trying preliminary data (type = 2)...")
      df <- download_and_parse(2)
    }
    df
  }, error = function(e) {
    message("Download failed: ", e$message)
    return(NULL)
  })

  if (is.null(df) || nrow(df) <= 1) {
    message("No valid data retrieved.")
    return(invisible(NULL))
  }


  if (d == "visits") {
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
  } else if (d == "feed") {
    colnames(df) <- c(
      "FID",
      "FeedTime",
      "CowTag",
      "CurrentCup",
      "MaxCups",
      "CurrentPeriod",
      "MaxPeriods",
      "CupDelay",
      "PeriodDelay",
      "FoodType"
    )
  } else if (d == "rfid") {
    colnames(df) <- c(
      "FID",
      "ScanTime",
      "CowTag",
      "InOrOut",
      "Tray(IfApplicable)"
    )
  } else if (d == "cmds") {
    colnames(df) <- c(
      "FID",
      "CommandTime",
      "Cmd"
    )
  }

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
