#' @title finalrep
#'
#' @description Processing and reporting GreenFeed data - final report
#'
#' @param Exp The study name
#' @param Unit The number of the GreenFeed unit/s
#' @param Start_Date The start date of the study
#' @param End_Date The end date of the study
#' @param Final_report The final report generate by C-Lock at the end of the study
#'
#' @return An excel file with daily data and a PDF report with description of GreenFeed data
#'
#' @examples
#'
#'
#' @export
#' @import readr
#' @import readxl
#' @import dplyr
#' @import lubridate
#' @import rmarkdown


finalrep <- function(Exp = NA, Unit = NA,
                     Start_Date = NA, End_Date = NA, Final_report = NA) {

  #Dependent packages
  library(readr)
  library(readxl)
  library(dplyr)
  library(lubridate)
  library(rmarkdown)

  # Open the final report file and set the name for each column
  df <- read_excel(FinalReport, col_types = c("text", "text", "numeric", rep("date",3), rep("numeric",12), "text", rep("numeric",6)))
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
    dplyr::mutate(GoodDataDuration = round(period_to_seconds(hms(format(as.POSIXct(GoodDataDuration),"%H:%M:%S"))) / 60, 2)) %>%

    # Removing data with Airflow below the threshold (25 l/s)
    dplyr::filter(AirflowLitersPerSec >= 25)

  # Create PDF report using Rmarkdown
  render("~/API_GreenFeed/Reports_FinalGF.Rmd", output_file = paste0("~/Downloads/Report_", Exp))

}
