#' @title finalrep
#' @name finalrep
#' @description Processing and reporting GreenFeed data - final report
#'
#' @param Exp Study name.
#' @param Unit The unit number/s of the GreenFeed.
#' @param Start_Date Start date of the study.
#' @param End_Date End date of the study.
#' @param Final_report Final report generate by C-Lock.
#'
#' @return An excel file with daily data and a PDF report with description of methane data.
#'
#' @examples
#' \dontrun{
#' Exp <- "Test_study"
#' Unit <- "577,578"
#' Start_Date <- "2023-01-01"
#' End_Date <- "2023-04-01"
#'
#' Please replace with the final report from C-Lock with the finalized GreenFeed data
#' Final_report = "/Users/CLock_finalreport.xlsx"
#'
#' finalrep(Exp, Unit, Start_Date, End_Date, Final_report)
#'
#' }
#'
#' @export finalrep
#'
#' @import readr
#' @import readxl
#' @import dplyr
#' @importFrom dplyr %>%
#' @import lubridate
#' @import rmarkdown
#' @import utils

utils::globalVariables(c("GoodDataDuration", "AirflowLitersPerSec"))

finalrep <- function(Exp = NA, Unit = NA, Start_Date = NA, End_Date = NA, Final_report = NA) {

  # Open the final report file and set the name for each column
  df <- readxl::read_excel(Final_report, col_types = c("text", "text", "numeric", rep("date",3), rep("numeric",12), "text", rep("numeric",6)))
  names(df)[1:14] <- c("RFID",
                       "FarmName",
                       "FeederID",
                       "StartTime",
                       "EndTime",
                       "GoodDataDuration",
                       "HourOfDay",
                       "CO2GramsPerDay",
                       "CH4GramsPerDay",
                       "O2GramsPerDay",
                       "H2GramsPerDay",
                       "H2SGramsPerDay",
                       "AirflowLitersPerSec",
                       "AirflowCf")

  # Remove leading zeros from RFID column
  df$RFID <- gsub("^0+", "", df$RFID)


  # Summarized data has the gas production data for a long period of time, so you should select the specific period of your experiment
  df <- df %>%

    # Change the format of good data duration column: Good Data Duration column to minutes with two decimals
    dplyr::mutate(GoodDataDuration = round(lubridate::period_to_seconds(lubridate::hms(format(as.POSIXct(GoodDataDuration),"%H:%M:%S"))) / 60, 2)) %>%

    # Removing data with Airflow below the threshold (25 l/s)
    dplyr::filter(AirflowLitersPerSec >= 25)


  # Create PDF report using Rmarkdown
  rmarkdown::render(system.file("FinalReportsGF.Rmd", package = "greenfeedR"), output_file = file.path(getwd(), paste0("/Report_", Exp, ".pdf")))

}
