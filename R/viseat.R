#' @name viseat
#' @title Check GreenFeed Visits
#'
#' @description `viseat()` processes GreenFeed visits and food drops.
#'      This function generates a list of animals not visiting the GreenFeed and
#'      a description of animals visiting the system for the requested period.
#'
#' @param file File with feedtimes from C-Lock. If multiple files are provided, units should be in the same order
#' @param unit GreenFeed unit number(s). If multiple units, they could be in a vector, list, or character as "1,2"
#' @param start_date Start date of the study
#' @param end_date End date of the study
#' @param RFID_file The file that contains the RFID of the animals enrolled in the study. The order should be col1=FarmName and col2=RFID
#'
#' @return A list with two data farmes, one with visits per day and one with visits per animal
#'
#' @examples
#' # You should provide the 'feedtimes' files.
#' # it could be a list of files if you have data from multiple units to combine
#' file <- list(system.file("extdata", "feedtimes.csv", package = "greenfeedr"))
#'
#' # If the user include an RFID file, the structure should be in col1 the farmname or visualID, and
#' # col2 the RFID or TAG_ID. The file could be save in different formats (.xlsx, .csv, or .txt).
#' RFIDs <- system.file("extdata", "RFID_file.txt", package = "greenfeedr")
#'
#' data <- viseat(file,
#'                unit = 1,
#'                start_date = "2024-05-13",
#'                end_date = "2024-05-25",
#'                RFID_file = RFIDs
#'                )
#'
#' @export viseat
#'
#' @import dplyr
#' @importFrom dplyr %>%
#' @import ggplot2
#' @import lubridate
#' @import readr
#' @import readxl
#' @import utils

utils::globalVariables(c(
  "FID", "FeedTime", "CowTag", "Date", "visits",
  "Time", "CurrentPeriod", "ndrops", "Date", "FarmName"
))

viseat <- function(file, unit, start_date, end_date, RFID_file = NA) {
  # Check Date format
  start_date <- ensure_date_format(start_date)
  end_date <- ensure_date_format(end_date)

  # Read file with the RFID in the study
  if (!is.na(RFID_file)) {
    file_extension <- tolower(tools::file_ext(RFID_file))

    if (file_extension == "csv") {
      RFID_file <- readr::read_csv(RFID_file, col_types = readr::cols(.default = readr::col_character()))
    } else if (file_extension %in% c("xls", "xlsx")) {
      # Read all columns and then select the first two
      RFID_file <- readxl::read_excel(RFID_file) %>%
        dplyr::select(1:2) %>%
        dplyr::mutate(across(everything(), as.character))
    } else if (file_extension == "txt") {
      RFID_file <- readr::read_table(RFID_file, col_types = readr::cols(.default = readr::col_character()))
    } else {
      stop("Unsupported file format.")
    }

    # Rename the columns if needed
    names(RFID_file)[1:2] <- c("FarmName", "RFID")
  } else {
    message("The user must include an 'RFID_file' with VisualID and RFID.")
  }

  # Read and bind feedtimes data
  df <- purrr::map2_dfr(file, unit, ~ {
    readr::read_csv(.x) %>%
      dplyr::mutate(FID = .y)
  }) %>%
    dplyr::relocate(FID, .before = FeedTime) %>%
    dplyr::mutate(CowTag = gsub("^0+", "", CowTag))


  # If RFID_file provided, filter and get animal ID not visiting the GreenFeed units
  df <- df[df$CowTag %in% RFID_file$RFID, ]
  noGFvisits <- RFID_file$FarmName[!(RFID_file$RFID %in% df$CowTag)]

  message(paste("Animal IDs not visiting GF:", paste(noGFvisits, collapse = ", ")))

  # Plot the visits per unit
  plotFID <- df %>%
    dplyr::group_by(FID) %>%
    dplyr::summarise(n = n()) %>%
    ggplot(aes(x = as.factor(FID), y = n, fill = as.factor(FID))) +
    geom_bar(stat = "identity", position = position_dodge()) +
    theme_classic() +
    labs(
      title = "TAG reads per unit",
      x = "Units",
      y = "Frequency",
      fill = "Unit"
    ) +
    geom_text(aes(label = n),
      vjust = 1.9,
      color = "black",
      position = position_dodge(0.9), size = 3.8
    )
  print(plotFID)

  # Create a data frame with number of drops and visits per day per animal
  daily_visits <- df %>%
    dplyr::inner_join(RFID_file[, 1:2], by = c("CowTag" = "RFID")) %>%
    dplyr::mutate(
      # Convert FeedTime to POSIXct with the correct format
      FeedTime = as.POSIXct(FeedTime, format = "%m/%d/%y %H:%M", tz = "UTC"),
      Date = as.character(as.Date(FeedTime)),
      Time = as.numeric(lubridate::period_to_seconds(lubridate::hms(format(FeedTime, "%H:%M:%S"))) / 3600)
    ) %>%
    dplyr::relocate(Date, Time, FarmName, .after = unit) %>%
    dplyr::select(-FeedTime) %>%
    # Number of drops per cow per day
    dplyr::group_by(FarmName, Date) %>%
    dplyr::summarise(
      ndrops = dplyr::n(),
      visits = max(CurrentPeriod)
    )

  # Calculate the number of drops and visits per animal
  animal_visits <- daily_visits %>%
    dplyr::group_by(FarmName) %>%
    dplyr::summarise(
      total_drops = sum(ndrops),
      total_visits = sum(visits),
      mean_drops = round(mean(ndrops), 2),
      mean_visits = round(mean(visits), 2)
    )


  # Return a list of data frames
  return(list(visits_per_unit = daily_visits, visits_per_animal = animal_visits))
}
