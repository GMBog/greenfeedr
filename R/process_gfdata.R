#' @title process_gfdata
#' @name process_gfdata
#' @description Process daily data from GreenFeed using your own parameters.
#'
#' @param file File with GreenFeed data
#' @param Start_Date Start date of the study
#' @param End_Date End date of the study
#' @param input_type Data could be from daily or final report: "daily" or "final"
#' @param param1 Number of records a day
#' @param param2 Number of days with records
#'
#' @return Tables with GreenFeed processed data: daily data and weekly data
#' @export process_gfdata
#'
#' @examples
#' \dontrun{
#' Start_Date <- "2024-01-22"
#' End_Date <- "2024-03-08"
#' input_type <- "final"
#' file <- system.file("extdata", "StudyName_FinalReport.xlsx", package = "greenfeedr")
#' data <- process_gfdata(file, Start_Date, End_Date, input_type, param1 = 2, param2 = 3)
#' }
#'
#' @import dplyr
#' @importFrom dplyr %>%
#' @import readxl
#' @importFrom stats weighted.mean
#' @importFrom stats sd

utils::globalVariables(c("EndTime", "CH4", "CO2", "O2", "H2", "nDays", "nRecords", "TotalMin", "CV"))

process_gfdata <- function(file, Start_Date, End_Date = Sys.Date(), input_type, param1, param2) {
  # Ensure param1 and param2 are defined
  if (missing(param1) || missing(param2)) {
    stop("Please define 'param1' (minimum records per day) and 'param2' (minimum days per week).")
  } else {
    message(paste("Using param1 =", param1, "and param2 =", param2))
  }

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

      # Rename columns
      names(df)[1:14] <- c(
        "RFID",
        "FarmName",
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
    } else {
      # Read from CSV file
      df <- readr::read_csv(file)

      # Ensure column names match
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
    }

    df <- df %>%
      # Remove leading zeros from RFID col to match with IDs
      dplyr::mutate(RFID = gsub("^0+", "", RFID)) %>%
      # Change columns format
      dplyr::mutate(
        # 'GoodDataDuration' col is the time the visit last and it will be expressed in minutes with two decimals
        GoodDataDuration = round(lubridate::period_to_seconds(lubridate::hms(format(as.POSIXct(GoodDataDuration), "%H:%M:%S"))) / 60, 2),
        # 'HourOfDay' col is a new col that will contains the time of the day in which the visit happened
        HourOfDay = round(lubridate::period_to_seconds(lubridate::hms(format(as.POSIXct(StartTime), "%H:%M:%S"))) / 3600, 2)
      )
  }

  # Combine all files into one data frame
  df <- do.call(rbind, lapply(file, process_file, input_type = input_type))



  ## Computing weekly production of gases
  daily_df <- df %>%
    dplyr::mutate(day = as.Date(EndTime)) %>%
    dplyr::filter(CH4GramsPerDay >= 200 & CH4GramsPerDay <= 800) %>%
    dplyr::group_by(RFID, day) %>%
    dplyr::summarise(
      n = n(),
      CH4 = weighted.mean(CH4GramsPerDay, GoodDataDuration, na.rm = TRUE),
      CO2 = weighted.mean(CO2GramsPerDay, GoodDataDuration, na.rm = TRUE),
      O2 = weighted.mean(O2GramsPerDay, GoodDataDuration, na.rm = TRUE),
      H2 = weighted.mean(H2GramsPerDay, GoodDataDuration, na.rm = TRUE),
      minutes = sum(GoodDataDuration, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::filter(n >= param1) %>% # Filter out days with less than 2 records

    dplyr::mutate(week = floor(as.numeric(difftime(day, min(day), units = "weeks"))) + 1) %>%
    dplyr::select(RFID, week, n, minutes, CH4, CO2, O2, H2)


  weekly_df <- daily_df %>%
    dplyr::group_by(RFID, week) %>%
    dplyr::summarise(
      nDays = n(),
      nRecords = sum(n),
      TotalMin = round(sum(minutes), 2),
      CH4 = stats::weighted.mean(CH4, minutes, na.rm = TRUE),
      CO2 = stats::weighted.mean(CO2, minutes, na.rm = TRUE),
      O2 = stats::weighted.mean(O2, minutes, na.rm = TRUE),
      H2 = stats::weighted.mean(H2, minutes, na.rm = TRUE),
      .groups = "drop" # Un-group after summarizing
    ) %>%
    dplyr::filter(nDays >= param2) %>% # Filter out weeks with less than "param2" days
    dplyr::select(RFID, week, nDays, nRecords, TotalMin, CH4, CO2, O2, H2)


  ### Description of mean, sd, and CV for weekly gases
  print(paste("CH4: ", round(mean(weekly_df$CH4, na.rm = TRUE), 2), "+-", round(stats::sd(weekly_df$CH4, na.rm = TRUE), 2)))
  print(paste("CH4 CV = ", round(stats::sd(weekly_df$CH4, na.rm = TRUE) / mean(weekly_df$CH4, na.rm = TRUE) * 100, 1)))

  print(paste("CO2: ", round(mean(weekly_df$CO2, na.rm = TRUE), 2), "+-", round(stats::sd(weekly_df$CO2, na.rm = TRUE), 2)))
  print(paste("CO2 CV = ", round(stats::sd(weekly_df$CO2, na.rm = TRUE) / mean(weekly_df$CO2, na.rm = TRUE) * 100, 1)))

  print(paste("O2: ", round(mean(weekly_df$O2, na.rm = TRUE), 2), "+-", round(stats::sd(weekly_df$O2, na.rm = TRUE), 2)))
  print(paste("O2 CV = ", round(stats::sd(weekly_df$O2, na.rm = TRUE) / mean(weekly_df$O2, na.rm = TRUE) * 100, 1)))

  print(paste("H2: ", round(mean(weekly_df$H2, na.rm = TRUE), 2), "+-", round(stats::sd(weekly_df$H2, na.rm = TRUE), 2)))
  print(paste("H2 CV = ", round(stats::sd(weekly_df$H2, na.rm = TRUE) / mean(weekly_df$H2, na.rm = TRUE) * 100, 1)))


  # Return a list of data frames
  return(list(daily_data = daily_df, weekly_data = weekly_df))
}
