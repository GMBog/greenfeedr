#' @name pellin
#' @title Process GreenFeed Pellet Intakes
#'
#' @description `pellin()` processes the feedtimes file from GreenFeed system,
#'     including visits and food drops across a specific period, and it is used
#'     to calculate pellet intakes per animal from all units.
#'     This function aggregates data to provide insights into the feeding behavior
#'     and pellet consumption of the animals during a study.
#'
#' @param file_path File with feedtimes from C-Lock. If multiple files are provided, units should be in the same order
#' @param unit GreenFeed unit number(s). If multiple units, they could be in a vector, list, or character as "1,2"
#' @param gcup Grams of pellets per cup. By default 34 grams, but users should provide the grams based on the 10-drops test
#' @param start_date Start date of the study
#' @param end_date End date of the study
#' @param save_dir Directory where to save the resulting file with pellet intakes
#' @param rfid_file The file that contains the rfid of the animals enrolled in the study. The order should be col1=FarmName and col2=RFID
#'
#' @return An Excel file with pellet intakes for all animals and dates of the requested period
#'
#' @examples
#' # You should provide the 'feedtimes' file provided by C-Lock.
#' # it could be a list of files if you have data from multiple units to combine
#' file <- list(system.file("extdata", "feedtimes.csv", package = "greenfeedr"))
#'
#' # By default the function use 34g, but you should include the result obtained from the 10-drops test
#'
#' # If the user include an rfid file, the structure should be in col1 the farmname or visualID, and
#' # col2 the RFID or TAG_ID. The file could be save in different formats (.xlsx, .csv, or .txt).
#'
#' pellin(file,
#'   unit = 1,
#'   gcup = 34,
#'   start_date = "2024-05-13",
#'   end_date = "2024-05-25",
#'   save_dir = tempdir()
#' )
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
  "FID", "FeedTime", "CowTag", "Time", "CurrentPeriod", "ndrops",
  "MassFoodDrop", "Date", "RFID", "pellintakes", "FarmName"
))

