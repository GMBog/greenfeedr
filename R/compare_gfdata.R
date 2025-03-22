#' @name compare_gfdata
#' @title Compare Preliminary and Finalized 'GreenFeed' Data
#'
#' @description Compare preliminary and finalized 'GreenFeed' data.
#'
#' @param prelimrep a data frame with preliminary 'GreenFeed' data
#' @param finalrep a data frame with finalized 'GreenFeed' data
#' @param start_date a character string representing the start date of the study (format: "DD-MM-YY" or "YYYY-MM-DD")
#' @param end_date a character string representing the end date of the study (format: "DD-MM-YY" or "YYYY-MM-DD")
#'
#' @return Data frame including records removed from preliminary and final reports
#'
#' @examples
#' # Datasets with preliminary and finalized GreenFeed data
#' prelimrep <- system.file("extdata", "StudyName_GFdata.csv", package = "greenfeedr")
#' finalrep <- system.file("extdata", "StudyName_FinalReport.xlsx", package = "greenfeedr")
#'
#' data <- compare_gfdata(
#'   prelimrep,
#'   finalrep,
#'   start_date = "2024-05-13",
#'   end_date = "2024-05-20"
#' )
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

compare_gfdata <- function(prelimrep, finalrep, start_date, end_date) {
  # Check date format
  start_date <- ensure_date_format(start_date)
  end_date <- ensure_date_format(end_date)

  # Open preliminary data
  prelim_data <- readr::read_csv(prelimrep, show_col_types = FALSE)

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
  list_of_data <- list(prelim_data, final_data)

  # Process data
  for (i in seq_along(list_of_data)) {
    data <- list_of_data[[i]]
    data <- data %>%
      # Remove leading zeros from RFID column to match with IDs
      dplyr::mutate(RFID = gsub("^0+", "", RFID)) %>%
      # Check format of Date
      dplyr::mutate(
        StartTime = if (is.character(StartTime)) as.POSIXct(StartTime, format = "%m/%d/%y %H:%M") else StartTime,
        EndTime = if (is.character(EndTime)) as.POSIXct(EndTime, format = "%m/%d/%y %H:%M") else EndTime
      ) %>%
      # Filter out records before and after study dates, NULL records, and low airflow
      dplyr::filter(
        as.Date(StartTime) >= as.Date(start_date),
        as.Date(StartTime) <= as.Date(end_date),
        CH4GramsPerDay > 0,
        AirflowLitersPerSec >= 25
      ) %>%
      # Remove duplicate records
      dplyr::distinct_at(vars(1:5), .keep_all = TRUE)

    # Store the processed data back in the list_of_data
    list_of_data[[i]] <- data

    # Move the processed data back to the original data frames
    if (i == 1) {
      prelim_data <- data
    } else if (i == 2) {
      final_data <- data
    }
  }

  # Difference in number of records from initial data
  records_out_finalrep <- dplyr::anti_join(prelim_data, final_data,
    by = c(
      "RFID",
      "FeederID",
      "StartTime",
      "EndTime"
    )
  )

  message("During the data processing ", nrow(records_out_finalrep), " records were removed from the finalized data")

  records_out_prelimrep <- dplyr::anti_join(final_data, prelim_data,
    by = c(
      "RFID",
      "FeederID",
      "StartTime",
      "EndTime"
    )
  )

  message("During the data processing ", nrow(records_out_prelimrep), " records were added to the finalized data")

  # Join preliminary and final data
  prelim_data$group <- "D"
  final_data$group <- "F"
  all_data <- rbind(
    prelim_data[, c(3, 2, 1, 4:8, 22)],
    final_data[, c(1:6, 8:9, 26)]
  )

  # Distribution of the CH4 and CO2 for both datasets
  plot1 <- ggplot(data = all_data, aes(x = group, y = CH4GramsPerDay, fill = group)) +
    geom_boxplot() +
    stat_summary(
      fun = mean, geom = "text",
      aes(label = round(after_stat(y), 0)),
      position = position_dodge(width = 0.75),
      vjust = -0.6, size = 4, color = "black"
    ) +
    scale_x_discrete(labels = c("D" = "Prelim data", "F" = "Final report")) +
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
    stat_summary(
      fun = mean, geom = "text",
      aes(label = round(after_stat(y), 0)),
      position = position_dodge(width = 0.75),
      vjust = -0.9, size = 4, color = "black"
    ) +
    scale_x_discrete(labels = c(
      "D" = "Prelim data",
      "F" = "Final report"
    )) +
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
  joined_data <- dplyr::inner_join(prelim_data, final_data,
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
    out_prelim = records_out_prelimrep
  ))
}
