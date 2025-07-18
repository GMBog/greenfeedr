#' @name viseat
#' @title Process 'GreenFeed' Visits
#'
#' @description Processes 'GreenFeed' visits and food drops for a requested period.
#'      Generates a list of animals not visiting the 'GreenFeed' to manage them,
#'      and a description of animals visiting the 'GreenFeed'.
#'
#' @param user a character string representing the user name to logging into 'GreenFeed' system
#' @param pass a character string representing password to logging into 'GreenFeed' system
#' @param unit numeric or character vector or list representing one or more GreenFeed unit numbers.
#' @param start_date a character string representing the start date of the study (format: "DD-MM-YY" or "YYYY-MM-DD")
#' @param end_date a character string representing the end date of the study (format: "DD-MM-YY" or "YYYY-MM-DD")
#' @param rfid_file a character string representing the file with individual RFIDs. The order should be Visual ID (col1) and RFID (col2)
#' @param file_path a character string or list representing files(s) with feedtimes from 'C-Lock Inc.'
#'
#' @return A list of two data frames:
#'   \item{visits_per_day }{Data frame with daily processed 'GreenFeed' data, including columns for VisualID, Date, Time, number of drops, and visits.}
#'   \item{visits_per_animal }{Data frame with weekly processed 'GreenFeed' data, including columns for VisualID, total drops, total visits, mean drops, and mean visits.}
#'
#'
#' @examples
#' # You should provide the feedtimes files.
#' # it could be a list of files if you have data from multiple units to combine
#' path <- system.file("extdata", "feedtimes.csv", package = "greenfeedr")
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
  "FID", "FeedTime", "CowTag", "Date", "visits", "Foodtype", "type",
  "Time", "CurrentPeriod", "ndrops", "Date", "FarmName"
))

viseat <- function(user = NA, pass = NA, unit,
                   start_date, end_date, rfid_file = NULL, file_path = NULL) {
  # Check Date format
  start_date <- ensure_date_format(start_date)
  end_date <- ensure_date_format(end_date)

  if (is.null(file_path)) {
    # Ensure unit is a comma-separated string
    unit <- convert_unit(unit,1)

    # Download data (using internal function in 'utils.R')
    df <- download_data(user, pass, d = "feed", type, unit = convert_unit(unit,1), start_date, end_date)

    # Remove leading zeros from tag IDs and formatting Date
    df <- df %>%
      dplyr::mutate(
        CowTag = gsub("^0+", "", CowTag),
        FeedTime = as.POSIXct(FeedTime, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")) %>%
      dplyr::filter(!is.na(FeedTime))
  } else {

    file_path <- normalizePath(file_path, mustWork = FALSE) # Convert to absolute path
    ext <- tools::file_ext(file_path)
    if (ext == "csv") {
      # Read CSV file
      df <- readr::read_csv(file_path, show_col_types = FALSE)
    } else if (ext %in% c("xls", "xlsx")) {
      # Read Excel file (both xls and xlsx)
      df <- readxl::read_excel(file_path)
    } else {
      stop("Unsupported file type. Please provide a CSV, XLS, or XLSX file.")
    }

    # Detect date format
    if (all(grepl("^\\d{4}-\\d{2}-\\d{2}", df$FeedTime))) {
      detected_format <- "%Y-%m-%d %H:%M:%S"
    } else if (all(grepl("^\\d{1,2}/\\d{1,2}/\\d{2}", df$FeedTime))) {
      detected_format <- "mdy_hm"
    } else {
      stop("Unknown FeedTime format in dataset!")
    }

    # Convert FeedTime using the detected format
    df <- df %>%
      mutate(
        FID = as.character(FID),
        CowTag = gsub("^0+", "", CowTag),
        FeedTime = if (detected_format == "%Y-%m-%d %H:%M:%S") {
          as.POSIXct(FeedTime, format = detected_format)
        } else {
          mdy_hm(FeedTime)
        }
      )

  }


  # Process the rfid data
  rfid_file <- process_rfid_data(rfid_file)

  # If rfid_file provided, filter and get animal ID not visiting the 'GreenFeed' units
  if (!is.null(rfid_file)){
    df <- df[df$CowTag %in% rfid_file$RFID, ]
    noGFvisits <- rfid_file$FarmName[!(rfid_file$RFID %in% df$CowTag)]

    message(paste("Animal IDs not visiting GF:", paste(noGFvisits, collapse = ", ")))

    # Create a data frame with number of drops and visits per day per animal
    daily_visits <- df %>%
      dplyr::inner_join(rfid_file[, 1:2], by = c("CowTag" = "RFID")) %>%
      dplyr::mutate(
        # Convert FeedTime to POSIXct with the correct format
        FeedTime = as.POSIXct(FeedTime, format = "%m/%d/%y %H:%M", tz = "UTC"),
        Date = as.character(as.Date(FeedTime)),
        Time = as.numeric(lubridate::period_to_seconds(lubridate::hms(format(FeedTime, "%H:%M:%S"))) / 3600),
        FoodType = as.character(FoodType)
      ) %>%
      dplyr::relocate(Date, Time, FarmName, .after = FID) %>%
      dplyr::select(-FeedTime) %>%
      # Number of drops per cow per day
      dplyr::group_by(FarmName, Date, FoodType) %>%
      dplyr::summarise(
        ndrops = dplyr::n(),
        visits = max(CurrentPeriod)
      )

    # Calculate the number of drops and visits per animal
    animal_visits <- daily_visits %>%
      dplyr::group_by(FarmName, FoodType) %>%
      dplyr::mutate(visits = as.numeric(visits)) %>%
      dplyr::summarise(
        total_drops = sum(ndrops),
        total_visits = sum(visits),
        mean_drops = round(mean(ndrops), 2),
        mean_visits = round(mean(visits), 2)
      )

  } else {

    # Create a data frame with number of drops and visits per day per animal
    daily_visits <- df %>%
      dplyr::mutate(
        # Convert FeedTime to POSIXct with the correct format
        FeedTime = as.POSIXct(FeedTime, format = "%m/%d/%y %H:%M", tz = "UTC"),
        Date = as.character(as.Date(FeedTime)),
        Time = as.numeric(lubridate::period_to_seconds(lubridate::hms(format(FeedTime, "%H:%M:%S"))) / 3600),
        FoodType = as.character(FoodType)
      ) %>%
      dplyr::relocate(Date, Time, RFID = CowTag, .after = FID) %>%
      dplyr::select(-FeedTime) %>%
      # Number of drops per cow per day
      dplyr::group_by(RFID, Date, FoodType) %>%
      dplyr::summarise(
        ndrops = dplyr::n(),
        visits = max(CurrentPeriod)
      ) %>%
      dplyr::mutate(visits = as.numeric(visits))

    # Calculate the number of drops and visits per animal
    animal_visits <- daily_visits %>%
      dplyr::group_by(RFID, FoodType) %>%
      dplyr::summarise(
        total_drops = sum(ndrops),
        total_visits = sum(visits),
        mean_drops = round(mean(ndrops), 2),
        mean_visits = round(mean(visits), 2)
      )
  }


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


  # Return a list of data frames
  return(list(
    feedtimes = df,
    visits_per_day = daily_visits,
    visits_per_animal = animal_visits
  ))

  message("Processing complete.")
}
