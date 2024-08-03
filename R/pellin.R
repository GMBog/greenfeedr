#' @title pellin
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


pellin <- function(Exp = NA, Unit = list(NA), gcup = 34,
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
  noGFvisits <- CowsInExperiment$FarmName[!(CowsInExperiment$EID %in% feedtimes$CowTag)]

  # Adding to the table the visit day and daytime visit
  number_drops <- feedtimes %>%
    dplyr::filter(CowTag %in% CowsInExperiment$EID) %>%
    dplyr::mutate(Day = as.character(as.Date(FeedTime)),
                  Time = round(period_to_seconds(hms(format(as.POSIXct(FeedTime), "%H:%M:%S"))) / 3600, 2)) %>%
    dplyr::relocate(Day, Time, .before = unit) %>%
    dplyr::select(-FeedTime) %>%

    # Number of drops per cow per day and per unit
    dplyr::group_by(CowTag, unit, Day) %>%
    dplyr::summarise(ndrops = n(),
                     TotalPeriod = max(CurrentPeriod))

  # Calculating the mass food per drop in different units
  grams_df <- data.frame(unit = unlist(Unit), gcup = gcup)

  # Join the grams_per_cup dataframe with number_drops and calculate MassFoodDrop
  massAP_intakes <- number_drops %>%
    dplyr::left_join(grams_df, by = "unit") %>%
    dplyr::mutate(MassFoodDrop = ndrops * gcup) %>%

    # Create a table with alfalfa pellets (AP) intakes in kg
    dplyr::group_by(CowTag, Day) %>%
    dplyr::summarise(MassFoodDrop = sum(MassFoodDrop) / 1000) # Divided by 1000 to transform mass in kg

  # Create a grid of all unique combinations of visit_day and CowTag
  grid <- expand.grid(Day = unique(massAP_intakes$Day), CowTag = unique(massAP_intakes$CowTag))
  massAP_intakes <- merge(massAP_intakes, grid, all = TRUE, fill = list(MassFoodDrop = 0))

  # Adding the Farm name to the AP intakes
  massAP_intakes <- CowsInExperiment[,1:2] %>%
    inner_join(massAP_intakes, by = c("EID" = "CowTag"))
  names(massAP_intakes) <- c("Farm_name", "RFID", "Date", "Intake_AP_kg")


  # Create a sequence of dates from Start_Date to End_Date
  all_dates <- seq(as.Date(Start_Date), as.Date(End_Date), by = "day")

  # Create file with AP intakes in kg
  massAP_intakes_sp <- massAP_intakes %>%
    dplyr::filter(Date >= Start_Date & Date <= End_Date) %>%
    dplyr::select(-RFID)

  massAP_intakes_sp$Date <- as.Date(massAP_intakes_sp$Date)

  massAP_intakes_sp <- massAP_intakes_sp %>% tidyr::complete(Date = all_dates, nesting(Farm_name))

  # Add cows without visits to the units
  grid_cows_missing <- expand.grid(
    Date = unique(massAP_intakes_sp$Date),
    Farm_name = CowsInExperiment$FarmName[CowsInExperiment$FarmName %in% noGFvisits],
    Intake_AP_kg = NA)
  massAP_intakes_sp <- rbind(massAP_intakes_sp, grid_cows_missing)

  # Replace NA for a period (.)
  massAP_intakes_sp$Intake_AP_kg[is.na(massAP_intakes_sp$Intake_AP_kg)] <- "."

  # Export a table with the amount of kg of pellets for a specific period!
  output_file_path <- paste0("~/Downloads/Pellet_Intakes_", Start_Date, "_", End_Date, ".txt")
  write.table(massAP_intakes_sp, file = output_file_path, quote = F, row.names = F)

}



