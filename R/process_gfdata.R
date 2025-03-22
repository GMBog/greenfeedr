#' @name process_gfdata
#' @title Process Preliminary and Finalized 'GreenFeed' Data
#'
#' @description Processes and calculates daily and weekly averages of 'GreenFeed' data.
#'     Handles data filtering, aggregation, and summarization to facilitate further analysis.
#'
#' @param data a data frame with preliminary or finalized 'GreenFeed' data
#' @param start_date a character string representing the start date of the study (format: "DD-MM-YY" or "YYYY-MM-DD")
#' @param end_date a character string representing the end date of the study (format: "DD-MM-YY" or "YYYY-MM-DD")
#' @param param1 an integer representing the number of records per day to be consider for analysis
#' @param param2 an integer representing the number of days with records per week to be consider for analysis
#' @param min_time an integer representing the minimum number of minutes for a records to be consider for analysis (default: 2 minutes)
#' @param cutoff an integer specifying the range for identifying outliers (default: 3 SD)
#'
#' @return A list of three data frames:
#'   \item{filtered_data }{data frame with filtered 'GreenFeed' data}
#'   \item{daily_data }{data frame with daily processed 'GreenFeed' data}
#'   \item{weekly_data }{data frame with weekly processed 'GreenFeed' data}
#'
#' @examples
#' file <- system.file("extdata", "StudyName_GFdata.csv", package = "greenfeedr")
#' datafile <- readr::read_csv(file)
#'
#' gf_data <- process_gfdata(
#'   data = datafile,
#'   start_date = "2024-05-13",
#'   end_date = "2024-05-25",
#'   param1 = 2,
#'   param2 = 3,
#'   min_time = 2
#' )
#' head(gf_data)
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

