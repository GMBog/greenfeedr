#' @name dailyrep
#' @title Download and Report Daily GreenFeed Data
#'
#' @description dailyrep( ) download daily data using API and
#'     generate a PDF report to check correct functionality of GreenFeed unit/s.
#'
#' @param User User name to log in to GreenFeed
#' @param Pass Password to log in to GreenFeed
#' @param Exp Study name
#' @param Unit The unit number(s) of the GreenFeed
#' @param Start_Date Start date of the study
#' @param End_Date End date of the study. If not specified, the current date will be used
#' @param Dir Directory to save the output file. If not specified, the current working directory will be used
#' @param RFID_file The file that contains the RFID of the animals in the study
#' @param Plot_opt Type of gas to plot: All, or CH4, CO2, O2, H2. If not specified, only CH4 will be processed
#'
#' @return A .csv file with daily data from GreenFeed unit(s) and
#'     a PDF report with a description of daily data
#'
#' @examples
#' \dontrun{
#' # Replace "your_username" and "your_password" with actual GreenFeed credentials
#' User <- "your_username"
#' Pass <- "your_password"
#' Exp <- "StudyName"
#' Unit <- 1
#' Start_Date <- "2023-01-01"
#' End_Date <- Sys.Date()
#' Dir <- getwd()
#' RFID_file <- "/Users/RFID_file.csv"
#' Plot_opt <- "All"
#'
#' dailyrep(User, Pass, Exp, Unit, Start_Date, End_Date, Dir, RFID_file, Plot_opt)
#' }
#'
#' @export
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

utils::globalVariables(c("GoodDataDuration", "StartTime", "AirflowLitersPerSec", "DIM", "Data"))

dailyrep <- function(User = NA, Pass = NA, Exp = NA, Unit = NA,
                     Start_Date = NA, End_Date = Sys.Date(),
                     Dir = getwd(), RFID_file = NA, Plot_opt = "CH4") {
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

  # Save GreenFeed data as a csv file in the specified directory
  readr::write_excel_csv(df, file = paste0(Dir, "/", Exp, "_GFdata.csv"))


  # Read file with the RFID (or TagID) in the study
  if (tolower(tools::file_ext(RFID_file)) == "csv") {
    CowsInExperiment <- readr::read_table(RFID_file, col_types = readr::cols(FarmName = readr::col_character(), RFID = readr::col_character()))
  } else if (tolower(tools::file_ext(RFID_file)) %in% c("xls", "xlsx")) {
    CowsInExperiment <- readxl::read_excel(RFID_file, col_types = c("text", "text", "numeric", "text"))
  } else {
    stop("Unsupported file format.")
  }


  # df contains daily GreenFeed data
  df <- df %>%
    # Remove leading zeros from RFID col to match with IDs
    dplyr::mutate(RFID = gsub("^0+", "", RFID)) %>%
    # Retain only those animals that are in the experiment (it will remove unknown ID)
    dplyr::inner_join(CowsInExperiment, by = "RFID") %>%
    dplyr::distinct_at(dplyr::vars(1:5), .keep_all = TRUE) %>%
    # Change columns format
    dplyr::mutate(
      # 'GoodDataDuration' col is the time the visit last and it will be expressed in minutes with two decimals
      GoodDataDuration = round(lubridate::period_to_seconds(lubridate::hms(GoodDataDuration)) / 60, 2),
      # 'HourOfDay' col is a new col that will contains the time of the day in which the visit happened
      HourOfDay = round(lubridate::period_to_seconds(lubridate::hms(format(as.POSIXct(StartTime), "%H:%M:%S"))) / 3600, 2)
    ) %>%
    # Remove data with Airflow below the threshold (25 l/s)
    dplyr::filter(AirflowLitersPerSec >= 25)


  # Create the list of animals that will include in the PDF report
  CowsInExperiment <- CowsInExperiment %>%
    dplyr::mutate(
      # 'DIM' or Days in milk is increasing while the animal is in the study
      DIM = DIM + floor(as.numeric(difftime(max(df$StartTime), min(as.Date(df$StartTime)), units = "days") + 1)),
      # 'Data' col is a binary (YES = animal has records, NO = animal has no records)
      Data = ifelse(RFID %in% df$RFID, "Yes", "No")
    ) %>%
    # Arrange dataset by Days in milk (DIM)
    dplyr::arrange(dplyr::desc(DIM))


  # Create PDF report using Rmarkdown
  rmarkdown::render(
    input = system.file("DailyReportsGF.Rmd", package = "greenfeedr"),
    output_file = file.path(getwd(), paste0("/Report_", Exp, ".pdf"))
  )
}
