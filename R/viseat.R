#' @title viseat
#'
#' @description Processing feedtimes file with intakes
#'
#' @param Exp The study name
#' @param Unit List of the GreenFeed unit/s
#' @param gcup Grams of pellets per cup
#' @param Start_Date The start date of the study
#' @param End_Date The end date of the study
#' @param RFID_file The file that contains the RFID of the animals in the study
#'
#' @return
#'
#' @examples
#'
#'
#' @export
#'
#' @import readr
#' @import readxl
#' @import data.table
#' @import dplyr
#' @import tidyverse
#' @import lubridate
#' @import reshape2
#' @import plyr


viseat <- function(Exp = NA, Unit = list(NA), gcup = 34,
                   Start_Date = NA, End_Date = NA, RFID_file = NA) {


  # Dependent packages
  library(readr)
  library(readxl)
  library(data.table)
  library(dplyr)
  library(tidyverse)
  library(lubridate)
  library(reshape2)
  library(plyr)


  # Open list of animal IDs in the study
  if (tolower(tools::file_ext(RFID_file)) == "csv") {
    CowsInExperiment <- read_table(RFID_file, col_types = cols(EID = col_character()))
  } else if (tolower(tools::file_ext(RFID_file)) %in% c("xls", "xlsx")) {
    CowsInExperiment <- read_excel(RFID_file)
    CowsInExperiment$EID <- as.character(CowsInExperiment$EID)
  } else {
    stop("Unsupported file format.")
  }

  # Open GreenFeed feedtimes downloaded through C-Lock web interface
  feedtimes_file_paths <- purrr::map_chr(Unit, function(u) {
    file <- paste0(paste("~/Downloads/data", u, Start_Date, End_Date, sep = "_"), "/feedtimes.csv")
    return(file)
  })

  feedtimes <- dplyr::bind_rows(purrr::map2_dfr(feedtimes_file_paths, Unit, ~ readr::read_csv(.x) %>% dplyr::mutate(unit = .y))) %>%
    dplyr::relocate(unit, .before = FeedTime) %>%
    dplyr::mutate(CowTag = gsub("^0+", "", CowTag))


  # Get the animal IDs that were not visiting the GreenFeed during the study
  message("Cows not visiting: ", paste(CowsInExperiment$FarmName[!(CowsInExperiment$EID %in% feedtimes$CowTag)], collapse = ", "))

  # Get the number of drops and visits per day per cow
  daily_visits <- feedtimes %>%
    dplyr::inner_join(CowsInExperiment[,1:2], by = c("CowTag" = "EID")) %>%
    dplyr::mutate(Day = as.character(as.Date(FeedTime)),
                  Time = round(period_to_seconds(hms(format(as.POSIXct(FeedTime), "%H:%M:%S"))) / 3600, 2)) %>%
    dplyr::relocate(Day, Time, FarmName, .after = unit) %>%
    dplyr::select(-FeedTime) %>%

    # Number of drops per cow per day and per unit
    dplyr::group_by(FarmName, Day) %>%
    dplyr::summarise(ndrops = n(),
                     visits = max(CurrentPeriod))

  # Get the number of drops and visits per cow
  visits <- daily_visits %>%
    dplyr::group_by(FarmName) %>%
    dplyr::summarise(total_drops = sum(ndrops),
                     total_visits = sum(visits),
                     mean_drops = round(mean(ndrops),2),
                     mean_visits = round(mean(visits),2))


  return(visits)

}




