#' @name viseat
#' @title Process GreenFeed Visits
#'
#' @description `viseat()` processes visits to the GreenFeed
#'
#' @param Exp Study name
#' @param Unit List of the unit number/s of the GreenFeed
#' @param Start_Date Start date of the study
#' @param End_Date End date of the study
#' @param RFID_file The file that contains the RFID of the animals enrolled in the study
#'
#' @return Table with a summary of drops and visits to the GreenFeed unit/s
#'
#' @examples
#' \dontrun{
#' Exp <- "Test_study"
#' Unit <- list("577", "578")
#' Start_Date <- "2023-01-01"
#' End_Date <- "2023-04-01"
#' RFID_file <- "/Users/RFID_file.csv"
#'
#' viseat(Exp, Unit, Start_Date, End_Date, RFID_file)
#' }
#'
#' @export viseat
#'
#' @import dplyr
#' @importFrom dplyr %>%
#' @import lubridate
#' @import readr
#' @import readxl
#' @import utils

utils::globalVariables(c("unit", "FeedTime", "CowTag", "Day", "Time", "CurrentPeriod", "ndrops", "Date", "FarmName"))

viseat <- function(Exp = NA, Unit = list(NA),
                   Start_Date = NA, End_Date = NA, RFID_file = NA) {
  # Open list of animal IDs in the study
  if (tolower(tools::file_ext(RFID_file)) == "csv") {
    CowsInExperiment <- readr::read_table(RFID_file, col_types = readr::cols(EID = readr::col_character()))
  } else if (tolower(tools::file_ext(RFID_file)) %in% c("xls", "xlsx")) {
    CowsInExperiment <- readxl::read_excel(RFID_file)
    CowsInExperiment$EID <- as.character(CowsInExperiment$EID)
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
  message("Cows not visiting: ", paste(CowsInExperiment$FarmName[!(CowsInExperiment$EID %in% feedtimes$CowTag)], collapse = ", "))

  # Get the number of drops and visits per day per cow
  daily_visits <- feedtimes %>%
    dplyr::inner_join(CowsInExperiment[, 1:2], by = c("CowTag" = "EID")) %>%
    dplyr::mutate(
      Day = as.character(as.Date(FeedTime)),
      Time = round(lubridate::period_to_seconds(lubridate::hms(format(as.POSIXct(FeedTime), "%H:%M:%S"))) / 3600, 2)
    ) %>%
    dplyr::relocate(Day, Time, FarmName, .after = unit) %>%
    dplyr::select(-FeedTime) %>%
    # Number of drops per cow per day and per unit
    dplyr::group_by(FarmName, Day) %>%
    dplyr::summarise(ndrops = dplyr::n(), visits = max(CurrentPeriod))

  # Get the number of drops and visits per cow
  visits <- daily_visits %>%
    dplyr::group_by(FarmName) %>%
    dplyr::summarise(
      total_drops = sum(ndrops),
      total_visits = sum(visits),
      mean_drops = round(mean(ndrops), 2),
      mean_visits = round(mean(visits), 2)
    )


  return(visits)
}
