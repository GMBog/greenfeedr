#' @name viseat
#' @title Process 'GreenFeed' Visits
#'
#' @description Processes 'GreenFeed' visits and food drops for a requested period.
#'      Generates a list of animals not visiting the 'GreenFeed' to manage them,
#'      and a description of animals visiting the 'GreenFeed'.
#'
#' @param file_path a character string or list representing files(s) with feedtimes from 'C-Lock Inc.'.
#' @param unit numeric or character vector or list representing one or more GreenFeed unit numbers.
#' @param start_date a character string representing the start date of the study (format: "mm/dd/yyyy")
#' @param end_date a character string representing the end date of the study (format: "mm/dd/yyyy")
#' @param rfid_file a character string representing the file with individual RFIDs.  The order should be Visual ID (col1) and RFID (col2)
#'
#' @return A list of two data frames:
#'   \item{visits_per_unit }{Data frame with daily processed 'GreenFeed' data, including columns for VisualID, Date, Time, number of drops, and visits.}
#'   \item{visits_per_animal }{Data frame with weekly processed 'GreenFeed' data, including columns for VisualID, total drops, total visits, mean drops, and mean visits.}
#'
#'
#' @examples
#' # You should provide the feedtimes files.
#' # it could be a list of files if you have data from multiple units to combine
#' path <- list(system.file("extdata", "feedtimes.csv", package = "greenfeedr"))
#'
#' # If the user include an rfid file, the structure should be in col1 AnimalName or VisualID, and
#' # col2 the RFID or TAG_ID. The file could be save in different formats (.xlsx, .csv, or .txt).
#' RFIDs <- system.file("extdata", "RFID_file.csv", package = "greenfeedr")
#'
#' data <- viseat(
#'   file_path = path,
#'   unit = 1,
#'   start_date = "2024-05-13",
#'   end_date = "2024-05-25",
#'   rfid_file = RFIDs
#' )
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

viseat <- function(file_path, unit, start_date, end_date, rfid_file = NA) {
  # Check Date format
  start_date <- ensure_date_format(start_date)
  end_date <- ensure_date_format(end_date)

  # Process the rfid data
  rfid_file <- process_rfid_data(rfid_file)

  if (is.null(rfid_file)) {
    message("RFID data could not be processed. Exiting function.")
    return(NULL)
  }

  # Read and bind feedtimes data
  df <- purrr::map2_dfr(file_path, unit, ~ {
    if (grepl("\\.csv$", .x)) {
      # Read CSV file
      readr::read_csv(.x, show_col_types = FALSE) %>%
        dplyr::mutate(FID = .y)
    } else if (grepl("\\.xls?$", .x)) {
      # Read Excel file
      readxl::read_excel(.x) %>%
        dplyr::mutate(FID = .y)
    } else {
      stop("Unsupported file type. Please provide a CSV or Excel file.")
    }
  }) %>%
    dplyr::relocate(FID, .before = FeedTime) %>%
    dplyr::mutate(CowTag = gsub("^0+", "", CowTag))


  # If rfid_file provided, filter and get animal ID not visiting the 'GreenFeed' units
  df <- df[df$CowTag %in% rfid_file$RFID, ]
  noGFvisits <- rfid_file$FarmName[!(rfid_file$RFID %in% df$CowTag)]

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
  message(plotFID)

  # Create a data frame with number of drops and visits per day per animal
  daily_visits <- df %>%
    dplyr::inner_join(rfid_file[, 1:2], by = c("CowTag" = "RFID")) %>%
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
  return(list(
    visits_per_unit = daily_visits,
    visits_per_animal = animal_visits
  ))

  message("Processing complete.")
}
