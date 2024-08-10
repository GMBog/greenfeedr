#' @title get_api_data
#' @name get_api_data
#' @description Download daily GreenFeed data.
#'
#' @param User The user name to log in to GreenFeed system.
#' @param Pass The password to log in to GreenFeed system.
#' @param Exp Study name.
#' @param Unit The unit number/s of the GreenFeed.
#' @param Start_Date Start date of the study.
#' @param End_Date End date of the study. If not specified, the current date will be used.
#' @param Dir Directory to save the output file. If not specified, the current working directory will be used.
#'
#' @return An excel file with the daily data from GreenFeed system.
#'
#' @examples
#' \dontrun{
#' # Please replace "your_username" and "your_password" with your actual GreenFeed credentials.
#' User <- "your_username"
#' Pass <- "your_password"
#' Exp <- "Test_study"
#' Unit <- 578
#' Start_Date <- "2023-01-01"
#' End_Date <- Sys.Date()
#' Dir <- getwd()
#'
#' get_api_data(User, Pass, Exp, Unit, Start_Date, End_Date, Dir)
#' }
#'
#' @export get_api_data
#'
#' @import httr
#' @import stringr
#' @import readr


get_api_data <- function(User = NA, Pass = NA, Exp = NA, Unit = NA,
                         Start_Date = NA, End_Date = Sys.Date(), Dir = getwd()) {
  # First Authenticate to receive token:
  req <- httr::POST("https://portal.c-lockinc.com/api/login", body = list(user = User, pass = Pass))
  httr::stop_for_status(req)
  TOK <- trimws(httr::content(req, as = "text"))
  print(TOK)

  # Now get data using the login token
  URL <- paste0(
    "https://portal.c-lockinc.com/api/getemissions?d=visits&fids=", Unit,
    "&st=", Start_Date, "&et=", End_Date, "%2012:00:00"
  )
  print(URL)

  req <- httr::POST(URL, body = list(token = TOK))
  httr::stop_for_status(req)
  a <- httr::content(req, as = "text")
  print(a)

  # Split the lines
  perline <- stringr::str_split(a, "\\n")[[1]]
  print(perline)

  # Split the commas into a dataframe, while getting rid of the "Parameters" line and the headers line
  df <- do.call("rbind", stringr::str_split(perline[3:length(perline)], ","))
  df <- as.data.frame(df)
  colnames(df) <- c(
    "FeederID", "AnimalName", "RFID", "StartTime", "EndTime", "GoodDataDuration",
    "CO2GramsPerDay", "CH4GramsPerDay", "O2GramsPerDay", "H2GramsPerDay", "H2SGramsPerDay",
    "AirflowLitersPerSec", "AirflowCf", "WindSpeedMetersPerSec", "WindDirDeg", "WindCf",
    "WasInterrupted", "InterruptingTags", "TempPipeDegreesCelsius", "IsPreliminary", "RunTime"
  )

  # Check if the directory exists, if not, create it
  if (!dir.exists(Dir)) {
    dir.create(Dir, recursive = TRUE)
  }

  # Save your data as a datafile
  name_file <- paste0(Dir, "/", Exp, "_GFdata.csv")
  readr::write_excel_csv(df, file = name_file)
}
