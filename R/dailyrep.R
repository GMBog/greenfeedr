#' @title dailyrep
#'
#' @description Download, processing, and reporting daily GreenFeed data.
#'
#' @param User The user name to log in to GreenFeed system.
#' @param Pass The password to log in to GreenFeed system.
#' @param Exp Study name.
#' @param Unit The unit number/s of the GreenFeed.
#' @param Start_Date Start date of the study.
#' @param End_Date End date of the study. If not specified, the current date will be used.
#' @param Dir Directory to save the output file. If not specified, the current working directory will be used.
#' @param RFID_file The file that contains the RFID of the animals in the study.
#'
#' @return An Excel file with the GreenFeed daily data and a PDF report with a description of the gas data.
#'
#' @examples
#'
#'
#' @export
#'
#' @import httr
#' @import stringr
#' @import readr
#' @import readxl
#' @import dplyr
#' @import lubridate
#' @import rmarkdown


dailyrep <- function(User = NA, Pass = NA, Exp = NA, Unit = NA,
                     Start_Date = NA, End_Date = Sys.Date(), Dir = getwd(), RFID_file = NA) {


  #Dependent packages
  library(httr)
  library(stringr)
  library(readr)
  library(readxl)
  library(dplyr)
  library(lubridate)
  library(rmarkdown)


  # First Authenticate to receive token:
  req <- POST("https://portal.c-lockinc.com/api/login", body = list(user = User, pass = Pass))
  stop_for_status(req)
  TOK <- trimws(content(req, as = "text"))
  print(TOK)

  # Now get data using the login token
  URL <- paste0(
    "https://portal.c-lockinc.com/api/getemissions?d=visits&fids=", Unit,
    "&st=", Start_Date, "&et=", End_Date, "%2012:00:00"
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

  # Check if the directory exists, if not, create it
  if (!dir.exists(Dir)) {
    dir.create(Dir, recursive = TRUE)
  }

  # Save your data as a datafile
  name_file <- paste0(Dir, "/", Exp, "_GFdata.csv")
  write_excel_csv(df, file = name_file)

  # Read cow's ID table included in the experiment
  if (tolower(tools::file_ext(RFID_file)) == "csv") {
    CowsInExperiment <- read_table(RFID_file, col_types = cols(FarmName = col_character(), EID = col_character()))

  } else if (tolower(tools::file_ext(RFID_file)) %in% c("xls", "xlsx")) {
    CowsInExperiment <- read_excel(RFID_file, col_types = c("text", "text", "numeric", "text"))

  } else {
    stop("Unsupported file format.")
  }

  # Remove leading zeros from RFID column
  df$RFID <- gsub("^0+", "", df$RFID)

  # Summarized data has the gas production data
  df <- df %>%

    # Retained only those cows in the experiment
    dplyr::inner_join(CowsInExperiment, by = c("RFID" = "EID")) %>%
    distinct_at(vars(1:5), .keep_all = TRUE) %>%

    # Change the format of good data duration column: Good Data Duration column to minutes with two decimals
    dplyr::mutate(
      GoodDataDuration = round(period_to_seconds(hms(GoodDataDuration)) / 60, 2),
      HourOfDay = round(period_to_seconds(hms(format(as.POSIXct(StartTime), "%H:%M:%S"))) / 3600, 2)) %>%

    # Removing data with Airflow below the threshold (25 l/s)
    dplyr::filter(AirflowLitersPerSec >= 25)

  # Create the list of animals that will include in the PDF report
  CowsInExperiment <- CowsInExperiment %>%
    dplyr::mutate(
      DIM = DIM + floor(as.numeric(difftime(max(df$StartTime), min(as.Date(df$StartTime)), units = "days") + 1)),
      Data = ifelse(EID %in% df$RFID, "Yes", "No")) %>%
    dplyr::relocate(Data, .after = DIM) %>%
    dplyr::arrange(desc(DIM))

  # Create PDF report using Rmarkdown
  rmarkdown::render(system.file("DailyReportsGF.Rmd", package = "greenfeedR"), output_file = paste0("~/Downloads/Report_", Exp))

}

