#' @name process_gfdata
#' @title Process Daily and Final GreenFeed Data
#'
#' @description `process_gfdata()` processes and computes daily and weekly averages
#'     for daily and final GreenFeed data, organizing it into two data sets.
#'     This function handles data filtering, aggregation, and summarization to facilitate
#'     further analysis and reporting.
#'
#' @param file File with GreenFeed data. It could be daily or final data
#' @param start_date Start date of the study
#' @param end_date End date of the study
#' @param input_type Input file with data. It could be from daily or final report
#' @param param1 Number of records per day to be consider for analysis
#' @param param2 Number of days with records per week to be consider for analysis
#' @param min_time Minimum number of minutes for a records to be consider for analysis. By default min_time is 2
#'
#' @return Two data frames with daily and weekly processed GreenFeed data
#'
#' @examples
#' file1 <- system.file("extdata", "StudyName_GFdata.csv", package = "greenfeedr")
#' data1 <- process_gfdata(file1,
#'                         input_type = "daily",
#'                         start_date = "2024-05-13",
#'                         end_date = "2024-05-25",
#'                         param1 = 2,
#'                         param2 = 3
#'                         )
#' head(data1)
#'
#' file2 <- system.file("extdata", "StudyName_FinalReport.xlsx", package = "greenfeedr")
#' data2 <- process_gfdata(file2,
#'                         input_type = "final",
#'                         start_date = "2024-05-13",
#'                         end_date = "2024-05-25",
#'                         param1 = 2,
#'                         param2 = 3
#'                         )
#'
#' head(data2)
#'
#' @export process_gfdata
#'
#' @import dplyr
#' @importFrom dplyr %>%
#' @import readxl
#' @importFrom stats weighted.mean
#' @importFrom stats sd

utils::globalVariables(c(
  "EndTime", "CH4GramsPerDay", "CO2GramsPerDay", "O2GramsPerDay", "H2GramsPerDay",
  "nDays", "nRecords", "TotalMin"
))

