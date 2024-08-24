
# Reports and Figures for JDS Communications
# Example with dairy cow data

load_all()

## Create the daily report
dailyrep(user = "wattiaux",
         pass = "greenfeed",
         exp = "Example data",
         unit = 579,
         start_date = "2024-01-22",
         end_date = "2024-02-18",
         save_dir = "/Users/GuillermoMartinez/Downloads/",
         plot_opt = c("CH4","CO2"),
         RFID_file = "/Users/GuillermoMartinez/GreenFeed_UW/Methane/Studies/FP695/FP695_EID.csv"
         )

## Create the final report
finalrep(exp = "Example data",
         unit = 579,
         start_date = "2024-01-22",
         end_date = "2024-03-08",
         save_dir = "/Users/GuillermoMartinez/Downloads/",
         final_report = "/Users/GuillermoMartinez/GreenFeed_UW/Methane/Studies/FP695/GreenFeed_Summarized_Data_579_2024_01_22_to_2024_03_08.xlsx",
         plot_opt = c("All"),
         RFID_file = "/Users/GuillermoMartinez/GreenFeed_UW/Methane/Studies/FP695/FP695_EID.csv"
         )


## Figures ######################################################################

library(ggplot2)
library(patchwork)

#Figure 1: in PPT
#Figure 2: Final report plots
##First run the function finalrep by hand and remove outliers for methane (-999)

df <- df[df$CH4GramsPerDay != -999,]
df <- df[df$H2GramsPerDay != -999,]

##Change cowID to include in plots
newIDs <- paste0("Cow", 1:32)
newIDs

#A) Total number of records per animal
plotA <- df %>%
  dplyr::mutate(day = as.Date(EndTime)) %>%
  dplyr::group_by(!!sym(group_var), day) %>%
  dplyr::summarise(
    n = n(),
    daily_CH4 = weighted.mean(CH4GramsPerDay, GoodDataDuration, na.rm = TRUE)
  ) %>%
  dplyr::group_by(!!sym(group_var)) %>%
  dplyr::summarise(
    n = sum(n),
    daily_CH4 = mean(daily_CH4, na.rm = TRUE)
  ) %>%
  ggplot(aes(x = factor(!!sym(group_var), levels = farmname_order), y = n)) +
  geom_bar(stat = "identity", position = position_dodge()) +
  labs(
    title = "A)", x = "", y = "Total Records"
  ) +
  scale_x_discrete(labels = newIDs) +  # Apply custom x-axis labels
  theme_classic() +
  theme(
    plot.title = element_text(size = 11, face = "bold", family = "Times New Roman"),
    axis.text.x = element_text(angle = 45, hjust = 1.05, size = 5, family = "Times New Roman"),
    axis.text.y = element_text(angle = 0, size = 6, family = "Times New Roman"),
    axis.title.y = element_text(size = 8, face = "bold", family = "Times New Roman"),
    legend.position = "none") +
  geom_text(aes(label = n), vjust = -0.5, color = "black",
            position = position_dodge(width = 0.9), size = 1.1) +
  coord_cartesian(ylim = c(0, 200)) +
  scale_y_continuous(breaks = seq(0, 200, 20), expand = c(0.02,0))