process_gfdata <- function(data, start_date, end_date,
                           param1, param2, min_time = 2, cutoff = 3) {
  # Check date format
  start_date <- ensure_date_format(start_date)
  end_date <- ensure_date_format(end_date)

  # Ensure param1 and param2 are defined
  if (missing(param1) || missing(param2)) {
    stop("Please define 'param1' (minimum records per day), 'param2' (minimum days per week), and min_time (minimum minutes per visit)")
  } else {
    message(paste("Using param1 =", param1, ", param2 =", param2, ", min_time =", min_time))
  }

  # Function to read and process each file
  process_data <- function(data) {
    if (ncol(data) >= 25) { # Preliminary data always have 25 columns or more
      names(data)[1:14] <- c(
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

      data <- data %>%
        ## Remove leading zeros from RFID column to match with IDs
        dplyr::mutate(RFID = gsub("^0+", "", RFID)) %>%
        ## Remove records with unknown ID and airflow below 25 l/s (threshold value recommended by C-Lock Inc.)
        dplyr::filter(
          RFID != "unknown",
          AirflowLitersPerSec >= 25
        ) %>%
        ## Mark records with invalid gas values as NA, instead of removing them
        dplyr::mutate(
          CH4GramsPerDay = ifelse(CH4GramsPerDay <= 0, NA, CH4GramsPerDay),
          CO2GramsPerDay = ifelse(CO2GramsPerDay <= 0, NA, CO2GramsPerDay),
          O2GramsPerDay = ifelse(O2GramsPerDay <= 0, NA, O2GramsPerDay),
          H2GramsPerDay = ifelse(H2GramsPerDay <= 0, NA, H2GramsPerDay)
        ) %>%
        ## Change format of 'StartTime' and 'GoodDataDuration' columns
        dplyr::mutate(
          day = as.Date(StartTime),
          ## Suppress warnings from coercion issues with GoodDataDuration
          GoodDataDuration = suppressWarnings(
            case_when(
              # HH:MM:SS format
              nchar(GoodDataDuration) == 8 ~ as.numeric(substr(GoodDataDuration, 1, 2)) * 60 +
                as.numeric(substr(GoodDataDuration, 4, 5)) +
                as.numeric(substr(GoodDataDuration, 7, 8)) / 60,
              # YYYY-MM-DD HH:MM:SS format
              nchar(GoodDataDuration) > 8 ~ as.numeric(substr(GoodDataDuration, 12, 13)) * 60 +
                as.numeric(substr(GoodDataDuration, 15, 16)) +
                as.numeric(substr(GoodDataDuration, 18, 19)) / 60,
              TRUE ~ NA_real_
            )
          ),
          GoodDataDuration = round(GoodDataDuration, 2)
        )
    } else { # Finalized data always have less than 21 columns
      names(data) <- c(
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

      data <- data %>%
        ## Remove leading zeros from RFID column to match with IDs
        dplyr::mutate(RFID = gsub("^0+", "", RFID)) %>%
        ## Remove records with unknown ID and airflow below 25 l/s (threshold value recommended by C-Lock Inc.)
        dplyr::filter(
          RFID != "unknown",
          AirflowLitersPerSec >= 25
        ) %>%
        ## Mark records with invalid gas values as NA, instead of removing them
        dplyr::mutate(
          CH4GramsPerDay = ifelse(CH4GramsPerDay <= 0, NA, CH4GramsPerDay),
          CO2GramsPerDay = ifelse(CO2GramsPerDay <= 0, NA, CO2GramsPerDay),
          O2GramsPerDay = ifelse(O2GramsPerDay <= 0, NA, O2GramsPerDay),
          H2GramsPerDay = ifelse(H2GramsPerDay <= 0, NA, H2GramsPerDay)
        ) %>%
        ## Change columns format
        dplyr::mutate(
          ## Create a column with date
          day = parse_date_time(sub(" .*", "", StartTime),
            orders = c("Y-m-d", "m/d/y", "d/m/y", "y/m/d", "d-b-Y", "b/d/Y", "m/d/Y", "Y/m/d", "Ymd", "mdy")
          ),
          ## Extract hours, minutes, and seconds from GoodDataDuration
          GoodDataDuration = round(
            as.numeric(substr(GoodDataDuration, 1, 2)) * 60 + # Hours to minutes
              as.numeric(substr(GoodDataDuration, 4, 5)) + # Minutes
              as.numeric(substr(GoodDataDuration, 7, 8)) / 60, # Seconds to minutes
            2
          ),
          ## Create a column that contains daytime (extract the time part from StartTime (HH:MM:SS))
          HourOfDay = round(
            as.numeric(format(as.POSIXct(StartTime, format = "%m/%d/%y %H:%M"), "%H")) + # Extract hours
              as.numeric(format(as.POSIXct(StartTime, format = "%m/%d/%y %H:%M"), "%M")) / 60, # Extract minutes and convert to fraction of an hour
            2
          )
        )
    }
  }

  # Combine files into one data frame
  df <- process_data(data)

  # Filtering data
  df <- df %>%
    ## Filter by conditions where CH4 and CO2 must be within range, but allow O2 and H2 to be NA
    dplyr::filter(
      dplyr::if_all(
        c(CH4GramsPerDay, CO2GramsPerDay),
        ~ filter_within_range(.x, cutoff)
      ),

      ## Retain records with valid CH4 and CO2, even if O2 or H2 are NA
      !is.na(CH4GramsPerDay) & !is.na(CO2GramsPerDay),

      ## Filter by minimum time of records
      GoodDataDuration >= min_time,

      ## Filter by start and end of study
      day >= start_date & day <= end_date
    )


  # Calculation of average daily gas production
  daily_df <- df %>%
    ## Group by animal and date
    dplyr::group_by(RFID, day) %>%
    ## Compute weighted mean of all gases
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
    ## Filter by number of records per day (=param1)
    dplyr::filter(n >= param1) %>%
    ## Compute week based on the minimum date
    dplyr::mutate(week = floor(as.numeric(difftime(day, as.Date(start_date), units = "weeks"))) + 1) %>%
    ## Select columns
    dplyr::select(RFID, week, day, n, minutes, CH4GramsPerDay, CO2GramsPerDay, O2GramsPerDay, H2GramsPerDay)

  # Calculation of average weekly gas production
  weekly_df <- daily_df %>%
    ## Group by animal and week
    dplyr::group_by(RFID, week) %>%
    ## Compute number of days with records, total records and minutes, and the weighted mean of all gases
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
    ## Filter by number of days with records (=param2)
    dplyr::filter(nDays >= param2) %>%
    ## Select columns
    dplyr::select(RFID, week, nDays, nRecords, TotalMin, CH4GramsPerDay, CO2GramsPerDay, O2GramsPerDay, H2GramsPerDay)


  # Description of mean, sd, and CV for weekly gases
  message(paste0("CH4: ", round(mean(weekly_df$CH4GramsPerDay, na.rm = TRUE), 2), " +- ", round(stats::sd(weekly_df$CH4GramsPerDay, na.rm = TRUE), 2)))
  message(paste0("CH4 CV = ", round(stats::sd(weekly_df$CH4GramsPerDay, na.rm = TRUE) / mean(weekly_df$CH4GramsPerDay, na.rm = TRUE) * 100, 1), "%"))

  message(paste0("CO2: ", round(mean(weekly_df$CO2GramsPerDay, na.rm = TRUE), 2), " +- ", round(stats::sd(weekly_df$CO2GramsPerDay, na.rm = TRUE), 2)))
  message(paste0("CO2 CV = ", round(stats::sd(weekly_df$CO2GramsPerDay, na.rm = TRUE) / mean(weekly_df$CO2GramsPerDay, na.rm = TRUE) * 100, 1), "%"))

  message(paste0("O2: ", round(mean(weekly_df$O2GramsPerDay, na.rm = TRUE), 2), " +- ", round(stats::sd(weekly_df$O2GramsPerDay, na.rm = TRUE), 2)))
  message(paste0("O2 CV = ", round(stats::sd(weekly_df$O2GramsPerDay, na.rm = TRUE) / mean(weekly_df$O2GramsPerDay, na.rm = TRUE) * 100, 1), "%"))

  message(paste0("H2: ", round(mean(weekly_df$H2GramsPerDay, na.rm = TRUE), 2), " +- ", round(stats::sd(weekly_df$H2GramsPerDay, na.rm = TRUE), 2)))
  message(paste0("H2 CV = ", round(stats::sd(weekly_df$H2GramsPerDay, na.rm = TRUE) / mean(weekly_df$H2GramsPerDay, na.rm = TRUE) * 100, 1), "%"))


  # Return a list of data frames
  return(list(
    filtered_data = df,
    daily_data = daily_df,
    weekly_data = weekly_df
  ))

  message("List with data sets created.")
}
