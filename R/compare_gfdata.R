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
#'
#' @export
#'
#' @import dplyr
#' @importFrom dplyr %>%
#' @import ggplot2
#' @import readr
#' @import readxl

utils::globalVariables(c(
  "group", "..y..", "CH4GramsPerDay.x", "CH4GramsPerDay.y"
))

compare_gfdata <- function(dailyrep, finalrep, start_date, end_date){

  # Check date format
  start_date <- ensure_date_format(start_date)
  end_date <- ensure_date_format(end_date)

  # Open daily data
  daily_data <- readr::read_csv(dailyrep)

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

  # Process data
  list_of_data <- list(daily_data, final_data)

  for (i in seq_along(list_of_data)) {
    data <- list_of_data[[i]]

    data$RFID <- gsub("^0+", "", data$RFID)

    data <- data %>%
      dplyr::filter(
        as.Date(StartTime) >= as.Date(start_date),
        as.Date(StartTime) <= as.Date(end_date),
        CH4GramsPerDay > 0
      ) %>%
      dplyr::distinct_at(vars(1:5), .keep_all = TRUE)

    data <- data[data$AirflowLitersPerSec >= 25, ]

    # Store the manipulated data back in the list_of_data
    list_of_data[[i]] <- data

    # Move the modified data back to the original data frames
    if (i == 1) {
      daily_data <- data
    } else if (i == 2) {
      final_data <- data
    }
  }

  ### Difference in number of records from initial data
  records_out_finalrep <- anti_join(daily_data, final_data,
                                    by = c("RFID",
                                           "FeederID",
                                           "StartTime",
                                           "EndTime"))
  records_out_dailyrep <- anti_join(final_data, daily_data,
                                    by = c("RFID",
                                           "FeederID",
                                           "StartTime",
                                           "EndTime"))


  ### Join daily and final data
  daily_data$group <- "D"
  final_data$group <- "F"
  all_data <- rbind(daily_data[, c(3, 2, 1, 4:8, 22)],
                    final_data[, c(1:6, 8:9, 26)])

  ### Distribution of the CH4 and CO2 for both datasets
  plot1 <- ggplot(data = all_data, aes(x = group, y = CH4GramsPerDay, fill = group)) +
    geom_boxplot() +
    stat_summary(fun = mean, geom = "text", aes(label = round(..y.., 0)), position = position_dodge(width = 0.75), vjust = -0.5, size = 4, color = "black") +
    scale_x_discrete(labels = c("D" = "Daily data", "F" = "Final report")) +
    scale_fill_manual(values = c("#9FA8DA", "#A5D6A7")) +
    theme_classic() +
    theme(
      axis.text.x = element_text(angle = 0, size = 9, family = "Times New Roman"),
      axis.text.y = element_text(angle = 0, size = 9, family = "Times New Roman"),
      legend.position = "none",
      axis.title.y = element_text(size = 15, family = "Times New Roman", face = "bold"),
      axis.title.x = element_text(size = 15, family = "Times New Roman", face = "bold")
    ) +
    labs(title = "", x = "", y = "CH4 production (g/d)") +
    coord_cartesian(ylim = c(0, 1100)) +
    scale_y_continuous(breaks = seq(0, 1100, 100))

  plot2 <- ggplot(data = all_data, aes(x = group, y = CO2GramsPerDay, fill = group)) +
    geom_boxplot() +
    stat_summary(fun = mean, geom = "text", aes(label = round(..y.., 0)), position = position_dodge(width = 0.75), vjust = -0.5, size = 4, color = "black") +
    scale_x_discrete(labels = c("D" = "Daily data", "F" = "Final report")) +
    scale_fill_manual(values = c("#9FA8DA", "#A5D6A7")) +
    theme_classic() +
    theme(
      axis.text.x = element_text(angle = 0, size = 9, family = "Times New Roman"),
      axis.text.y = element_text(angle = 0, size = 9, family = "Times New Roman"),
      legend.position = "none",
      axis.title.y = element_text(size = 15, family = "Times New Roman", face = "bold"),
      axis.title.x = element_text(size = 15, family = "Times New Roman", face = "bold")
    ) +
    labs(title = "", x = "", y = "CO2 production (g/d)") +
    coord_cartesian(ylim = c(2000, 26000)) +
    scale_y_continuous(breaks = seq(2000, 26000, 2000))

  print(plot1)
  print(plot2)

  ### Comparison of CH4 values for each dataset
  joined_data <- dplyr::inner_join(daily_data, final_data,
                                   by = c("RFID",
                                          "FeederID",
                                          "StartTime",
                                          "EndTime"))

  # Plot the scatter plot with one group's CH4 Massflow (g/d) on x-axis and the other group's CH4 Massflow (g/d) on y-axis
  plot3 <- ggplot(data = joined_data, aes(x = CH4GramsPerDay.x, y = CH4GramsPerDay.y)) +
    geom_point(size = 0.9) +
    theme_minimal() +
    labs(x = "Daily Report MeP", y = "Final Report MeP (g/d)")

  print(plot3)

}
