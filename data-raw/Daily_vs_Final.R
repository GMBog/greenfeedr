# Script to evaluate the final report from GreenFeed
# Written by Guillermo Martinez Boggio


rm(list = ls()) # initialization

# Choose one of the experiments of the following list. If it's not on the list, then include it (Experiment name, Start and End Dates, and units)
list_of_experiments <- list(KFK21 = list(
  StartDate = "2024-02-02", EndDate = "2024-03-29",
  Units = list("323" = 35, "324" = 35, "527" = 35),
  fileEID_path = "~/GreenFeed_UW/Methane/KFK21/KFK21_EID.csv",
  FinalData_path = "~/GreenFeed_UW/Methane/KFK21/GreenFeed_Summarized_Data_323_324_527.xlsx"
))


user_choice <- 1

selected_experiment <- names(list_of_experiments)[user_choice]
Exp_PERIOD <- paste(list_of_experiments[[selected_experiment]]["StartDate"], list_of_experiments[[selected_experiment]]["EndDate"], sep = "_")

UNIT <- names(list_of_experiments[[selected_experiment]][["Units"]])


# Read cow's ID table included in the Experiment

file_path <- list_of_experiments[[selected_experiment]][["fileEID_path"]]
if (tolower(tools::file_ext(file_path)) == "csv") {
  CowsInExperiment <- read_table(file_path, col_types = cols(FarmName = col_character(), EID = col_character()))
} else if (tolower(tools::file_ext(file_path)) %in% c("xls", "xlsx")) {
  CowsInExperiment <- read_excel(file_path, col_types = c("text", "text", "numeric", "text"))
} else {
  stop("Unsupported file format.")
}


# Comparing the daily data and the final report from GreenFeed units

## Read daily data
# daily_report <- data.frame()
# for (unit in UNIT){
#  file_path <- paste0("~/GreenFeed_UW/Methane/", selected_experiment, "/", selected_experiment, "_", unit,".txt")
#  data <- read_csv(file_path, skip = 1)
#  daily_report <- rbind(daily_report, data)
# }

file_path <- paste0("~/GreenFeed_UW/Methane/", selected_experiment, "/", selected_experiment, "_GFdata.xlsx")
daily_report <- read_excel(file_path, col_types = c(rep("text", 6), rep("numeric", 4), "text", "numeric", rep("text", 9)))

## Read final report
final_report <- read_excel(list_of_experiments[[selected_experiment]][["FinalData_path"]])
colnames(final_report)[1:14] <- c("RFID", "AnimalName", "FeederID", colnames(daily_report)[4:6], "HourOfDay", colnames(daily_report)[7:13])


list_of_data <- list(daily_report, final_report)

for (i in seq_along(list_of_data)) {
  data <- list_of_data[[i]]

  data$RFID <- gsub("^0+", "", data$RFID)

  selected_experiment <- user_choice # Replace with the index of the selected experiment

  data <- data %>%
    dplyr::filter(
      as.Date(StartTime) >= unlist(list_of_experiments[[selected_experiment]]["StartDate"]),
      as.Date(StartTime) <= unlist(list_of_experiments[[selected_experiment]]["EndDate"]),
      RFID %in% CowsInExperiment$EID,
      CH4GramsPerDay > 0
    ) %>%
    dplyr::distinct_at(vars(1:5), .keep_all = TRUE)

  data <- data[data$AirflowLitersPerSec >= 25, ]

  # Store the manipulated data back in the list_of_data
  list_of_data[[i]] <- data

  # Move the modified data back to the original data frames
  if (i == 1) {
    daily_report <- data
  } else if (i == 2) {
    final_report <- data
  }
}
rm(data)


### Difference in number of records from initial data
records_out_finalrep <- anti_join(daily_report, final_report, by = c("RFID", "FeederID", "StartTime", "EndTime"))
records_out_dailyrep <- anti_join(final_report, daily_report, by = c("RFID", "FeederID", "StartTime", "EndTime"))

### Join daily and final data
daily_report$group <- "D"
final_report$group <- "F"
all_data <- rbind(daily_report[, c(3, 2, 1, 4:8, 22)], final_report[, c(1:6, 8:9, 26)])

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


tiff("~/Downloads/FigF1.tiff", units = "cm", width = 25, height = 12, res = 300)

combined_plot <- plot1 + plot2
combined_plot

dev.off()

### Comparison of CH4 values for each dataset
joined_data <- inner_join(daily_report, final_report, by = c("RFID", "FeederID", "StartTime", "EndTime"))

# Plot the scatter plot with one group's CH4 Massflow (g/d) on x-axis and the other group's CH4 Massflow (g/d) on y-axis
ggplot(data = joined_data, aes(x = CH4GramsPerDay.x, y = CH4GramsPerDay.y)) +
  geom_point(size = 0.9) +
  # geom_smooth(span = 0.8) +
  theme_minimal() +
  labs(x = "Daily Report MeP", y = "Final Report MeP (g/d)")
