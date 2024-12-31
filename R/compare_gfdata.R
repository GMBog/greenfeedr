#' @name compare_gfdata
#' @title Compare Daily and Final 'GreenFeed' Data
#'
#' @description Compare daily and finalized 'GreenFeed' data.
#'
#' @param dailyrep a data frame with daily 'GreenFeed' data
#' @param finalrep a data frame with finalized 'GreenFeed' data
#' @param start_date a character string representing the start date of the study (format: "mm/dd/yyyy")
#' @param end_date a character string representing the end date of the study (format: "mm/dd/yyyy")
#'
#' @return Data frame including records removed from daily and final reports.
#'
#' @examples
#' start_date <- "2024-05-13"
#' end_date <- "2024-05-20"
#'
#' dailyrep <- system.file("extdata", "StudyName_GFdata.csv", package = "greenfeedr")
#' finalrep <- system.file("extdata", "StudyName_FinalReport.xlsx", package = "greenfeedr")
#'
#' data <- compare_gfdata(dailyrep,
#'                       finalrep,
#'                       start_date,
#'                       end_date)
#'
#' @export compare_gfdata
#'
#' @import dplyr
#' @importFrom dplyr %>%
#' @import ggplot2
#' @import readr
#' @import readxl

utils::globalVariables(c(
  "group", "CH4GramsPerDay.x", "CH4GramsPerDay.y", "y"
))

compare_gfdata <- function(dailyrep, finalrep, start_date, end_date) {
  # Check date format
  start_date <- ensure_date_format(start_date)
  end_date <- ensure_date_format(end_date)

  # Open daily data
  daily_data <- readr::read_csv(dailyrep, show_col_types = FALSE)

  # Open final data
  final_data <- readxl::read_excel(finalrep)
  names(final_data)[1:14] <- c(
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

  # List of datasets
  list_of_data <- list(daily_data, final_data)

  # Process data
  for (i in seq_along(list_of_data)) {
    data <- list_of_data[[i]]
    data <- data %>%
      ## Remove leading zeros from RFID column to match with IDs
      dplyr::mutate(RFID = gsub("^0+", "", RFID)) %>%
      ## Change date format if it is character
      dplyr::mutate(
        StartTime = ifelse(
          is.character(StartTime),
          as.Date(as.POSIXct(StartTime, format = "%m/%d/%y")),
          as.Date(StartTime, origin = "1899-12-30") # For Excel date format
        ),
        EndTime = ifelse(
          is.character(EndTime),
          as.Date(as.POSIXct(EndTime, format = "%m/%d/%y")),
          as.Date(EndTime, origin = "1899-12-30") # For Excel date format
        )
      ) %>%
      ## Filter out records before and after study dates, NULL records, and low airflow (threshold value recommended by C-Lock Inc.)
      dplyr::filter(
        as.Date(StartTime) >= as.Date(start_date),
        as.Date(StartTime) <= as.Date(end_date),
        CH4GramsPerDay > 0,
        AirflowLitersPerSec >= 25
      ) %>%
      ## Remove duplicate records
      dplyr::distinct_at(vars(1:5), .keep_all = TRUE)

    # Store the processed data back in the list_of_data
    list_of_data[[i]] <- data

    # Move the modified data back to the original data frames
    if (i == 1) {
      daily_data <- data
    } else if (i == 2) {
      final_data <- data
    }
  }

  # Difference in number of records from initial data
  records_out_finalrep <- anti_join(daily_data, final_data,
    by = c(
      "RFID",
      "FeederID",
      "StartTime",
      "EndTime"
    )
  )

  message("During the data processing ", nrow(records_out_finalrep), " records were removed from the finalized data")

  records_out_dailyrep <- anti_join(final_data, daily_data,
    by = c(
      "RFID",
      "FeederID",
      "StartTime",
      "EndTime"
    )
  )

  message("During the data processing ", nrow(records_out_dailyrep), " records were added to the finalized data")

  # Join daily and final data
  daily_data$group <- "D"
  final_data$group <- "F"
  all_data <- rbind(
    daily_data[, c(3, 2, 1, 4:8, 22)],
    final_data[, c(1:6, 8:9, 26)]
  )

  # Distribution of the CH4 and CO2 for both datasets
  plot1 <- ggplot(data = all_data, aes(x = group, y = CH4GramsPerDay, fill = group)) +
    geom_boxplot() +
    stat_summary(fun = mean, geom = "text",
                 aes(label = round(after_stat(y), 0)),
                 position = position_dodge(width = 0.75),
                 vjust = -0.6, size = 4, color = "black") +
    scale_x_discrete(labels = c("D" = "Daily data", "F" = "Final report")) +
    scale_fill_manual(values = c("#9FA8DA", "#A5D6A7")) +
    theme_classic() +
    theme(
      axis.text.x = element_text(angle = 0, size = 9),
      axis.text.y = element_text(angle = 0, size = 9),
      axis.title.y = element_text(size = 10, face = "bold"),
      axis.title.x = element_text(size = 10, face = "bold"),
      legend.position = "none",
    ) +
    labs(y = "CH4 production (g/d)")

  plot2 <- ggplot(data = all_data, aes(x = group, y = CO2GramsPerDay, fill = group)) +
    geom_boxplot() +
    stat_summary(fun = mean, geom = "text",
                 aes(label = round(after_stat(y), 0)),
                 position = position_dodge(width = 0.75),
                 vjust = -0.9, size = 4, color = "black") +
    scale_x_discrete(labels = c("D" = "Daily data",
                                "F" = "Final report")) +
    scale_fill_manual(values = c("#9FA8DA", "#A5D6A7")) +
    theme_classic() +
    theme(
      axis.text.x = element_text(angle = 0, size = 9),
      axis.text.y = element_text(angle = 0, size = 9),
      axis.title.y = element_text(size = 10, face = "bold"),
      axis.title.x = element_text(size = 10, face = "bold"),
      legend.position = "none"
    ) +
    labs(y = "CO2 production (g/d)")

  print(plot1)
  print(plot2)

  # Comparison of CH4 values for each dataset
  joined_data <- dplyr::inner_join(daily_data, final_data,
    by = c(
      "RFID",
      "FeederID",
      "StartTime",
      "EndTime"
    )
  )

  # Return a list of data frames
  return(list(
    out_final = records_out_finalrep,
    out_daily = records_out_dailyrep
  ))

}