#B) Percentage of Total Records
plotB <- df %>%
  dplyr::mutate(AMPM = case_when(
    HourOfDay >= 22 ~ "10PM-4AM",
    HourOfDay < 4 ~ "10PM-4AM",
    HourOfDay >= 4 & HourOfDay < 10 ~ "4AM-10AM",
    HourOfDay >= 10 & HourOfDay < 16 ~ "10AM-4PM",
    HourOfDay >= 16 & HourOfDay < 22 ~ "4PM-10PM",
    TRUE ~ NA_character_
  )) %>%
  dplyr::group_by(!!sym(group_var), AMPM) %>%
  dplyr::summarise(n = n()) %>%
  ggplot(aes(
    x = factor(!!sym(group_var), levels = farmname_order), y = n,
    fill = factor(AMPM, levels = c("10PM-4AM", "4AM-10AM", "10AM-4PM", "4PM-10PM"))
  )) +
  geom_bar(stat = "identity", position = "fill") +
  labs(
    title = "B)",
    x = "",
    y = "Percentage of Total Records",
    fill = "Time-Windows:"
  ) +
  scale_x_discrete(labels = newIDs) +  # Apply custom x-axis labels
  theme_classic() +
  theme(
    plot.title = element_text(size = 11, face = "bold", family = "Times New Roman"),
    axis.text.x = element_text(angle = 45, hjust = 1.05, size = 5, family = "Times New Roman"),
    axis.text.y = element_text(angle = 0, size = 6, family = "Times New Roman"),
    axis.title.y = element_text(size = 8, face = "bold", family = "Times New Roman"),
    legend.title = element_text(size = 7, family = "Times New Roman"),
    legend.text = element_text(size = 6, family = "Times New Roman"),
    legend.position = "top",
    legend.key.size = unit(0.2, "cm"),  # Adjust size of legend keys
    legend.box.spacing = unit(0, "cm"),  # Reduce space between legend and plot
    legend.spacing.x = unit(0.5, "cm"),
    legend.spacing.y = unit(0.5, "cm")) +
  scale_fill_brewer(palette = "BrBG") +
  scale_y_continuous(breaks = c(0, 0.25, 0.50, 0.75, 1),
                     labels = c("0%", "25%", "50%", "75%", "100%"), expand = c(0.01, 0.01))


#C) Gas distribution thorughout the day
generate_combined_plot <- function(df, plot_opt) {
  # Convert to lowercase to avoid case sensitivity issues
  plot_opt <- tolower(plot_opt)

  if ("all" %in% plot_opt) {
    options_selected <- c("ch4", "o2", "co2", "h2")
  } else {
    options_selected <- plot_opt
  }

  # Normalize the data
  df_normalized <- df %>%
    dplyr::mutate(
      Normalized_CH4 = scale(CH4GramsPerDay),
      Normalized_CO2 = scale(CO2GramsPerDay),
      Normalized_O2 = scale(O2GramsPerDay),
      Normalized_H2 = scale(H2GramsPerDay)
    )

  # Create a base plot
  combined_plot <- ggplot(df_normalized[df_normalized$HourOfDay <= 23, ], aes(x = HourOfDay)) +
    theme_classic() +
    theme(
      plot.title = element_text(size = 11, face = "bold", family = "Times New Roman"),
      axis.text.x = element_text(angle = 45, hjust = 1.05, size = 5, family = "Times New Roman"),
      axis.text.y = element_text(angle = 0, size = 6, family = "Times New Roman"),
      axis.title.y = element_text(size = 8, face = "bold", family = "Times New Roman"),
      legend.title = element_text(size = 7, family = "Times New Roman"),
      legend.text = element_text(size = 6, family = "Times New Roman"),
      legend.position = "top",
      legend.key.size = unit(0.2, "cm"),  # Adjust size of legend keys
      legend.box.spacing = unit(0, "cm"),  # Reduce space between legend and plot
      legend.spacing.x = unit(0.5, "cm"),
      legend.spacing.y = unit(0.5, "cm")
    ) +
    labs(
      title = "C)",
      x = "",
      y = "Normalized Gas Value",
      color = "Gas type:"
    ) +
    scale_x_continuous(
      breaks = seq(0, 23),
      labels = c(
        "12 AM", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11",
        "12 PM", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"
      )
    )

  # Initialize empty lists for points and smooth lines
  points_list <- list()
  smooth_list <- list()

  # Loop through selected options to add points and smooth lines
  for (gas in options_selected) {
    if (gas == "ch4") {
      points_list <- c(points_list, list(geom_point(aes(y = Normalized_CH4), color = "#E0E0E0")))
      smooth_list <- c(smooth_list, list(geom_smooth(aes(y = Normalized_CH4, color = "CH4"), se = FALSE)))
    }
    if (gas == "co2") {
      points_list <- c(points_list, list(geom_point(aes(y = Normalized_CO2), color = "#E0E0E0")))
      smooth_list <- c(smooth_list, list(geom_smooth(aes(y = Normalized_CO2, color = "CO2"), se = FALSE)))
    }
    if (gas == "o2") {
      points_list <- c(points_list, list(geom_point(aes(y = Normalized_O2), color = "#E0E0E0")))
      smooth_list <- c(smooth_list, list(geom_smooth(aes(y = Normalized_O2, color = "O2"), se = FALSE)))
    }
    if (gas == "h2") {
      points_list <- c(points_list, list(geom_point(aes(y = Normalized_H2), color = "#E0E0E0")))
      smooth_list <- c(smooth_list, list(geom_smooth(aes(y = Normalized_H2, color = "H2"), se = FALSE)))
    }
  }

  # Add points and smooth lines to the combined plot
  combined_plot <- combined_plot + do.call("list", points_list)
  combined_plot <- combined_plot + do.call("list", smooth_list)

  # Check for valid options
  valid_options <- c("all", "ch4", "co2", "o2", "h2")
  if (!all(options_selected %in% valid_options)) {
    stop("Invalid plot option selected.")
  }

  return(combined_plot)
}
plotC <- generate_combined_plot(df, plot_opt)