pellin <- function(file_path, unit, gcup = 34, start_date, end_date,
                   save_dir = getwd(), rfid_file = NA) {
  message("Please set the 'gcup' parameter based on the 10-drops test. The default value is 34g.")

  # Check Date format
  start_date <- ensure_date_format(start_date)
  end_date <- ensure_date_format(end_date)

  # Read file with the RFID in the study
  if (!is.na(rfid_file)) {
    file_extension <- tolower(tools::file_ext(rfid_file))

    if (file_extension == "csv") {
      rfid_file <- readr::read_csv(rfid_file, col_types = readr::cols(.default = readr::col_character()))
    } else if (file_extension %in% c("xls", "xlsx")) {
      # Read all columns and then select the first two
      rfid_file <- readxl::read_excel(rfid_file) %>%
        dplyr::select(1:2) %>%
        dplyr::mutate(across(everything(), as.character))
    } else if (file_extension == "txt") {
      rfid_file <- readr::read_table(rfid_file, col_types = readr::cols(.default = readr::col_character()))
    } else {
      stop("Unsupported file format.")
    }

    # Rename the columns if needed
    names(rfid_file)[1:2] <- c("FarmName", "RFID")
  } else {
    message("It is recommended to include an 'rfid_file' that contains the relevant columns.")
  }

  # Read and bind feedtimes data
  df <- purrr::map2_dfr(file_path, unit, ~ {
    readr::read_csv(.x) %>%
      dplyr::mutate(FID = .y)
  }) %>%
    dplyr::relocate(FID, .before = FeedTime) %>%
    dplyr::mutate(CowTag = gsub("^0+", "", CowTag))


  # If rfid_file provided, filter and get animal ID not visiting the GreenFeed units
  if (!is.null(rfid_file) && is.data.frame(rfid_file) && nrow(rfid_file) > 0) {
    df <- df[df$CowTag %in% rfid_file$RFID, ]
    noGFvisits <- rfid_file$FarmName[!(rfid_file$RFID %in% df$CowTag)]
    message(paste("Animal ID not visting GF: ", noGFvisits))
  }

  # Create a table with visit day and time and calculate drops per animal/FID/day
  number_drops <- df %>%
    dplyr::mutate(
      # Convert FeedTime to POSIXct with the correct format
      FeedTime = as.POSIXct(FeedTime, format = "%m/%d/%y %H:%M", tz = "UTC"),
      Date = as.character(as.Date(FeedTime)),
      Time = as.numeric(lubridate::period_to_seconds(lubridate::hms(format(FeedTime, "%H:%M:%S"))) / 3600)
    ) %>%
    dplyr::relocate(Date, Time, .before = FID) %>%
    dplyr::select(-FeedTime) %>%
    # Calculate drops per animal/FID/day
    dplyr::group_by(CowTag, FID, Date) %>%
    dplyr::summarise(
      ndrops = dplyr::n(),
      TotalPeriod = max(CurrentPeriod)
    )

  # As units can fit different amount of grams in their cups. We define gcup per unit
  grams_df <- data.frame(
    FID = unlist(unit),
    gcup = gcup
  )

  # Calculate MassFoodDrop by number of cup drops times grams per cup
  pellintakes <- number_drops %>%
    dplyr::left_join(grams_df, by = "FID") %>%
    dplyr::mutate(MassFoodDrop = ndrops * gcup) %>%
    # Create a table with alfalfa pellets (AP) intakes in kg
    dplyr::group_by(CowTag, Date) %>%
    dplyr::summarise(MassFoodDrop = sum(MassFoodDrop) / 1000) # Divided by 1000 to transform mass in kg

  # Create a grid with all unique combinations of Date and CowTag
  grid <- expand.grid(
    Date = unique(pellintakes$Date),
    CowTag = unique(pellintakes$CowTag)
  )

  # Create a table with all animals
  ## We merge pellintakes file with the grid and then we replace 'NA' with 0
  pellintakes <- merge(pellintakes, grid, all = TRUE)
  pellintakes$MassFoodDrop[is.na(pellintakes$MassFoodDrop)] <- 0

  # Adding the Farm name to the AP intakes
  if (!is.null(rfid_file) && is.data.frame(rfid_file) && nrow(rfid_file) > 0) {
    pellintakes <- rfid_file[, 1:2] %>%
      dplyr::inner_join(pellintakes, by = c("RFID" = "CowTag"))
    names(pellintakes) <- c("FarmName", "RFID", "Date", "Intake_AP_kg")
  } else {
    names(pellintakes) <- c("RFID", "Date", "Pellin_kg")
  }


  # Create a sequence of dates from the start date to the end date of the study
  all_dates <- seq(as.Date(start_date), as.Date(end_date), by = "day")

  # Create file with pellet intakes in kg
  df <- pellintakes %>%
    dplyr::filter(Date >= start_date & Date <= end_date) %>%
    dplyr::mutate(Date = as.Date(Date))


  if (!is.null(rfid_file) && is.data.frame(rfid_file) && nrow(rfid_file) > 0) {
    df <- df %>% tidyr::complete(Date = all_dates, tidyr::nesting(FarmName, RFID))
  } else {
    df <- df %>% tidyr::complete(Date = all_dates, tidyr::nesting(RFID))
  }

  # Add cows without visits to the units
  if (!is.null(rfid_file) && is.data.frame(rfid_file) && nrow(rfid_file) > 0) {
    grid_cows_missing <- expand.grid(
      Date = unique(df$Date),
      FarmName = rfid_file$FarmName[rfid_file$FarmName %in% noGFvisits],
      RFID = rfid_file$RFID[rfid_file$FarmName %in% noGFvisits],
      Intake_AP_kg = NA
    )

    df <- rbind(df, grid_cows_missing)
  }


  # Export a table with the amount of kg of pellets for a specific period!
  readr::write_excel_csv(df,
    file = paste0(save_dir, "/Pellet_Intakes_", start_date, "_", end_date, ".csv")
  )
}
