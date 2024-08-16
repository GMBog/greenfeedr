#' @name pellin
#' @title Process Pellet Intakes
#'
#' @description `pellin()` processes the feedtimes file, including visits and food drops,
#'     to calculate pellet intakes per animal for the entire requested period.
#'     This function aggregates data to provide insights into the feeding behavior
#'     and pellet consumption of the animals during a study.
#'
#' @param Exp Study name
#' @param Unit List of the unit number(s) of the GreenFeed
#' @param gcup Grams of pellets per cup
#' @param Start_Date Start date of the study
#' @param End_Date End date of the study
#' @param RFID_file The file that contains the RFID of the animals enrolled in the study
#'
#' @return An Excel file with pellet intakes for all animals in the study
#'
#' @examples
#' \dontrun{
#' Exp <- "StudyName"
#' Unit <- list(1, 2)
#' # Please replace here with the grams of pellet that fit in one cup (10 drop-test)
#' gcup <- 34
#' Start_Date <- "2023-01-01"
#' End_Date <- "2023-04-01"
#' RFID_file <- "/Users/RFID_file.csv"
#'
#' pellin(Exp, Unit, gcup, Start_Date, End_Date, RFID_file)
#' }
#'
#' @export pellin
#'
#' @import dplyr
#' @importFrom dplyr %>%
#' @import lubridate
#' @import purrr
#' @import readr
#' @import readxl
#' @import tidyr
#' @import utils

utils::globalVariables(c(
  "unit", "FeedTime", "CowTag", "Day", "Time", "CurrentPeriod", "ndrops",
  "MassFoodDrop", "Date", "RFID", "massAP_intakes_sp", "Farm_name"
))

pellin <- function(Exp = NA, Unit = list(NA), gcup = 34,
                   Start_Date = NA, End_Date = NA, RFID_file = NA) {
  # Open list of animal IDs in the study
  if (tolower(tools::file_ext(RFID_file)) == "csv") {
    CowsInExperiment <- readr::read_table(RFID_file, col_types = readr::cols(RFID = readr::col_character()))
  } else if (tolower(tools::file_ext(RFID_file)) %in% c("xls", "xlsx")) {
    CowsInExperiment <- readxl::read_excel(RFID_file)
    CowsInExperiment$RFID <- as.character(CowsInExperiment$RFID)
  } else {
    stop("Unsupported file format.")
  }

  # Open GreenFeed feedtimes downloaded through C-Lock web interface
  feedtimes_file_paths <- purrr::map_chr(Unit, function(u) {
    # Construct the file path
    file <- paste0(getwd(), "/data_", u, "_", Start_Date, "_", End_Date, "/feedtimes.csv")

    # Check if the file exists
    if (!file.exists(file)) {
      stop(paste("File does not exist:", file))
    }

    return(file)
  })

  # Read and bind feedtimes data
  feedtimes <- dplyr::bind_rows(
    purrr::map2_dfr(feedtimes_file_paths, Unit, function(file_path, unit) {
      readr::read_csv(file_path) %>%
        dplyr::mutate(unit = unit)
    })
  ) %>%
    dplyr::relocate(unit, .before = FeedTime) %>%
    dplyr::mutate(CowTag = gsub("^0+", "", CowTag))


  # Get the animal IDs that were not visiting the GreenFeed during the study
  noGFvisits <- CowsInExperiment$FarmName[!(CowsInExperiment$RFID %in% feedtimes$CowTag)]

  # Adding to the table the visit day and daytime visit
  number_drops <- feedtimes %>%
    dplyr::filter(CowTag %in% CowsInExperiment$RFID) %>%
    dplyr::mutate(
      Day = as.character(as.Date(FeedTime)),
      Time = round(lubridate::period_to_seconds(lubridate::hms(format(as.POSIXct(FeedTime), "%H:%M:%S"))) / 3600, 2)
    ) %>%
    dplyr::relocate(Day, Time, .before = unit) %>%
    dplyr::select(-FeedTime) %>%
    # Number of drops per cow per day and per unit
    dplyr::group_by(CowTag, unit, Day) %>%
    dplyr::summarise(
      ndrops = dplyr::n(),
      TotalPeriod = max(CurrentPeriod)
    )

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
  massAP_intakes <- CowsInExperiment[, 1:2] %>%
    dplyr::inner_join(massAP_intakes, by = c("RFID" = "CowTag"))
  names(massAP_intakes) <- c("Farm_name", "RFID", "Date", "Intake_AP_kg")


  # Create a sequence of dates from Start_Date to End_Date
  all_dates <- seq(as.Date(Start_Date), as.Date(End_Date), by = "day")

  # Create file with AP intakes in kg
  df <- massAP_intakes %>%
    dplyr::filter(Date >= Start_Date & Date <= End_Date) %>%
    dplyr::select(-RFID)

  df$Date <- as.Date(df$Date)

  df <- df %>% tidyr::complete(Date = all_dates, tidyr::nesting(Farm_name))

  # Add cows without visits to the units
  grid_cows_missing <- expand.grid(
    Date = unique(df$Date),
    Farm_name = CowsInExperiment$FarmName[CowsInExperiment$FarmName %in% noGFvisits],
    Intake_AP_kg = NA
  )
  df <- rbind(df, grid_cows_missing)

  # Replace NA for a period (.)
  df$Intake_AP_kg[is.na(df$Intake_AP_kg)] <- "."

  # Export a table with the amount of kg of pellets for a specific period!
  readr::write_excel_csv(df, file = paste0(getwd(), "/Pellet_Intakes_", Start_Date, "_", End_Date, ".txt"))
}