#D) Variability of methane production per animal
plotD <- df %>%
  dplyr::mutate(day = as.Date(EndTime)) %>%
  dplyr::group_by(!!sym(group_var), day) %>%
  dplyr::summarise(daily_CH4 = weighted.mean(CH4GramsPerDay, GoodDataDuration, na.rm = TRUE)) %>%
  ggplot(aes(x = reorder(!!sym(group_var), -daily_CH4), y = daily_CH4, color = daily_CH4)) +
    geom_boxplot(fatten = NULL, outlier.shape = NA) +
    stat_summary(
      fun = mean, geom = "errorbar",
      aes(ymax = ..y.., ymin = ..y..), width = 0.75, size = 0.7,
      color = "black", linetype = "solid"
    ) +
    labs(
      title = "D)",
      x = "",
      y = "Methane emissions (g/d)"
    ) +
  scale_x_discrete(labels = newIDs) +  # Apply custom x-axis labels
  theme_classic() +
  theme(
    plot.title = element_text(size = 11, face = "bold", family = "Times New Roman"),
    axis.text.x = element_text(angle = 45, hjust = 1.05, size = 5, family = "Times New Roman"),
    axis.text.y = element_text(angle = 0, size = 6, family = "Times New Roman"),
    axis.title.y = element_text(size = 8, face = "bold", family = "Times New Roman"),
    legend.title = element_text(size = 7, family = "Times New Roman"),
    legend.text = element_text(size = 6, family = "Times New Roman")
  ) +
  coord_cartesian(ylim = c(0, 800)) + scale_y_continuous(breaks = seq(0, 800, 100))


tiff("~/Downloads/Figure2.tiff", units="cm", width=20, height=13, res=300)

combined_plot <- (plotA | plotB) / (plotC | plotD)
combined_plot

dev.off()

#################################################################################


## Process all data from the study
data <- process_gfdata(file = "/Users/GuillermoMartinez/GreenFeed_UW/Methane/Studies/FP695/GreenFeed_Summarized_Data_579_2024_01_22_to_2024_03_08.xlsx",
                       input_type = "final",
                       start_date = "2024-01-22",
                       end_date = "2024-03-08",
                       param1 = 2,
                       param2 = 4,
                       min_time = 2
                       )


library(purrr)
library(dplyr)
library(openxlsx)

# Define the sequences for i, j, and k
i <- seq(1, 3)
j <- seq(3, 7)
k <- seq(2, 5)

# Generate all combinations of i, j, and k
param_combinations <- expand.grid(param1 = i, param2 = j, min_time = k)

