#' @name get_api_data
#' @title Download daily GreenFeed data using API
#'
#' @description `get_api_data()` downloads daily data from GreenFeed unit(s)
#'     using an application programming interface (API). This function
#'     retrieves data based on specified parameters such as date range and
#'     unit identifiers, providing a structured data output for further analysis
#'     or reporting.
#'
#' @param User User name to log in to GreenFeed
#' @param Pass Password to log in to GreenFeed
#' @param Exp Study name
#' @param Unit The unit number(s) of the GreenFeed. If multiple units, they should be separated by a comma.
#' @param Start_Date Start date of the study
#' @param End_Date End date of the study. If not specified, the current date will be used
#' @param Dir Directory to save the output file. If not specified, the current working directory will be used
#'
#' @return A .csv file with daily data from GreenFeed unit(s)
#'
#' @examplesIf has_credentials()
#' # Please replace "your_username" and "your_password" with your actual GreenFeed credentials.
#' User <- Sys.getenv("API_USER")
#' Pass <- Sys.getenv("API_PASS")
#' Exp <- "StudyName"
#' Unit <- "304,305" # Specify multiple units as a comma-separated string
#' Start_Date <- "2023-01-01"
#' End_Date <- Sys.Date()
#' Dir <- getwd()
#'
#' # Example with multiple units as a comma-separated string
#' get_api_data(User, Pass, Exp, Unit, Start_Date, End_Date, Dir)
#'
#' # Example with a single unit as a numeric value
#' Unit <- 304
#' get_api_data(User, Pass, Exp, Unit, Start_Date, End_Date, Dir)
#'
#' # Example with units as a vector
#' Unit <- c(304, 305)
#' get_api_data(User, Pass, Exp, Unit, Start_Date, End_Date, Dir)
#'
#'
#' @export get_api_data
#'
#' @import httr
#' @import readr
#' @import stringr

get_api_data <- function(User, Pass, Exp, Unit,
                         Start_Date, End_Date = Sys.Date(), Dir = getwd()) {

  # Ensure Unit is a comma-separated string
  if (is.numeric(Unit)) {
    Unit <- as.character(Unit)
  } else if (is.character(Unit)) {
    if (grepl(",", Unit)) {
      Unit <- strsplit(Unit, ",")[[1]]
    }
  } else if (is.list(Unit) || is.vector(Unit)) {
    Unit <- paste(Unit, collapse = ",")
  }

  Unit <- as.character(Unit)

  # First Authenticate to receive token:
  req <- httr::POST("https://portal.c-lockinc.com/api/login", body = list(user = User, pass = Pass))
  httr::stop_for_status(req)
  TOK <- trimws(httr::content(req, as = "text"))

  # Now get data using the login token
  URL <- paste0(
    "https://portal.c-lockinc.com/api/getemissions?d=visits&fids=", Unit,
    "&st=", Start_Date, "&et=", End_Date, "%2012:00:00"
  )
  print(URL)

  req <- httr::POST(URL, body = list(token = TOK))
  httr::stop_for_status(req)
  a <- httr::content(req, as = "text")

  # Split the lines
  perline <- stringr::str_split(a, "\\n")[[1]]

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

  # Save your data as a datafile in csv format
  name_file <- paste0(Dir, "/", Exp, "_GFdata.csv")
  readr::write_excel_csv(df, file = name_file)
}



#' @title Check for API Credentials

#' @description A function to check if the necessary API credentials are available in the environment.

#' @export
has_credentials <- function() {
  !is.na(Sys.getenv("API_USER", unset = NA)) && !is.na(Sys.getenv("API_PASS", unset = NA))
}
