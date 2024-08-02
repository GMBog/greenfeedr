#' @title get_api_data
#'
#' @description Download daily GreenFeed data
#'
#' @param User The user name to log in to GreenFeed system
#' @param Pass The password to log in to GreenFeed system
#' @param Output_dir The directory to save the generated file
#'
#' @return An excel file with the daily data from GreenFeed system
#'
#' @examples
#'
#'
#' @export
#' @import httr
#' @import stringr
#' @import readr


get_api_data <- function(User = NA, Pass = NA, Output_dir = NA) {


  #Dependent packages
  library(httr)
  library(stringr)
  library(readr)


  # First Authenticate to receive token:
  req <- POST("https://portal.c-lockinc.com/api/login", body = list(user = User, pass = Pass))
  stop_for_status(req)
  TOK <- trimws(content(req, as = "text"))
  print(TOK)

  # Now get data using the login token
  URL <- paste0(
    "https://portal.c-lockinc.com/api/getemissions?d=visits&fids=", Unit,
    "&st=", Start_Date, "&et=", Sys.Date(), "%2012:00:00"
  )
  print(URL)

  req <- POST(URL, body = list(token = TOK))
  stop_for_status(req)
  a <- content(req, as = "text")
  print(a)

  # Split the lines
  perline <- str_split(a, "\\n")[[1]]
  print(perline)

  # Split the commas into a dataframe, while getting rid of the "Parameters" line and the headers line
  df <- do.call("rbind", str_split(perline[3:length(perline)], ","))
  df <- as.data.frame(df)
  colnames(df) <- c(
    'FeederID', 'AnimalName', 'RFID', 'StartTime', 'EndTime', 'GoodDataDuration',
    'CO2GramsPerDay', 'CH4GramsPerDay', 'O2GramsPerDay', 'H2GramsPerDay', 'H2SGramsPerDay',
    'AirflowLitersPerSec', 'AirflowCf', 'WindSpeedMetersPerSec', 'WindDirDeg', 'WindCf',
    'WasInterrupted', 'InterruptingTags', 'TempPipeDegreesCelsius', 'IsPreliminary', 'RunTime'
  )

  # Save your data as a datafile
  name_file <- paste0(Output_dir, "GFdata.csv")
  write_excel_csv(df, file = name_file)

}