# Function to call process_gfdata and extract relevant information
process_and_summarize <- function(param1, param2, min_time) {
  data <- process_gfdata(
    file = "/Users/GuillermoMartinez/GreenFeed_UW/Methane/Studies/FP695/GreenFeed_Summarized_Data_579_2024_01_22_to_2024_03_08.xlsx",
    input_type = "final",
    start_date = "2024-01-22",
    end_date = "2024-03-08",
    param1 = param1,
    param2 = param2,
    min_time = min_time
  )

  # Extract daily_data and weekly_data
  daily_data <- data$daily_data
  weekly_data <- data$weekly_data

  # Calculate the required metrics
  records_d <- nrow(daily_data)
  cows_d <- length(unique(daily_data$RFID))

  mean_dCH4 <- mean(daily_data$CH4GramsPerDay, na.rm = TRUE)
  sd_dCH4 <- sd(daily_data$CH4GramsPerDay, na.rm = TRUE)
  CV_dCH4 <- sd(daily_data$CH4GramsPerDay, na.rm = TRUE) / mean(daily_data$CH4GramsPerDay, na.rm = TRUE)
  mean_dCO2 <- mean(daily_data$CO2GramsPerDay, na.rm = TRUE)
  sd_dCO2 <- sd(daily_data$CO2GramsPerDay, na.rm = TRUE)
  CV_dCO2 <- sd(daily_data$CO2GramsPerDay, na.rm = TRUE) / mean(daily_data$CO2GramsPerDay, na.rm = TRUE)

  records_w <- nrow(weekly_data)
  cows_w <- length(unique(weekly_data$RFID))

  mean_wCH4 <- mean(weekly_data$CH4GramsPerDay, na.rm = TRUE)
  sd_wCH4 <- sd(weekly_data$CH4GramsPerDay, na.rm = TRUE)
  CV_wCH4 <- sd(weekly_data$CH4GramsPerDay, na.rm = TRUE) / mean(weekly_data$CH4GramsPerDay, na.rm = TRUE)
  mean_wCO2 <- mean(weekly_data$CO2GramsPerDay, na.rm = TRUE)
  sd_wCO2 <- sd(weekly_data$CO2GramsPerDay, na.rm = TRUE)
  CV_wCO2 <- sd(weekly_data$CO2GramsPerDay, na.rm = TRUE) / mean(weekly_data$CO2GramsPerDay, na.rm = TRUE)

  # Return a summary row
  return(data.frame(
    param1 = param1,
    param2 = param2,
    min_time = min_time,

    records_d = records_d,
    cows_d = cows_d,
    mean_dCH4 = round(mean_dCH4, 1),
    sd_dCH4 = round(sd_dCH4, 1),
    CV_dCH4 = round(CV_dCH4, 2),
    mean_dCO2 = round(mean_dCO2, 1),
    sd_dCO2 = round(sd_dCO2, 1),
    CV_dCO2 = round(CV_dCO2, 2),

    records_w = records_w,
    cows_w = cows_w,
    mean_wCH4 = round(mean_wCH4, 1),
    sd_wCH4 = round(sd_wCH4, 1),
    CV_wCH4 = round(CV_wCH4, 2),
    mean_wCO2 = round(mean_wCO2, 1),
    sd_wCO2 = round(sd_wCO2, 1),
    CV_wCO2 = round(CV_wCO2, 2)
  ))
}

# Apply the function to all combinations and combine results into a data frame
data <- param_combinations %>%
  pmap_dfr(process_and_summarize)

openxlsx::write.xlsx(data, file = "~/Downloads/results_param.xlsx")

#data <- readxl::read_excel("~/Downloads/results_param.xlsx")

# Calculate Pearson correlations between parameters and means
## Note that based on the correlations the factor that reduce more the records in min_time
dcorrelations <- round(cor(data[, c("param1", "param2", "min_time", "records_d", "cows_d", "mean_dCH4", "CV_dCH4")], use = "complete.obs"),2)
dcorrelations
wcorrelations <- round(cor(data[, c("param1", "param2", "min_time", "records_w", "cows_w", "mean_wCH4", "CV_wCH4")], use = "complete.obs"),2)
wcorrelations

# Extract results for different min_time
mintime2 <- data[data$min_time == 2,]






