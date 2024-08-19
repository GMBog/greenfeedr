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
#'
#' # You should provide the folder where is 'feedtimes' file.
#' # it could be a list of files if you have data from multiple units to combine
#' file = list(
#'   system.file("extdata", "data_1_2024-05-13_2024-05-25, "feedtimes.csv", package = "greenfeedr"
#'   )
#'
#' # By default the function use 34g, but you should include the result obtained from the 10-drops test
#'
#' pellin(file,
#'        Unit = 1,
#'        gcup = 34,
#'        Start_Date = "2024-05-13",
#'        End_Date = "2024-05-25")
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
  "unit", "FeedTime", "CowTag", "Time", "CurrentPeriod", "ndrops", "feedtimes",
  "MassFoodDrop", "Date", "RFID", "massAP_intakes_sp", "Farm_name"
))

pellin <- function(file, Unit, gcup = 34,
                   Start_Date, End_Date, RFID_file = NA) {

  message("Please set the 'gcup' parameter based on the 10-drops test. The default value is 34g.")

  # Read file with the RFID in the study
  if (!is.na(RFID_file)) {
    file_extension <- tolower(tools::file_ext(RFID_file))

    if (file_extension == "csv") {
      RFID_file <- readr::read_table(RFID_file, col_types = readr::cols(FarmName = readr::col_character(), RFID = readr::col_character()))
    } else if (file_extension %in% c("xls", "xlsx")) {
      RFID_file <- readxl::read_excel(RFID_file, col_types = c("text", "text", "numeric", "text"))
    } else {
      stop("Unsupported file format.")
    }
  } else {
    message("It is recommended to include an 'RFID_file' that contains both 'RFID' and 'FarmName' columns.")
  }

  # Read and bind feedtimes data
  df <- purrr::map2_dfr(file, Unit, ~ {
    readr::read_csv(.x) %>%
      dplyr::mutate(unit = .y)
  }) %>%
    dplyr::relocate(unit, .before = FeedTime) %>%
    dplyr::mutate(CowTag = gsub("^0+", "", CowTag))


  # Get the animal IDs that were not visiting the GreenFeed during the study
  if (nrow(RFID_file) > 0 && !is.na(RFID_file)) {
    noGFvisits <- RFID_file$FarmName[!(RFID_file$RFID %in% feedtimes$CowTag)]
    df <- df %>%
      dplyr::filter(CowTag %in% RFID_file$RFID)
  }

  # Adding to the table the visit day and daytime visit
  number_drops <- df %>%
    dplyr::mutate(
      # Convert FeedTime to POSIXct with the correct format
      FeedTime = as.POSIXct(FeedTime, format="%m/%d/%y %H:%M", tz="UTC"),
      Date = as.character(as.Date(FeedTime)),
      Time = as.numeric(lubridate::period_to_seconds(lubridate::hms(format(FeedTime, "%H:%M:%S"))) / 3600)
    ) %>%
    dplyr::relocate(Date, Time, .before = unit) %>%
    dplyr::select(-FeedTime) %>%
    # Number of drops per cow per day and per unit
    dplyr::group_by(CowTag, unit, Date) %>%
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
    dplyr::group_by(CowTag, Date) %>%
    dplyr::summarise(MassFoodDrop = sum(MassFoodDrop) / 1000) # Divided by 1000 to transform mass in kg

  # Create the grid of all unique combinations of Date and CowTag
  grid <- expand.grid(Date = unique(massAP_intakes$Date), CowTag = unique(massAP_intakes$CowTag))

  # Merge massAP_intakes with the grid and then replace NA values in the MassFoodDrop column with 0
  massAP_intakes <- merge(massAP_intakes, grid, all = TRUE)
  massAP_intakes$MassFoodDrop[is.na(massAP_intakes$MassFoodDrop)] <- 0

  # Adding the Farm name to the AP intakes
  if (nrow(RFID_file) > 0 && !is.na(RFID_file)) {
    massAP_intakes <- RFID_file[, 1:2] %>%
      dplyr::inner_join(massAP_intakes, by = c("RFID" = "CowTag"))
    names(massAP_intakes) <- c("Farm_name", "RFID", "Date", "Intake_AP_kg")
  } else {
    names(massAP_intakes) <- c("RFID", "Date", "Intake_AP_kg")
  }


  # Create a sequence of dates from Start_Date to End_Date
  all_dates <- seq(as.Date(Start_Date), as.Date(End_Date), by = "day")

  # Create file with AP intakes in kg
  df <- massAP_intakes %>%
    dplyr::filter(Date >= Start_Date & Date <= End_Date)

  df$Date <- as.Date(df$Date)

  if (nrow(RFID_file) > 0 && !is.na(RFID_file)) {
    df <- df %>% tidyr::complete(Date = all_dates, tidyr::nesting(Farm_name))
  } else {
    df <- df %>% tidyr::complete(Date = all_dates, tidyr::nesting(RFID))
  }

  # Add cows without visits to the units
  if (nrow(RFID_file) > 0 && !is.na(RFID_file)) {
    grid_cows_missing <- expand.grid(
      Date = unique(df$Date),
      Farm_name = RFID_file$FarmName[RFID_file$FarmName %in% noGFvisits],
      Intake_AP_kg = NA
    )

    df <- rbind(df, grid_cows_missing)
  }

  # Replace NA for a period (.)
  df$Intake_AP_kg[is.na(df$Intake_AP_kg)] <- "."

  # Export a table with the amount of kg of pellets for a specific period!
  readr::write_excel_csv(df, file = paste0(getwd(), "/Pellet_Intakes_", Start_Date, "_", End_Date, ".txt"))
}
