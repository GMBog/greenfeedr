

pellin <- function(experiment_name, start_date, end_date, units, EIDfile) {


  # Dependent packages
  library(readr)
  library(readxl)
  library(data.table)
  library(dplyr)
  library(tidyverse)
  library(lubridate)
  library(reshape2)
  library(plyr)


  # Setting parameters of the GreenFeed unit/s
  list_of_experiments <- list(
    experiment_name = list(
      StartDate = start_date,
      EndDate = end_date,
      Units = units,
      EIDfile = EIDfile
    )
  )

  selected_experiment <- names(list_of_experiments)[1]
  Exp_PERIOD <- paste(list_of_experiments[[selected_experiment]]["StartDate"], list_of_experiments[[selected_experiment]]["EndDate"], sep = "_")
  UNIT <- names(list_of_experiments[[selected_experiment]][["Units"]])

  # Open list of animal IDs in the study
  file_path <- list_of_experiments[[selected_experiment]][["EIDfile"]]
  if (tolower(tools::file_ext(file_path)) == "csv") {
    CowsInExperiment <- read_table(file_path)
  } else if (tolower(tools::file_ext(file_path)) %in% c("xls", "xlsx")) {
    CowsInExperiment <- read_excel(file_path)
    CowsInExperiment$EID <- as.character(CowsInExperiment$EID)
  } else {
    stop("Unsupported file format.")
  }

  # Open GreenFeed feedtimes downloaded through C-Lock web interface
  feedtimes_file_paths <- purrr::map_chr(UNIT, function(u) {
    file <- paste0("~/GreenFeed_UW/Methane/", selected_experiment, "/data_", u, "_", Exp_PERIOD, "/feedtimes.csv")
    return(file)
  })

  feedtimes <- dplyr::bind_rows(purrr::map2_dfr(feedtimes_file_paths, UNIT, ~ readr::read_csv(.x) %>% dplyr::mutate(unit = .y))) %>%
    dplyr::relocate(unit, .before = FeedTime) %>%
    dplyr::mutate(CowTag = gsub("^0+", "", CowTag))

  # Get the animal IDs that were not visiting the GreenFeed during the study
  NOVisitGF <- CowsInExperiment$FarmName[!(CowsInExperiment$EID %in% feedtimes$CowTag)]

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
  grams_df <- data.frame(unit = names(list_of_experiments[[selected_experiment]][["Units"]]),
                         gcup = unlist(list_of_experiments[[selected_experiment]][["Units"]]))

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

  # Define the first and last dates for which you want the intakes
  FirstDate <- list_of_experiments[[selected_experiment]]["StartDate"]
  LastDate <- list_of_experiments[[selected_experiment]]["EndDate"]

  # Create a sequence of dates from FirstDate to LastDate
  all_dates <- seq(as.Date(FirstDate), as.Date(LastDate), by = "day")

  # Create file with AP intakes in kg
  massAP_intakes_sp <- massAP_intakes %>%
    dplyr::filter(Date >= FirstDate & Date <= LastDate) %>%
    dplyr::select(-RFID)

  massAP_intakes_sp$Date <- as.Date(massAP_intakes_sp$Date)

  massAP_intakes_sp <- massAP_intakes_sp %>%
    complete(Date = all_dates, nesting(Farm_name))

  # Add cows without visits to the units
  grid_cows_missing <- expand.grid(
    Date = unique(massAP_intakes_sp$Date),
    Farm_name = CowsInExperiment$FarmName[CowsInExperiment$FarmName %in% NOVisitGF],
    Intake_AP_kg = NA)
  massAP_intakes_sp <- rbind(massAP_intakes_sp, grid_cows_missing)

  # Replace NA for a period (.)
  massAP_intakes_sp$Intake_AP_kg[is.na(massAP_intakes_sp$Intake_AP_kg)] <- "."

  # Export a table with the amount of kg of pellets for a specific period!
  output_file_path <- paste0("~/Downloads/Pellet_Intakes_", FirstDate, "_", LastDate, ".txt")
  write.table(massAP_intakes_sp, file = output_file_path, quote = F, row.names = F)
}



