#' @name dailyrep
#' @title Download and Report Daily GreenFeed Data
#'
#' @description `dailyrep()` downloads daily data using an application programming interface (API)
#'     and generates a PDF report to verify the correct functionality of GreenFeed unit(s).
#'     This function retrieves data based on the specified parameters, processes it,
#'     and outputs a summary report in PDF format. The report includes essential metrics and plots
#'     to ensure that the GreenFeed units are operating as expected.
#'
#' @param User User name to log in to GreenFeed
#' @param Pass Password to log in to GreenFeed
#' @param Exp Study name
#' @param Unit The unit number(s) of the GreenFeed. If multiple units, they should be separated by a comma
#' @param Start_Date Start date of the study
#' @param End_Date End date of the study. If not specified, the current date will be used
#' @param Dir Directory to save the output file. If not specified, the current working directory will be used
#' @param Plot_opt Type of gas to plot: All, or CH4, CO2, O2, H2. If not specified, only CH4 will be processed
#' @param RFID_file The file that contains the RFID of the animals in the study
#'
#' @return A .csv file with daily data from GreenFeed unit(s) and
#'     a PDF report with a description of daily data
#'
#' @examplesIf has_credentials()
#' # Please replace "your_username" and "your_password" with your actual GreenFeed credentials.
#' User <- Sys.getenv("API_USER")
#' Pass <- Sys.getenv("API_PASS")
#' Exp <- "StudyName"
#' Unit <- 1
#'
#' # The data range must be fewer than 180 days
#' Start_Date <- "2023-01-01"
#' End_Date <- Sys.Date()
#'
#' Dir <- getwd()
#' Plot_opt <- "All"
#'
#' # Example without RFID_file (by default NA)
#' dailyrep(User, Pass, Exp, Unit = 1, Start_Date, End_Date, Dir, Plot_opt)
#'
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

utils::globalVariables(c("GoodDataDuration", "StartTime", "AirflowLitersPerSec", "DIM", "Data"))

dailyrep <- function(User, Pass, Exp, Unit, Start_Date, End_Date = Sys.Date(),
                     Dir = getwd(), Plot_opt = "CH4", RFID_file = NA) {




  # Ensure Unit is a comma-separated string
  if (is.numeric(Unit)) {
    # Convert numeric to character
    Unit <- as.character(Unit)
  } else if (is.character(Unit)) {
    # If it's already a comma-separated string, keep it as is
    if (grepl(",", Unit)) {
      Unit <- Unit
    } else {
      # If it's a single string without commas, keep it as is
      Unit <- Unit
    }
  } else if (is.list(Unit) || is.vector(Unit)) {
    # Convert lists or vectors to a single comma-separated string
    Unit <- paste(unlist(Unit), collapse = ",")
  }

  # Ensure the final output is a single comma-separated string
  Unit <- paste(Unit, collapse = ",")

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
  if (!dir.exists(Dir)) {
    dir.create(Dir, recursive = TRUE)
  }

  # Save GreenFeed data as a csv file in the specified directory
  readr::write_excel_csv(df, file = paste0(Dir, "/", Exp, "_GFdata.csv"))


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
        as.numeric(substr(GoodDataDuration, 1, 2)) * 60 +  # Hours to minutes
          as.numeric(substr(GoodDataDuration, 4, 5)) +      # Minutes
          as.numeric(substr(GoodDataDuration, 7, 8)) / 60,  # Seconds to minutes
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
    output_file = file.path(getwd(), paste0("/DailyReport_", Exp, ".pdf"))
  )
}


#' @title Check for API Credentials

#' @description A function to check if the necessary API credentials are available in the environment.

#' @export
has_credentials <- function() {
  !is.na(Sys.getenv("API_USER", unset = NA)) && !is.na(Sys.getenv("API_PASS", unset = NA))
}