process_gfdata <- function(file, start_date, end_date, input_type,
                           param1, param2, min_time = 2) {
  # Check Date format
  start_date <- ensure_date_format(start_date)
  end_date <- ensure_date_format(end_date)

  # Ensure param1 and param2 are defined
  if (missing(param1) || missing(param2)) {
    stop("Please define 'param1' (minimum records per day), 'param2' (minimum days per week), and min_time (minimum minutes per visit)")
  } else {
    message(paste("Using param1 =", param1, ", param2 =", param2, ", min_time =", min_time))
  }

  # Convert input_type to lowercase to ensure case-insensitivity
  input_type <- tolower(input_type)

  # Ensure input_type is valid
  valid_inputs <- c("final", "daily")
  if (!(input_type %in% valid_inputs)) {
    stop(paste("Invalid input_type. Choose one of:", paste(valid_inputs, collapse = ", ")))
  }

  # Function to read and process each file
  process_file <- function(file, input_type) {
    if (input_type == "final") {
      # Read from Excel file
      df <- readxl::read_excel(file, col_types = c("text", "text", "numeric", rep("date", 3), rep("numeric", 12), rep("text", 3), rep("numeric", 4)))
      names(df)[1:14] <- c(
        "RFID",
        "AnimalName",
        "FeederID",
        "StartTime",
        "EndTime",
        "GoodDataDuration",
        "HourOfDay",
        "CO2GramsPerDay",
        "CH4GramsPerDay",
        "O2GramsPerDay",
        "H2GramsPerDay",
        "H2SGramsPerDay",
        "AirflowLitersPerSec",
        "AirflowCf"
      )

      df <- df %>%
        # Remove leading zeros from RFID col to match with IDs
        dplyr::mutate(RFID = gsub("^0+", "", RFID)) %>%
        # Remove records with negative values. Note that O2 and H2 it is greater or equal because some units don't have sensors
        dplyr::filter(CH4GramsPerDay > 0, CO2GramsPerDay > 0, O2GramsPerDay >= 0, H2GramsPerDay >= 0) %>%
        # Change columns format
        dplyr::mutate(
          day = as.Date(EndTime),
          # Extract hours, minutes, and seconds from GoodDataDuration
          GoodDataDuration = round(
             as.numeric(substr(GoodDataDuration, 12, 13)) * 60 + # Hours to minutes
            #as.numeric(substr(GoodDataDuration, 1, 2)) * 60 + # Hours to minutes
             as.numeric(substr(GoodDataDuration, 15, 16)) + # Minutes
            #as.numeric(substr(GoodDataDuration, 4, 5)) + # Minutes
             as.numeric(substr(GoodDataDuration, 18, 19)) / 60, # Seconds to minutes
            #as.numeric(substr(GoodDataDuration, 7, 8)) / 60, # Seconds to minutes
            2
          )
        )
    } else {
      # Read from CSV file
      df <- readr::read_csv(file)
      names(df) <- c(
        "FeederID",
        "AnimalName",
        "RFID",
        "StartTime",
        "EndTime",
        "GoodDataDuration",
        "CO2GramsPerDay",
        "CH4GramsPerDay",
        "O2GramsPerDay",
        "H2GramsPerDay",
        "H2SGramsPerDay",
        "AirflowLitersPerSec",
        "AirflowCf",
        "WindSpeedMetersPerSec",
        "WindDirDeg",
        "WindCf",
        "WasInterrupted",
        "InterruptingTags",
        "TempPipeDegreesCelsius",
        "IsPreliminary",
        "RunTime"
      )

      df <- df %>%
        # Remove leading zeros from RFID col to match with IDs
        dplyr::mutate(RFID = gsub("^0+", "", RFID)) %>%
        # Remove records with negative values. Note that O2 and H2 are greater or equal because some units don't have sensors
        dplyr::filter(CH4GramsPerDay > 0, CO2GramsPerDay > 0, O2GramsPerDay >= 0, H2GramsPerDay >= 0) %>%
        # Change columns format
        dplyr::mutate(
          day = as.Date(sub(" .*", "", df$EndTime), format = "%m/%d/%y"),
          # Extract hours, minutes, and seconds from GoodDataDuration
          GoodDataDuration = round(
            as.numeric(substr(GoodDataDuration, 1, 2)) * 60 + # Hours to minutes
              as.numeric(substr(GoodDataDuration, 4, 5)) + # Minutes
              as.numeric(substr(GoodDataDuration, 7, 8)) / 60, # Seconds to minutes
            2
          ),
          # 'HourOfDay' is a new col that contains daytime (extract the time part from StartTime (HH:MM:SS))
          HourOfDay = round(
            as.numeric(format(as.POSIXct(StartTime, format = "%m/%d/%y %H:%M"), "%H")) + # Extract hours
              as.numeric(format(as.POSIXct(StartTime, format = "%m/%d/%y %H:%M"), "%M")) / 60, # Extract minutes and convert to fraction of an hour
            2
          )
        )
    }
  }

  # Combine all files into one data frame
  df <- do.call(rbind, lapply(file, process_file, input_type))

  ## Computing weekly production of gases
  daily_df <- df %>%
    dplyr::filter(
      dplyr::if_all(
        c(CH4GramsPerDay, CO2GramsPerDay, O2GramsPerDay, H2GramsPerDay),
        ~ filter_within_range(.x, 2.5)
      ),
      GoodDataDuration >= min_time
    ) %>%
    dplyr::group_by(RFID, day) %>%
    dplyr::summarise(
      n = n(),
      across(
        c(CH4GramsPerDay, CO2GramsPerDay, O2GramsPerDay, H2GramsPerDay),
        ~ weighted.mean(.x, GoodDataDuration, na.rm = TRUE),
        .names = "{.col}"
      ),
      minutes = sum(GoodDataDuration, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::filter(n >= param1) %>%
    dplyr::mutate(week = floor(as.numeric(difftime(day, min(day), units = "weeks"))) + 1) %>%
    dplyr::select(RFID, week, n, minutes, CH4GramsPerDay, CO2GramsPerDay, O2GramsPerDay, H2GramsPerDay)


  weekly_df <- daily_df %>%
    dplyr::group_by(RFID, week) %>%
    dplyr::summarise(
      nDays = n(),
      nRecords = sum(n),
      TotalMin = round(sum(minutes), 2),
      across(
        c(CH4GramsPerDay, CO2GramsPerDay, O2GramsPerDay, H2GramsPerDay),
        ~ weighted.mean(.x, minutes, na.rm = TRUE),
        .names = "{.col}"
      ),
      .groups = "drop" # Un-group after summarizing
    ) %>%
    dplyr::filter(nDays >= param2) %>% # Filter out weeks with less than "param2" days
    dplyr::select(RFID, week, nDays, nRecords, TotalMin, CH4GramsPerDay, CO2GramsPerDay, O2GramsPerDay, H2GramsPerDay)


  ### Description of mean, sd, and CV for weekly gases
  print(paste0("CH4: ", round(mean(weekly_df$CH4GramsPerDay, na.rm = TRUE), 2), " +- ", round(stats::sd(weekly_df$CH4GramsPerDay, na.rm = TRUE), 2)))
  print(paste0("CH4 CV = ", round(stats::sd(weekly_df$CH4GramsPerDay, na.rm = TRUE) / mean(weekly_df$CH4GramsPerDay, na.rm = TRUE) * 100, 1), "%"))

  print(paste0("CO2: ", round(mean(weekly_df$CO2GramsPerDay, na.rm = TRUE), 2), " +- ", round(stats::sd(weekly_df$CO2GramsPerDay, na.rm = TRUE), 2)))
  print(paste0("CO2 CV = ", round(stats::sd(weekly_df$CO2GramsPerDay, na.rm = TRUE) / mean(weekly_df$CO2GramsPerDay, na.rm = TRUE) * 100, 1), "%"))

  print(paste0("O2: ", round(mean(weekly_df$O2GramsPerDay, na.rm = TRUE), 2), " +- ", round(stats::sd(weekly_df$O2GramsPerDay, na.rm = TRUE), 2)))
  print(paste0("O2 CV = ", round(stats::sd(weekly_df$O2GramsPerDay, na.rm = TRUE) / mean(weekly_df$O2GramsPerDay, na.rm = TRUE) * 100, 1), "%"))

  print(paste0("H2: ", round(mean(weekly_df$H2GramsPerDay, na.rm = TRUE), 2), " +- ", round(stats::sd(weekly_df$H2GramsPerDay, na.rm = TRUE), 2)))
  print(paste0("H2 CV = ", round(stats::sd(weekly_df$H2GramsPerDay, na.rm = TRUE) / mean(weekly_df$H2GramsPerDay, na.rm = TRUE) * 100, 1), "%"))


  # Return a list of data frames
  return(list(daily_data = daily_df, weekly_data = weekly_df))
}
