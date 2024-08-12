# Processing data from GreenFeed units
# The data use in this script is that obtain directly from C-Lock interface
# Written by Guillermo Martinez Boggio


library(readr)
library(readxl)
library(data.table)
library(dplyr)
library(tidyverse)
library(lubridate)
library(ggfortify)
library(car)
library(lme4)
library(phyloseq)
library(ggplot2)
library(RColorBrewer)
library(reshape2)
library(patchwork)
library(gridExtra)
library(cowplot)
library(plyr)
library(ggpubr)
library(reshape2)
library(purrr)
library(knitr)
library(kableExtra)
library(zoo)


#### **SETTING PARAMETERS FOR GREENFEED DATA ANALYSIS ###########################

# Choose one of the experiments of the following list. If it's not on the list, then include it (Experiment name, Start and End Dates, and units)
list_of_experiments <- list(
  HMW668 = list(StartDate = "2023-04-23", EndDate = "2023-06-02", Units = list("45" = 48, "212" = 37), fileEID_path = "~/GreenFeed_UW/Methane/HMW668/HMW668_EID.csv"),
  KAW680 = list(StartDate = "2023-06-27", EndDate = "2023-08-10", Units = list("212" = 33), fileEID_path = "~/GreenFeed_UW/Methane/KAW680/KAW680_EID_DIM.csv"),
  LFF682 = list(StartDate = "2023-07-28", EndDate = "2023-10-20", Units = list("592" = 36, "593" = 35.6), fileEID_path = "~/GreenFeed_UW/Methane/LFF682/LFF682_EID.csv"),
  KAW688 = list(StartDate = "2023-09-18", EndDate = "2023-11-03", Units = list("212" = 38), fileEID_path = "~/GreenFeed_UW/Methane/KAW688/KAW688_EID.csv"),
  FP690 = list(StartDate = "2023-09-22", EndDate = "2023-11-17", Units = list("579" = 0), fileEID_path = "~/GreenFeed_UW/Methane/FP690/FP690_EID.csv"),
  LFF691 = list(StartDate = "2023-10-23", EndDate = "2024-01-12", Units = list("592" = 43, "593" = 43), fileEID_path = "~/GreenFeed_UW/Methane/LFF691/LFF691_EID.csv"),
  KAW693 = list(StartDate = "2023-11-13", EndDate = "2023-12-21", Units = list("212" = 38), fileEID_path = "~/GreenFeed_UW/Methane/KAW693/KAW693_EID.csv"),
  FP692 = list(StartDate = "2023-11-27", EndDate = "2024-01-12", Units = list("579" = 0), fileEID_path = "~/GreenFeed_UW/Methane/FP692/FP692_EID.csv"),
  HMW706 = list(StartDate = "2024-06-10", EndDate = "2024-08-02", Units = list("592" = 34, "593" = 34), fileEID_path = "~/GreenFeed_UW/Methane/HMW706/HMW706_EID.csv"),
  FP703 = list(StartDate = "2024-07-15", EndDate = as.character(Sys.Date()), Units = list("212" = 34), fileEID_path = "~/GreenFeed_UW/Methane/FP703/FP703_EID.csv")
)

user_choice <- menu(names(list_of_experiments), title = "Select Experiment Number: ")
9

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


#################################################################################


#### READING FILES OF RFIDS AND FEEDTIMES FROM C-LOCK ###########################

# Read GreenFeed data from C-Lock interface
## Data: View/Download Raw Data (Download Large Dataset (>2 hours))
## Download and Read data from all units

## Read RFID data
rfids_file_paths <- purrr::map_chr(UNIT, function(u) {
  file <- paste0("~/GreenFeed_UW/Methane/", selected_experiment, "/data_", u, "_", Exp_PERIOD, "/rfids.csv")
  return(file)
})

rfids <- dplyr::bind_rows(purrr::map2_dfr(rfids_file_paths, UNIT, ~ readr::read_csv(.x) %>% dplyr::mutate(unit = .y)))


## Read feedtimes data
feedtimes_file_paths <- purrr::map_chr(UNIT, function(u) {
  file <- paste0("~/GreenFeed_UW/Methane/", selected_experiment, "/data_", u, "_", Exp_PERIOD, "/feedtimes.csv")
  return(file)
})

feedtimes <- dplyr::bind_rows(purrr::map2_dfr(feedtimes_file_paths, UNIT, ~ readr::read_csv(.x) %>% dplyr::mutate(unit = .y)))


### Remove leading zeros from CowTag column
rfids$CowTag <- gsub("^0+", "", rfids$CowTag)
feedtimes$CowTag <- gsub("^0+", "", feedtimes$CowTag)

### Selecting data only from cows in the current experiment (remove calibration TAGs, unknowns, errors, etc.)
rfids <- rfids[rfids$CowTag %in% CowsInExperiment$EID, ]
feedtimes <- feedtimes[feedtimes$CowTag %in% CowsInExperiment$EID, ]


# QUICK CHECK OF HOW MANY COWS ARE VISITING OR NOT THE UNITS:
## Lets make a list of cows that received food drops in the current experimental period
ListCowsVisitingGF <- semi_join(CowsInExperiment, feedtimes, by = c("EID" = "CowTag"))
ListCowsNonVisitingGF <- anti_join(CowsInExperiment, feedtimes, by = c("EID" = "CowTag"))

#################################################################################


#### PROCESSING TAG READS (OR APPROACHES) FROM UNITS ##########################

# Data processing the number of visits to units based on the rfids_visits
# This data set is download every day with data for every second visit


# Adding to the table the visit day and daytime visit
rfids <- rfids %>%
  dplyr::mutate(
    visit_day = as.character(as.Date(rfids$ScanTime)),
    visit_time = as.character(as.POSIXct(rfids$ScanTime), format = "%H")
  )


# Generating the number of visits per cow to the GF units
rfids$approach_number <- cumsum(rfids$CowTag != lag(rfids$CowTag, default = rfids$CowTag[1])) + 1


## Description of number of TAG reads per day and per unit
cat("Total number of TAG reads: ", nrow(rfids))

## Plot number of TAG reads per unit
rfids %>%
  dplyr::group_by(unit) %>%
  dplyr::summarise(n = n()) %>%
  ggplot(aes(x = unit, y = n, fill = unit)) +
  geom_bar(stat = "identity", position = position_dodge()) +
  labs(title = "Number of TAG reads per GF units", x = "Units", y = "Frequency") +
  geom_text(aes(label = n), vjust = 1.9, color = "black", position = position_dodge(0.9), size = 3.8) +
  scale_fill_manual(values = c("#009E73", "#0072B2")) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
    axis.text = element_text(size = 12),
    axis.title = element_text(size = 12),
    legend.position = "none"
  )


## Plot the number of TAG reads per day
rfids %>%
  dplyr::group_by(unit, visit_day) %>%
  dplyr::summarise(n = n()) %>%
  ggplot(aes(x = visit_day, y = n, fill = unit)) +
  geom_bar(stat = "identity", position = "stack", width = 0.8) +
  labs(title = "Daily number of TAG reads grouped by unit", x = "Day", y = "Frequency", fill = "Unit") +
  geom_text(aes(label = n), position = position_stack(vjust = 0.5), color = "black", size = 2) +
  scale_fill_manual(values = c("#009E73", "#0072B2")) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8, margin = margin(t = 0.5, r = 0, b = 0, l = 0)),
    axis.text.y = element_text(size = 10),
    axis.title = element_text(size = 12),
    plot.title = element_text(size = 12, face = "bold", hjust = 0.5),
    legend.position = "right",
    legend.title = element_blank(),
    legend.text = element_text(size = 10)
  )



## Plot the number of TAG reads per day time
rfids %>%
  dplyr::group_by(unit, visit_time) %>%
  dplyr::summarise(n = n()) %>%
  ggplot(aes(x = visit_time, y = n, fill = unit)) +
  geom_bar(stat = "identity", position = position_stack()) +
  labs(title = "Number of TAG reads per daytime grouped by unit", x = "Day Time", y = "Frequency", fill = "") +
  geom_text(aes(label = n), position = position_stack(vjust = 0.5), color = "black", size = 2.5) +
  scale_fill_manual(values = c("#009E73", "#0072B2")) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 0, hjust = 0.5, size = 8),
    axis.text.y = element_text(size = 10),
    axis.title = element_text(size = 12),
    plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
    legend.position = "right",
    legend.title = element_blank(),
    legend.text = element_text(size = 10)
  )



## Description of number of approaches to units (approaches as lecture of RFID TAG)

## Grouping the number of approaches per cow per unit
approachesToGF <- rfids %>%
  dplyr::group_by(CowTag, approach_number, unit) %>%
  dplyr::summarise(
    v_mins = round(as.numeric(difftime(max(ScanTime), min(ScanTime), units = "mins")), 3),
    v_secs = as.numeric(difftime(max(ScanTime), min(ScanTime), units = "secs"))
  )

cat("Total number of approaches: ", max(approachesToGF$approach_number))


### Plot number of visits per unit
approachesToGF %>%
  dplyr::group_by(unit) %>%
  dplyr::summarise(n = n()) %>%
  ggplot(aes(x = unit, y = n, fill = unit)) +
  geom_bar(stat = "identity", position = "stack", width = 0.8) +
  labs(title = "Number of visits per GF units", x = "Units", y = "Frequency") +
  geom_text(aes(label = n), vjust = -0.3, color = "black", size = 3.8) +
  scale_fill_manual(values = c("#009E73", "#0072B2")) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 0, hjust = 0.5, size = 8),
    axis.text.y = element_text(size = 10),
    axis.title = element_text(size = 12),
    plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
    legend.position = "none"
  )


## Grouping the number of visit per cow, per unit, per day and daytime
approachesToGF <- rfids %>%
  dplyr::group_by(CowTag, approach_number, unit, visit_day, visit_time)


## Grouping the number and time of visits to each unit and per day
# approachesAndTimeToGF <- rfids_visits %>%
#  dplyr::group_by(CowTag,visit_number,unit,visit_day) %>%
#  dplyr::summarise(v_mins = round(as.numeric(difftime(max(ScanTime),min(ScanTime),units = "mins")),3),
#                   v_secs = as.numeric(difftime(max(ScanTime),min(ScanTime),units = "secs")))

# VisitsPerCow <- visitsAndTimeToGF %>%
#  dplyr::group_by(CowTag) %>%
#  dplyr::summarise(n = n(),
#                   v_MeanTime = mean(v_mins),
#                   v_MedianTime = median(v_mins),
#                   v_MaxTime = max(v_mins),
#                   v_MinTime = min(v_mins))

### Description of number and mean time of visits per cow
# summary(VisitsPerCow$n);summary(VisitsPerCow$v_MeanTime)


## Grouping the number and time of visits per cow and per day
# VisitsPerCowPerDay = visitsAndTimeToGF %>%
#  dplyr::group_by(CowTag,visit_day) %>%
#  dplyr::summarise(n = n(), v_MeanTime = mean(v_mins),
#                   v_MedianTime = median(v_mins),
#                   v_MaxTime = max(v_mins),
#                   v_MinTime = min(v_mins))


### Plot number of visits per cow and per day (with the median of visits per day)
# ggplot(VisitsPerCowPerDay, aes(x=CowTag,y=n, fill=CowTag)) +
#  geom_boxplot() +
#  labs(title="",x="" ,y="Number of visits per day") +
#  theme_classic() +
#  geom_hline(yintercept=(median(VisitsPerCowPerDay$n)), linetype="dashed", color = "black", linewidth=0.5) +
#  theme(axis.text.x=element_text(angle = 45, hjust = 1, size = 8),
#        legend.position="none")


# How many cows are visiting but without food drop?
# unique(anti_join(VisitsPerCow,feed_visits, by="CowTag")[,1])

# How many cows are visiting with food drop? Then, this visit is an effective visit
# unique(semi_join(VisitsPerCow,feed_visits, by="CowTag")[,1])

# How many visits per cow? and how much time per visit per cow?

## Lets create a table with the number of visit per cow per day
# D1 <- t(data.frame(tapply(VisitsPerCowPerDay$n, list(VisitsPerCowPerDay$visit_day,VisitsPerCowPerDay$CowTag), mean), check.names = FALSE))
# D1 <- D1[order(row.names(D1)), ]
# write.table(D1,file="~/Downloads/D1", quote = F)

# D2 <- t(data.frame(round(tapply(VisitsPerCowPerDay$v_MeanTime, list(VisitsPerCowPerDay$visit_day,VisitsPerCowPerDay$CowTag), mean),1), check.names = FALSE))
# D2 <- D2[order(row.names(D2)), ]
# write.table(D2,file="~/Downloads/D2", quote = F)


#################################################################################


#### PROCESSING FEEDTIMES (OR FOOD DROPS) FROM UNITS #########################################

# Adding to the table the visit day and daytime visit
feedtimes <- feedtimes %>%
  dplyr::mutate(
    visit_day = as.character(as.Date(feedtimes$FeedTime)),
    visit_time = as.character(as.POSIXct(feedtimes$FeedTime), format = "%H")
  )

# For cows that are visiting the units
## How many drops per cow per day?
drops_per_cow_per_day <- feedtimes %>%
  dplyr::group_by(CowTag, visit_day) %>%
  dplyr::summarise(ndrops = n(), TotalPeriod = max(CurrentPeriod))


## Plot number of food drops per day per cow
ggplot(drops_per_cow_per_day, aes(x = factor(CowTag), y = ndrops, fill = factor(CowTag))) +
  geom_boxplot(width = 0.6) +
  geom_boxplot(aes(x = "", y = ndrops), fill = "white", color = "black", width = 0.6) +
  labs(title = "Number of food drops received per cow per day", x = "Cow Tag", y = "Number of drops per day") +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
    legend.position = "none"
  ) +
  geom_hline(
    yintercept = median(drops_per_cow_per_day$ndrops),
    linetype = "dashed", color = "black", linewidth = 0.5
  )


## Lets create a table with the MEAN of drops per cow per day
D3 <- aggregate(ndrops ~ visit_day + CowTag, data = drops_per_cow_per_day, sum)

# Create a grid of all unique combinations of visit_day and CowTag
grid <- expand.grid(visit_day = unique(D3$visit_day), CowTag = unique(D3$CowTag))

# Merge the grid with the aggregated data, filling missing combinations with 0
D3 <- merge(D3, grid, all = TRUE, fill = list(ndrops = 0))

# It is necessary to identify the cows with low number of visits to encourage them!!!
# Identify cows with no drops for a define number of days in the experiment
THR <- 2 # Define a threshold for the number of days without visits
list_of_cows_to_encourage <- D3 %>%
  dplyr::group_by(CowTag) %>%
  dplyr::mutate(n_NA = sum(is.na(ndrops))) %>%
  dplyr::filter(n_NA > THR) %>%
  dplyr::select(CowTag, n_NA) %>%
  dplyr::distinct()

## List of cows with their Farm name
list_of_cows_to_encourage <- CowsInExperiment %>% inner_join(list_of_cows_to_encourage, by = c("EID" = "CowTag"))

## Print the list of cows to encourage
print(list_of_cows_to_encourage)
# write.table(list_of_cows_to_encourage, file = "~/Downloads/List_of_cows_to_encourage.txt", row.names = FALSE, quote = FALSE)


# For cows that are visiting the units
## Calculate the number of drops and the food mass per cow
drops_per_cow_per_day_per_unit <- feedtimes %>%
  dplyr::group_by(CowTag, unit, visit_day) %>%
  dplyr::summarise(ndrops = n(), TotalPeriod = max(CurrentPeriod))

# Calculating the mass food per drop in different units
## TODO BEFORE START EXP!!! You should consider the amount of food in grams that each unit can provide
grams_per_cup <- list_of_experiments[[selected_experiment]][["Units"]] # Include in the list the amount of grams for each unit

for (i in 1:length(grams_per_cup)) {
  unit <- names(grams_per_cup)[i]
  mask <- drops_per_cow_per_day_per_unit$unit == unit
  drops_per_cow_per_day_per_unit$MassFoodDrop[mask] <- as.numeric(drops_per_cow_per_day_per_unit$ndrops[mask]) * as.numeric(grams_per_cup[[unit]])
}

## Create a table with alfalfa pellets (AP) intakes in kg
massAP_intakes <- drops_per_cow_per_day_per_unit %>%
  dplyr::group_by(CowTag, visit_day) %>%
  dplyr::summarise(MassFoodDrop = sum(MassFoodDrop) / 1000) # Divided by 1000 to transform mass in kg

# Create a grid of all unique combinations of visit_day and CowTag
grid <- expand.grid(visit_day = unique(massAP_intakes$visit_day), CowTag = unique(massAP_intakes$CowTag))
massAP_intakes <- merge(massAP_intakes, grid, all = TRUE, fill = list(MassFoodDrop = 0))

## Adding the Farm name to the AP intakes
massAP_intakes <- CowsInExperiment[, 1:2] %>% inner_join(massAP_intakes, by = c("EID" = "CowTag"))
colnames(massAP_intakes) <- c("Farm_name", "RFID", "Date", "Intake_AP_kg")

## Plot mass food drop per day per cow
ggplot(massAP_intakes, aes(x = RFID, y = Intake_AP_kg, fill = RFID)) +
  geom_boxplot() +
  geom_boxplot(aes(x = "", y = Intake_AP_kg), fill = "white", colour = "black") +
  labs(title = "", x = "", y = "Daily intakes of AP (kg)") +
  theme_classic() +
  scale_y_continuous(breaks = seq(0, max(massAP_intakes$Intake_AP_kg, na.rm = T), 0.1)) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
    legend.position = "none"
  ) +
  geom_hline(
    yintercept = mean(massAP_intakes$Intake_AP_kg, na.rm = T),
    linetype = "dashed", color = "black", linewidth = 0.5
  )




# Export a table with the amount of kg of pellets
# file_path <- paste0("~/Principal/Project_CH4/GreenFeed/", selected_experiment, "/FeedEfficiency_Data/Pellet_Intakes.txt")
# write.table(massAP_intakes, file = file_path, quote = F, row.names = F)


# However, if you need pellet intakes for a specific period (sp), then:
## Define the first and last dates for which you want the intakes
FirstDate <- "2023-11-21"
LastDate <- "2024-01-12"

# Create a sequence of dates from FirstDate to LastDate
all_dates <- seq(as.Date(FirstDate), as.Date(LastDate), by = "day")

massAP_intakes_sp <- massAP_intakes %>%
  dplyr::filter(Date >= FirstDate & Date <= LastDate)

massAP_intakes_sp$Date <- as.Date(massAP_intakes_sp$Date)

massAP_intakes_sp <- massAP_intakes_sp %>%
  complete(Date = all_dates, nesting(Farm_name))


## Add cows without visits to the units
cows_missing_GF <- c("9116")
grid_cows_missing <- expand.grid(
  Date = unique(massAP_intakes_sp$Date),
  Farm_name = CowsInExperiment$FarmName[CowsInExperiment$FarmName %in% cows_missing_GF],
  RFID = CowsInExperiment$EID[CowsInExperiment$FarmName %in% cows_missing_GF],
  Intake_AP_kg = NA
)
massAP_intakes_sp <- rbind(massAP_intakes_sp, grid_cows_missing)


# Replace NA for a period (.)
massAP_intakes_sp$Intake_AP_kg[is.na(massAP_intakes_sp$Intake_AP_kg)] <- "."

# Export a table with the amount of kg of pellets for a specific period!
file_path <- paste0("~/Downloads/Pellet_Intakes_", FirstDate, "_", LastDate, ".txt")
write.table(massAP_intakes_sp, file = file_path, quote = F, row.names = F)





#################################################################################


#### **PROCESSING AND EDITING GAS PRODUCTION DATA: CH4 AND CO2 ##################

# Data processing of Summarized data provided by C-Lock every day with the converted values of the previous day
# The data set combines all units under the same account

# Read daily SUMMARIZED DATA downloaded from C-Lock interface
# if (length(UNIT) == 1) {
#  file_path <- paste0("~/GreenFeed_UW/Methane/", selected_experiment, "/GreenFeed_Summarized_Data_", UNIT[1], ".xlsm")
# } else {
#  file_path <- paste0("~/GreenFeed_UW/Methane/", selected_experiment, "/GreenFeed_Summarized_Data_", UNIT[1], "_", UNIT[2], ".xlsm")
# }
# Summarized_Data <- read_excel(file_path)

Summarized_Data <- data.frame()
for (unit in UNIT) {
  file_path <- paste0("~/GreenFeed_UW/Methane/", selected_experiment, "/", selected_experiment, "_", unit, ".txt")
  data <- read_csv(file_path, skip = 1)
  Summarized_Data <- rbind(Summarized_Data, data)
}

### Remove leading zeros from RFID column
Summarized_Data$RFID <- gsub("^0+", "", Summarized_Data$RFID)

## Summarized data has the gas production data for a long period of time, so you should select the specific period of your experiment
## Selecting data only from cows in the current experiment
Summarized_Data <- Summarized_Data %>%
  dplyr::filter(
    as.Date(StartTime) >= as.Date(unlist(list_of_experiments[[selected_experiment]]["StartDate"])) &
      as.Date(StartTime) <= as.Date(unlist(list_of_experiments[[selected_experiment]]["EndDate"])),
    RFID %in% CowsInExperiment$EID
  ) %>%
  dplyr::distinct_at(vars(1:5), .keep_all = TRUE)


# Editing and applying filters to raw data

# Step 1: Inner join with CowsInExperiment based on RFID and EID, and calculate DIM
Summarized_Data <- Summarized_Data %>%
  inner_join(CowsInExperiment, by = c("RFID" = "EID")) %>%
  mutate(
    DIM = if ("DIM" %in% colnames(.)) {
      DIM + as.numeric(difftime(
        as.Date(StartTime),
        as.Date(unlist(list_of_experiments[[selected_experiment]])["StartDate"]),
        units = "days"
      ))
    }
  ) %>%
  # Step 2: Remove cannulated cows from data
  filter(if ("CAN" %in% colnames(CowsInExperiment)) {
    !(RFID %in% CowsInExperiment$EID[!is.na(CowsInExperiment$CAN)])
  } else {
    TRUE
  }) %>%
  # Step 3: Removing data with Airflow below the threshold (20 l/s)
  filter(AirflowLitersPerSec >= 20)


## Check for outliers per day for CH4 and CO2, and including NA if so
# Summarized_Data <- Summarized_Data %>%
#  dplyr::mutate(day = as.Date(EndTime)) %>%
#  dplyr::group_by(RFID, day) %>%
#  dplyr::mutate(CH4GramsPerDay = ifelse(CH4GramsPerDay %in% boxplot.stats(CH4GramsPerDay)$out, NA, CH4GramsPerDay),
#                CO2GramsPerDay = ifelse(CO2GramsPerDay %in% boxplot.stats(CO2GramsPerDay)$out, NA, CO2GramsPerDay))


## Change the format of good data duration column: Good Data Duration column to minutes with two decimals
### Always the Good data duration is lower or equal to the period between Start and End time
Summarized_Data$GoodDataDuration <- round(period_to_seconds(hms(as.character(as.POSIXct(Summarized_Data$GoodDataDuration), format = "%H:%M:%S"))) / 60, 2)
Summarized_Data$HourOfDay <- round(period_to_seconds(hms(as.character(as.POSIXct(Summarized_Data$StartTime), format = "%H:%M:%S"))) / 3600, 2)

#################################################################################


#### DESCRIPTION OF GAS PRODUCTION DATA: CH4 AND CO2 ############################

## Total number of animals in the experiment without data
anti_join(CowsInExperiment, Summarized_Data, by = c("EID" = "RFID"))

## Description of total number of records per unit

### Plot total number of gas production records per unit
Summarized_Data %>%
  dplyr::mutate(Unit = as.character(FeederID)) %>%
  dplyr::group_by(Unit) %>%
  dplyr::summarise(n = n()) %>%
  ggplot(aes(x = Unit, y = n, fill = Unit)) +
  geom_col(position = position_dodge()) +
  labs(title = "Number of gas records per unit", x = "Unit", y = "Total number of records") +
  scale_fill_manual(values = c("#009E73", "#0072B2")) +
  theme_minimal() +
  geom_text(aes(label = n), position = position_dodge(width = 0.9), vjust = -0.4, color = "black", size = 3.8) +
  theme(
    axis.text.x = element_blank(),
    legend.position = "right"
  )



## Description of total number of records and CH4 PER DAY

# Plot 1: Total number of gas production records per day
plot1 <- ggplot(as.data.frame(table(as.Date(Summarized_Data$StartTime))), aes(x = Var1, y = Freq)) +
  geom_col(color = "black") +
  labs(title = "Number of records per day", x = "", y = "Total number of records") +
  geom_text(aes(label = Freq), vjust = -0.5, color = "black", size = 2.2, position = position_dodge(width = 0.9)) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
    legend.position = "none"
  )

# Plot 2: CH4 production per day in the experimental period
plot2 <- ggplot(Summarized_Data, aes(x = as.character(as.Date(StartTime)), y = CH4GramsPerDay, color = as.character(as.Date(StartTime)))) +
  geom_boxplot(lwd = 0.8) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
    legend.position = "none"
  ) +
  scale_y_continuous(breaks = c(seq(0, max(Summarized_Data$CH4GramsPerDay), 50))) +
  labs(title = "CH4 massflow per visit in the experimental period", x = "", y = "CH4 (g/d)") +
  geom_hline(yintercept = mean(Summarized_Data$CH4GramsPerDay), linetype = "dashed", color = "black", linewidth = 0.5)

# Combine the plots
combined_plot <- plot1 + plot2 + plot_layout(ncol = 1, heights = c(0.4, 0.6))
combined_plot



## Description of total number of records and CH4 PER COW

# Plot 1: Total number of gas production records per cow
plot1 <- Summarized_Data %>%
  dplyr::mutate(day = as.Date(EndTime)) %>%
  dplyr::group_by(RFID, day) %>%
  dplyr::summarise(n = n(), daily_CH4 = weighted.mean(CH4GramsPerDay, GoodDataDuration, na.rm = TRUE)) %>%
  dplyr::group_by(RFID) %>%
  dplyr::summarise(n = sum(n), daily_CH4 = mean(daily_CH4, na.rm = TRUE)) %>%
  ggplot(aes(x = reorder(RFID, -daily_CH4), y = n)) +
  geom_bar(stat = "identity", position = position_dodge()) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1.05, size = 8, family = "Times New Roman"),
    legend.position = "none",
    axis.title.y = element_text(size = 10, family = "Times New Roman", face = "bold")
  ) +
  geom_text(aes(label = n),
    vjust = -1, color = "black",
    position = position_dodge(width = 0.9), size = 2.2
  ) +
  labs(title = "Number of gas production records per cow", x = "", y = "Total number of records", fill = "") +
  scale_y_continuous(expand = c(0.02, 0), limits = c(0, 300)) +
  geom_hline(
    yintercept = floor(as.numeric(difftime(max(Summarized_Data$StartTime), min(Summarized_Data$StartTime), units = "days"))),
    linetype = "dashed", color = "red", linewidth = 0.5
  ) #+
# annotate("text", x = length(unique(Summarized_Data$RFID)) + 0.3, y = floor(as.numeric(difftime(max(Summarized_Data$StartTime), min(as.Date(Summarized_Data$StartTime)), units = "days"))),
#         label = floor(as.numeric(difftime(max(Summarized_Data$StartTime), min(as.Date(Summarized_Data$StartTime)), units = "days"))), color = "red", fontface = "bold", size = 3)


# Plot 2: CH4 production per day
plot2 <- Summarized_Data %>%
  dplyr::mutate(day = as.Date(EndTime)) %>%
  dplyr::group_by(RFID, day) %>%
  dplyr::summarise(daily_CH4 = weighted.mean(CH4GramsPerDay, GoodDataDuration, na.rm = TRUE)) %>%
  {
    ggplot(., aes(x = reorder(RFID, -daily_CH4), y = daily_CH4, color = daily_CH4)) +
      geom_boxplot() +
      theme_classic() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1.05, size = 8, family = "Times New Roman"),
        legend.position = "none",
        axis.title.y = element_text(size = 10, family = "Times New Roman", face = "bold")
      ) +
      scale_y_continuous(breaks = seq(0, max(.$daily_CH4), by = 50)) +
      labs(title = "Daily CH4 massflux per cow", x = "", y = "CH4 (g/d)") +
      geom_hline(yintercept = mean(.$daily_CH4), linetype = "dashed", color = "#3366FF", linewidth = 0.8)
  }

# Combine the plots
combined_plot <- plot1 + plot2 + plot_layout(ncol = 1, heights = c(0.5, 0.6))
combined_plot



## Description of total number of records and CH4 PER DAY

# Plot 1: Total number of gas production records per day
plot1 <- ggplot(as.data.frame(table(as.Date(Summarized_Data$StartTime))), aes(x = Var1, y = Freq)) +
  geom_col(color = "black") +
  labs(title = "Number of records per day", x = "", y = "Total number of records") +
  geom_text(aes(label = Freq), vjust = -0.5, color = "black", size = 2.2, position = position_dodge(width = 0.9)) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
    legend.position = "none"
  )

# Plot 2: CH4 production per day in the experimental period
plot2 <- ggplot(Summarized_Data, aes(x = as.character(as.Date(StartTime)), y = CH4GramsPerDay, color = as.character(as.Date(StartTime)))) +
  geom_boxplot(lwd = 0.8) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
    legend.position = "none"
  ) +
  scale_y_continuous(breaks = c(seq(0, max(Summarized_Data$CH4GramsPerDay), 50))) +
  labs(title = "CH4 massflow per visit in the experimental period", x = "", y = "CH4 (g/d)") +
  geom_hline(yintercept = mean(Summarized_Data$CH4GramsPerDay), linetype = "dashed", color = "black", linewidth = 0.5)

# Combine the plots
combined_plot <- plot1 + plot2 + plot_layout(ncol = 1, heights = c(0.4, 0.6))
combined_plot



## Description of gases production, CH4 and CO2,  based on:

### Evaluate the good duration of measurements in the units
### C-Lock uses as a threshold a minimum time of 2 min., but how is the distribution of your data based on duration?

#### Calculate the CH4 and CO2 mean, standard deviation (SD), and coefficient of variation (CV) for each Good Data Duration
duration_summary <- Summarized_Data %>%
  dplyr::mutate(duration = round(GoodDataDuration, 0)) %>% # changing the round value you can obtain more finer description
  dplyr::group_by(duration) %>%
  dplyr::summarise(
    n = n(),
    mean_CH4 = mean(CH4GramsPerDay),
    SD_CH4 = sd(CH4GramsPerDay),
    CV_CH4 = round((sd(CH4GramsPerDay) / mean(CH4GramsPerDay)) * 100, 1),
    mean_CO2 = mean(CO2GramsPerDay),
    SD_CO2 = sd(CO2GramsPerDay),
    CV_CO2 = round((sd(CO2GramsPerDay) / mean(CO2GramsPerDay)) * 100, 1)
  )

kable(duration_summary, caption = "Summary of CH4 and CO2 per Good Data Duration") %>%
  kable_classic(full_width = FALSE) %>%
  kable_styling(bootstrap_options = c("striped", "hover"), font_size = 12) %>%
  add_header_above(c(" ", "Summary" = 7))


# Plot CH4 in function of the Duration of the measurement
plot1 <- ggplot(Summarized_Data, aes(x = GoodDataDuration, y = CH4GramsPerDay, color = CH4GramsPerDay)) +
  geom_point() +
  geom_boxplot(aes(x = 1, y = CH4GramsPerDay)) +
  theme_classic() +
  theme(
    axis.text.x = element_text(size = 8),
    legend.position = "none"
  ) +
  scale_color_gradient() +
  scale_x_continuous(breaks = seq(2, 15)) +
  scale_y_continuous(breaks = seq(0, max(Summarized_Data$CH4GramsPerDay), 50)) +
  labs(title = "", x = "Gases measurement duration", y = "CH4 (g/d)") +
  geom_hline(yintercept = mean(Summarized_Data$CH4GramsPerDay), linetype = "dashed", color = "red", linewidth = 0.5)

# Plot Good Data Duration in function of the days
plot2 <- ggplot(Summarized_Data, aes(x = as.character(as.Date(StartTime)), y = GoodDataDuration, color = as.character(as.Date(StartTime)))) +
  geom_boxplot(lwd = 0.8) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
    legend.position = "none"
  ) +
  scale_y_continuous(breaks = seq(0, 15)) +
  labs(title = "", x = "", y = "Gases measurement duration")

# Plot Good Data Duration in function of the hour of the day
plot3 <- ggplot(Summarized_Data, aes(x = HourOfDay, y = GoodDataDuration, color = GoodDataDuration)) +
  geom_point() +
  geom_smooth() +
  geom_boxplot(aes(x = 26, y = GoodDataDuration)) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 0, hjust = 0.5, size = 8),
    legend.position = "none"
  ) +
  scale_color_gradientn(colours = terrain.colors(4)) +
  scale_x_continuous(breaks = seq(0, 24)) +
  scale_y_continuous(breaks = seq(0, 15)) +
  labs(title = "", x = "Hours of the day", y = "Gases measurement duration")

# Combine the three plots
combined_plot <- (plot1 | plot2) / plot3
combined_plot



# 2. Hour of the day

### Grouping the records based on the hour of the day. 3 times in the morning (AM) and 3 timpoints in the afternoon (PM)

plot1 <- Summarized_Data %>%
  dplyr::mutate(day = as.Date(EndTime)) %>%
  dplyr::group_by(RFID, day) %>%
  dplyr::summarise(n = n(), daily_CH4 = weighted.mean(CH4GramsPerDay)) %>%
  ggplot(aes(x = RFID, y = n)) +
  geom_boxplot() +
  theme_minimal() +
  labs(title = "Daily CH4 records per cow", x = "", y = "Number of records", fill = "") +
  theme(
    axis.text.x = element_blank(),
    legend.position = "none"
  )

## Changing the format of the hour of the day
Summarized_Data$HourOfDay <- as.numeric(Summarized_Data$HourOfDay)

plot2 <- Summarized_Data %>%
  mutate(AMPM = case_when(
    HourOfDay >= 22 ~ "PM_AM",
    HourOfDay < 4 ~ "PM_AM",
    HourOfDay >= 4 & HourOfDay < 10 ~ "AM1",
    HourOfDay >= 10 & HourOfDay < 16 ~ "AM_PM",
    HourOfDay >= 16 & HourOfDay < 22 ~ "PM1",
    TRUE ~ NA_character_
  )) %>%
  dplyr::group_by(RFID, AMPM) %>%
  dplyr::summarise(n = n()) %>%
  ggplot(aes(x = RFID, y = n, fill = factor(AMPM, levels = c("PM_AM", "AM1", "AM_PM", "PM1")))) +
  geom_bar(stat = "identity", position = "fill") +
  labs(title = "", x = "", y = "% of total records", fill = "") +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1.05, size = 8),
    legend.position = "right",
    axis.title.y = element_text(size = 10, face = "bold")
  ) +
  scale_fill_brewer(palette = "BrBG") +
  scale_y_continuous(breaks = c(0, 0.25, 0.50, 0.75, 1), labels = c("0%", "25%", "50%", "75%", "100%"), expand = c(0, 0))


# Combine the plots
combined_plot <- plot1 + plot2 + plot_layout(ncol = 1, heights = c(0.5, 0.5))
combined_plot


## Table with number of records, mean, SD and CV for CH4 and CO2 across the day
Summarized_Data %>%
  dplyr::mutate(daytime = round(HourOfDay, 0)) %>%
  dplyr::group_by(daytime) %>%
  dplyr::summarise(
    n = n(),
    mean_CH4 = round(mean(CH4GramsPerDay), 1),
    SD_CH4 = round(sd(CH4GramsPerDay), 1),
    CV_CH4 = round(sd(CH4GramsPerDay / mean(CH4GramsPerDay)) * 100, 1),
    mean_CO2 = round(mean(CO2GramsPerDay), 1),
    SD_CO2 = round(sd(CO2GramsPerDay), 1),
    CV_CO2 = round((sd(CO2GramsPerDay) / mean(CO2GramsPerDay)) * 100, 1)
  ) %>%
  kable(caption = "Summary of CH4 and CO2 across the day") %>%
  kable_classic(full_width = FALSE) %>%
  add_header_above(c("CH4" = 4, "CO2" = 4)) %>%
  row_spec(0, bold = TRUE) %>%
  row_spec(1, italic = TRUE) %>%
  kable_styling(bootstrap_options = c("striped", "hover"), font_size = 12)


# Plot CH4 in function of the hour of the day
plot_CH4 <- ggplot(Summarized_Data, aes(x = HourOfDay, y = CH4GramsPerDay, color = CH4GramsPerDay)) +
  geom_point() +
  geom_smooth() +
  geom_boxplot(aes(x = 26, y = CH4GramsPerDay)) +
  theme_classic() +
  theme(legend.position = "none") +
  scale_color_gradientn(colours = terrain.colors(10)) +
  scale_x_continuous(breaks = seq(0, 24)) +
  scale_y_continuous(breaks = seq(0, 1100, 50)) +
  labs(title = "", x = "", y = "CH4 (g/d)")

# Plot CO2 in function of the hour of the day
plot_CO2 <- ggplot(Summarized_Data, aes(x = HourOfDay, y = CO2GramsPerDay, color = CO2GramsPerDay)) +
  geom_point() +
  geom_smooth() +
  geom_boxplot(aes(x = 26, y = CO2GramsPerDay)) +
  theme_classic() +
  theme(legend.position = "none") +
  scale_color_gradientn(colours = terrain.colors(10)) +
  scale_x_continuous(breaks = seq(0, 24)) +
  scale_y_continuous(breaks = seq(0, 35000, 5000)) +
  labs(title = "", x = "Hours of the day", y = "CO2 (g/d)")

# Combine the plots
combined_plot <- plot_CH4 + plot_CO2 + plot_layout(ncol = 1, heights = c(0.5, 0.5))
combined_plot


#################################################################################


#### **CALCULATING DAILY, WEEKLY, AND EXPERIMENTAL PRODUCTION OF GASES ##########

## 1. Description of production of gases in each visit

ggplot(Summarized_Data, aes(x = reorder(RFID, -CH4GramsPerDay), y = CH4GramsPerDay)) +
  geom_boxplot() +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
    legend.position = "none"
  ) +
  scale_y_continuous(breaks = seq(0, max(Summarized_Data$CH4GramsPerDay), by = 50)) +
  labs(title = "CH4 massflux per cow (per visit)", x = "", y = "CH4 (g/d)") +
  geom_hline(yintercept = mean(Summarized_Data$CH4GramsPerDay), linetype = "dashed", color = "#3366FF", linewidth = 0.8)

summary(Summarized_Data$CH4GramsPerDay)
cat("CH4: ", mean(Summarized_Data$CH4GramsPerDay), "+-", sd(Summarized_Data$CH4GramsPerDay))
cat("CV = ", round(sd(Summarized_Data$CH4GramsPerDay) / mean(Summarized_Data$CH4GramsPerDay) * 100, 1))


## 2. Computing daily production of gases

daily_gases_per_cow <- Summarized_Data %>%
  dplyr::mutate(day = as.Date(EndTime)) %>%
  dplyr::group_by(RFID, day) %>%
  dplyr::summarise(
    n = n(),
    minutes = sum(GoodDataDuration),
    daily_CH4 = mean(CH4GramsPerDay, na.rm = TRUE),
    daily_wmin_CH4 = weighted.mean(CH4GramsPerDay, GoodDataDuration, na.rm = TRUE)
  )

# Description of mean, sd, and CV for daily CH4
summary(daily_gases_per_cow$daily_CH4)
cat("CH4: ", mean(daily_gases_per_cow$daily_CH4), "+-", sd(daily_gases_per_cow$daily_CH4))
cat("  CV = ", round(sd(daily_gases_per_cow$daily_CH4) / mean(daily_gases_per_cow$daily_CH4) * 100, 1))

summary(daily_gases_per_cow$daily_wmin_CH4)
cat("weighted CH4: ", mean(daily_gases_per_cow$daily_wmin_CH4), "+-", sd(daily_gases_per_cow$daily_wmin_CH4))
cat("  CV = ", round(sd(daily_gases_per_cow$daily_wmin_CH4) / mean(daily_gases_per_cow$daily_wmin_CH4) * 100, 1))



## 3. Computing weekly production of gases

weekly_gases_per_cow <- Summarized_Data %>%
  dplyr::mutate(week = floor(as.numeric(difftime(as.Date(StartTime), min(as.Date(StartTime)), units = "weeks"))) + 1) %>%
  dplyr::group_by(RFID, FarmName, week) %>%
  dplyr::summarise(
    Parity = mean(Parity),
    DIM = round(mean(DIM), 1),
    n = n(),
    minutes = round(sum(GoodDataDuration), 2),
    weekly_CH4 = mean(CH4GramsPerDay),
    weekly_wmin_CH4 = weighted.mean(CH4GramsPerDay, GoodDataDuration)
  )

### Description of mean, sd, and CV for weekly CH4
summary(weekly_gases_per_cow$weekly_CH4)
cat("CH4: ", mean(weekly_gases_per_cow$weekly_CH4), "+-", sd(weekly_gases_per_cow$weekly_CH4))
cat("  CV = ", round(sd(weekly_gases_per_cow$weekly_CH4) / mean(weekly_gases_per_cow$weekly_CH4) * 100, 1))

summary(weekly_gases_per_cow$weekly_wmin_CH4)
cat("Weighted CH4: ", mean(weekly_gases_per_cow$weekly_wmin_CH4), "+-", sd(weekly_gases_per_cow$weekly_wmin_CH4))
cat("  CV = ", round(sd(weekly_gases_per_cow$weekly_wmin_CH4) / mean(weekly_gases_per_cow$weekly_wmin_CH4) * 100, 1))


##### Figures CH4 variation: Plot weekly weighted CH4 per cow

ggplot(weekly_gases_per_cow, aes(x = reorder(RFID, -weekly_wmin_CH4), y = weekly_wmin_CH4, color = weekly_wmin_CH4)) +
  geom_boxplot() +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
    legend.position = "none"
  ) +
  scale_y_continuous(
    breaks = seq(0, max(weekly_gases_per_cow$weekly_wmin_CH4) + 300, 50),
    limits = c(0, 1000)
  ) +
  labs(title = "CH4 Massflow per week", x = "", y = "Weekly CH4 (g/d)") +
  geom_hline(
    yintercept = mean(Summarized_Data$CH4GramsPerDay),
    linetype = "dashed",
    color = "#62134A",
    linewidth = 0.5
  ) +
  annotate("text",
    x = 1:length(table(weekly_gases_per_cow$RFID)),
    y = 50,
    label = table(reorder(weekly_gases_per_cow$RFID, -weekly_gases_per_cow$weekly_wmin_CH4)),
    col = "black",
    vjust = 2,
    size = 3
  )


### Description of CH4 per week

# Generate the summary table
summary_table <- Summarized_Data %>%
  mutate(week = floor(as.numeric(difftime(as.Date(Summarized_Data$StartTime), min(as.Date(Summarized_Data$StartTime)), units = "weeks"))) + 1) %>%
  dplyr::group_by(week) %>%
  dplyr::summarise(
    n = n(),
    minutes = round(sum(GoodDataDuration), 2),
    weekly_CH4 = mean(CH4GramsPerDay),
    weekly_wmin_CH4 = weighted.mean(CH4GramsPerDay, GoodDataDuration),
    SD_CH4 = sd(CH4GramsPerDay),
    CV_CH4 = sd(CH4GramsPerDay) / mean(CH4GramsPerDay) * 100
  )

# Format the summary table using kableExtra
kable(summary_table, caption = "Summary of CH4 per week") %>%
  kable_classic(full_width = FALSE) %>%
  kable_styling(bootstrap_options = c("striped", "hover"), font_size = 12) %>%
  add_header_above(c(" ", "Summary" = 6))

# Generate the plot
ggplot(weekly_gases_per_cow, aes(x = week, y = weekly_wmin_CH4, color = RFID)) +
  geom_line() +
  geom_point() +
  theme_classic() +
  theme(legend.position = "none") +
  labs(title = "CH4 Massflow per cow and per week", x = "Week", y = "Weekly CH4 (g/d)") +
  scale_y_continuous(breaks = seq(0, max(weekly_gases_per_cow$weekly_wmin_CH4), 50)) +
  scale_x_continuous(breaks = seq(1, 6), labels = c("1", "2", "3", "4", "5", "6"))




## 4. Computing Experimental production of gases

### Averaging mass flux of gases for the entire experimental period
ExpPeriod_GasesPerCow <- Summarized_Data %>%
  dplyr::mutate(day = as.Date(EndTime)) %>%
  dplyr::group_by(RFID, AnimalName, day) %>%
  dplyr::summarise( # Parity = mean(Parity),
    # DIM = round(mean(DIM),1),
    n = n(),
    minutes = round(sum(GoodDataDuration), 2),
    AvgCH4 = round(mean(CH4GramsPerDay), 2),
    AvgwCH4 = round(weighted.mean(CH4GramsPerDay, GoodDataDuration), 2),
    SD_AvgCH4 = round(sd(CH4GramsPerDay), 2),
    CV_AvgCH4 = round((sd(CH4GramsPerDay) / mean(CH4GramsPerDay)) * 100, 1)
  )


### Averaging mass flux of gases for the entire experimental period BUT USING DAILY CH4
ExpPeriod_GasesPerCow <- Summarized_Data %>%
  dplyr::mutate(day = as.Date(EndTime)) %>%
  dplyr::group_by(RFID, AnimalName, day) %>%
  dplyr::summarise(n = n(), daily_CH4 = weighted.mean(CH4GramsPerDay, GoodDataDuration, na.rm = TRUE)) %>%
  dplyr::group_by(RFID, AnimalName) %>%
  dplyr::summarise( # Parity = mean(Parity),
    # DIM = round(mean(DIM),1),
    n = n(),
    AvgCH4 = round(mean(daily_CH4), 2),
    SD_AvgCH4 = round(sd(daily_CH4), 2),
    CV_AvgCH4 = round((sd(daily_CH4) / mean(daily_CH4)) * 100, 1)
  )


### Description of mean, sd and CV for daily CH4
summary(ExpPeriod_GasesPerCow$AvgCH4)
cat("CH4: ", mean(ExpPeriod_GasesPerCow$AvgCH4), "+-", sd(ExpPeriod_GasesPerCow$AvgCH4))
cat("  CV= ", round(sd(ExpPeriod_GasesPerCow$AvgCH4) / mean(ExpPeriod_GasesPerCow$AvgCH4) * 100, 1))
# summary(ExpPeriod_GasesPerCow$AvgwCH4); cat("weighted CH4: ", mean(ExpPeriod_GasesPerCow$AvgwCH4), "+-",sd(ExpPeriod_GasesPerCow$AvgCH4))



#################################################################################




# NO COPY THESE PARTS (ONLY TO CHECK)!!!!!

#### PROCESSING FEED EFFICIENCY DATA ############################################

# DRY MATTER INTAKE (DMI)

## Read daily intakes
# Feed intakes
file_path <- paste0("~/GreenFeed_UW/Methane/", selected_experiment, "/FeedEfficiency_Data/Intake_DM/Daily Feed Intakes.xlsx")
Daily_Feed_Intakes <- read_excel(file_path, col_types = c("date", "text", "numeric", "numeric", "numeric"))

# Pellet intakes
file_path <- paste0("~/GreenFeed_UW/Methane/", selected_experiment, "/FeedEfficiency_Data/Pellet_intake/Pellet_Intakes_0423to0527.txt")
Pellet_Intakes <- read_table(file_path, col_types = cols(RFID = col_character(), COW = col_character()))

# Include in the list the number of pellet bags used and the DM in each one
DM_of_pellets <- list(bag1 = 0.9726, bag2 = 0.9162)

## Dry matter (DM) of pellets depending on the week
Pellet_Intakes$DM <- case_when(
  Pellet_Intakes$Date <= as.Date("2023-05-14") ~ DM_of_pellets[["bag1"]],
  Pellet_Intakes$Date >= as.Date("2023-05-15") & Pellet_Intakes$Date < as.Date("2023-05-20") ~ (DM_of_pellets[["bag1"]] + DM_of_pellets[["bag2"]]) / 2,
  Pellet_Intakes$Date >= as.Date("2023-05-20") ~ DM_of_pellets[["bag2"]],
  TRUE ~ 0
)

## Calculate DMI as the amount of pellet intakes in kg by the dry matter of pellets
Pellet_Intakes$DMI <- Pellet_Intakes$Intake_AP_kg * Pellet_Intakes$DM

## Do addition between Feed and Pellet intakes
Daily_intakes <- Daily_Feed_Intakes %>% inner_join(Pellet_Intakes, by = c("COW", "DATE" = "Date"))
Daily_intakes$DMI_total <- Daily_intakes$DMI.x + Daily_intakes$DMI.y

## Generate weekly intakes for each cow
Dry_matter_intakes <- Daily_intakes %>%
  dplyr::mutate(week = floor(as.numeric(difftime(as.Date(DATE), min(as.Date(DATE)), units = "weeks"))) + 1) %>% # Creating the week based on the start date of experiment
  dplyr::group_by(COW, week) %>%
  dplyr::summarise(n = n(), Avg_DMI = mean(DMI_total, na.rm = T)) # Grouping by cow and week to obtain the average DMI

colnames(Dry_matter_intakes) <- c("Visible_ID", "week", "n", "DMI")


############### USE THIS CODE IN CASE YOU HAVE THE RAW FEED INTAKES PER COW PER DAY TO OBTAIN DRY MATTER INTAKE
## Read the dry matter per week
# DM105C_feed <- list(week0 = 0.5329, week1 = 0.5201, week2 = 0.5014, week3 = 0.5313, week4 = 0.5280, week5 = 0.5289)

### Calculating DMI based on the DM week (computed from the start date)
# FeedEfficiency_data <- Daily_Feed_Intakes %>%
#  dplyr::mutate(week = floor(as.numeric(difftime(as.Date(DATE), min(as.Date(DATE)), units = "weeks"))) + 1) %>% #Creating the week based on the start date of experiment
#  dplyr::mutate(DMI = ifelse(week == 1, `Feed Intake AS FED, kg`*DM105C_feed$week1,
#                             ifelse(week == 2, `Feed Intake AS FED, kg`*DM105C_feed$week2,
#                                    ifelse(week == 3, `Feed Intake AS FED, kg`*DM105C_feed$week3,
#                                           ifelse(week ==4, `Feed Intake AS FED, kg`*DM105C_feed$week4,
#                                                  ifelse(week ==5, `Feed Intake AS FED, kg`*DM105C_feed$week5,99999)))))) %>% #Multiplying the daily feed intake by the corresponding DM
#  dplyr::group_by(COW, week) %>% dplyr::summarise(n = n(), Avg_DMI = mean(DMI)) #Grouping by cow and week to obtain the average DMI




# BODY WEIGHTS (BW) AND METABOLIC BODY WEIGHTS (mBW)

## Read body weights in pounds(lb)
file_path <- paste0("~/GreenFeed_UW/Methane/", selected_experiment, "/FeedEfficiency_Data/Body_Weights/HMW668 BW.BCS.HH.xlsx")
Body_weights_lb <- read_excel(file_path, col_types = c("text", rep("numeric", 18)))

## Transform body weights in kg and then calculate metabolic BW (mBW) with BW in kg
Body_weights_kg <- (Body_weights_lb[, c(1:4, 8:10, 14:16)])
Body_weights_kg[, c(2:10)] <- (Body_weights_kg[, c(2:10)] / 2.205)^0.75

## Calculate the average and SD of the mBW per cow
for (i in 1:nrow(Body_weights_kg)) {
  Body_weights_kg$Average_mBW_1[i] <- sum(Body_weights_kg[i, 2:4], na.rm = T) / sum(!is.na(Body_weights_kg[i, 2:4]))
  Body_weights_kg$Average_mBW_4[i] <- sum(Body_weights_kg[i, 5:7], na.rm = T) / sum(!is.na(Body_weights_kg[i, 5:7]))
  Body_weights_kg$Average_mBW_7[i] <- sum(Body_weights_kg[i, 8:10], na.rm = T) / sum(!is.na(Body_weights_kg[i, 8:10]))

  Body_weights_kg$Average_mBW[i] <- round(sum(Body_weights_kg[i, 11:13], na.rm = T) / sum(!is.na(Body_weights_kg[i, 11:13])), 1)
  Body_weights_kg$SD_mBW[i] <- round(sd(Body_weights_kg[i, 11:13], na.rm = T), 1)
}

metabolic_BW <- Body_weights_kg[, c(1, 14:15)]
colnames(metabolic_BW) <- c("Visible_ID", "mBW", "SD_mBW")



# DELTA BODY WEIGHTS (deltaBW)

# Read body weights in pounds (lb)
file_path <- paste0("~/GreenFeed_UW/Methane/", selected_experiment, "/FeedEfficiency_Data/Body_Weights/HMW668 BW.BCS.HH.xlsx")
Body_weights_lb <- read_excel(file_path, col_types = c("text", rep("numeric", 18)))

## Transform body weights to kg
Body_weights_kg <- Body_weights_lb %>%
  select(c(1:4, 8:10, 14:16)) %>%
  mutate(across(-1, ~ . / 2.205)) %>%
  rename_with(~ c("CowID", "2023-04-18", "2023-04-19", "2023-04-20", "2023-05-09", "2023-05-10", "2023-05-11", "2023-05-30", "2023-05-31", "2023-06-01"), 1:10)


## Create a table with all dates in the experiment
dates <- seq(as.Date("2023-04-16"), as.Date("2023-06-02"), by = "day")
data <- expand.grid(Visible_ID = unique(Body_weights_kg$Visible_ID), date = dates, value = NA)

## Melt Body_weights_kg
delta_BW <- reshape2::melt(Body_weights_kg)

## Match CowID and date to assign values
data$value <- delta_BW$value[match(paste(data$CowID, as.character(data$date)), paste(delta_BW$CowID, delta_BW$variable))]

# Do the liner regression to obtain the predicted BW for each day
data <- data[order(data$CowID, data$date), ]
BWhat <- data %>%
  split(.$CowID) %>% # group_by(CowID)
  map(~ predict(lm(value ~ date, data = .x), newdata = .x)) %>%
  map_df(~ as.data.frame(.x), .id = "CowID")

names(BWhat)[2] <- "BWhat"
data$BWhat <- BWhat$BWhat

### Check the range of predicted BW obtained
summary(data$BWhat)
plot(data$BWhat[data$CowID == "121"], data$date[data$CowID == "121"])

## Calculate weekly deltaBW for each cow
delta_BW <- data %>%
  dplyr::mutate(week = floor(as.numeric(difftime(as.Date(data$date), min(as.Date(data$date)), units = "weeks"))) + 1) %>%
  dplyr::group_by(CowID, week) %>%
  dplyr::summarize(BWhat = last(BWhat) - first(BWhat)) %>%
  dplyr::group_by(CowID) %>%
  dplyr::summarise(BWhat = mean(BWhat))

# Rename columns
colnames(delta_BW) <- c("Visible_ID", "deltaBW")

## Join weekly delta BW and metabolic BW
metabolic_BW <- metabolic_BW %>% inner_join(delta_BW, by = "Visible_ID")




# MILK ENERGY (MilkE)

## Read milk weights
file_path <- paste0("~/GreenFeed_UW/Methane/", selected_experiment, "/FeedEfficiency_Data/Milk_Weights/UW_HMW668_MilkWeightsYYYYMMDD.xlsx")
MilkWeights <- read_excel(file_path, col_types = c("skip", "date", "text", "text", rep("numeric", 2)))

## Read milk composition
file_path <- paste0("~/GreenFeed_UW/Methane/", selected_experiment, "/FeedEfficiency_Data/Milk_composition/UW_HMW668_MilkCompositionYYYYMMDD.xlsx")
MilkComposition <- read_excel(file_path, col_types = c("skip", "date", "text", "text", rep("numeric", 6)))

## Join milk weights and composition
Milk_energy <- MilkWeights %>% inner_join(MilkComposition, by = c("MilkNum", "Date", "Visible_ID"))

# Transform components in % to kg
Milk_energy$Fat_kg <- Milk_energy$MilkKg * (Milk_energy$FatPct / 100)
Milk_energy$Prot_kg <- Milk_energy$MilkKg * (Milk_energy$PrtPct / 100)
Milk_energy$Lact_kg <- Milk_energy$MilkKg * (Milk_energy$LacPct / 100)

### Remove data before Experimental start date
Start_ExpDate <- "2023-04-23"
Milk_energy <- Milk_energy[Milk_energy$Date >= as.Date(Start_ExpDate), ]


# Calculate daily milk components per cow
Daily_milkE <- Milk_energy %>%
  dplyr::mutate(week = floor(as.numeric(difftime(as.Date(Date), min(as.Date(Date)), units = "weeks"))) + 1) %>%
  dplyr::group_by(Visible_ID, week, MilkNum) %>%
  # Calculate daily components in kg
  dplyr::summarise(daily_Fat_kg = sum(Fat_kg), daily_Prot_kg = sum(Prot_kg), daily_Lact_kg = sum(Lact_kg)) %>%
  # Calculate daily milk energy based on the following formula:
  dplyr::mutate(milkE = (9.29 * daily_Fat_kg) + (5.63 * daily_Prot_kg) + (3.95 * daily_Lact_kg)) %>%
  # Do the average of milk energy per week
  dplyr::group_by(Visible_ID, week) %>%
  dplyr::summarise(n = n(), milkE = mean(milkE))




# JOIN DRY MATTER INTAKE, METABOLIC BW AND MILKE TABLES

# Inner join of DMI and mIlkE using the Id and week
Feed_efficiency_data <- inner_join(Dry_matter_intakes %>% select(-n), Daily_milkE %>% select(-n), by = c("Visible_ID", "week"))

# Adding the mBW to the feed efficiency table
Feed_efficiency_data <- left_join(Feed_efficiency_data, metabolic_BW %>% select(Visible_ID, mBW, deltaBW), by = "Visible_ID")



# COMBINING FEED EFFICIENCY DATA AND GAS PRODUCTION DATA

# Inner join of feed efficiency data and daily gases
FeedE_and_gas_data <- weekly_gases_per_cow %>% inner_join(Feed_efficiency_data, by = c("FarmName" = "Visible_ID", "week"))

### Average the data for the experimental period per cow
FeedE_and_gas_expdata <- FeedE_and_gas_data %>%
  dplyr::group_by(RFID, FarmName) %>%
  dplyr::summarise(
    n_visits = sum(n),
    n_min = sum(minutes),
    Parity = mean(Parity),
    DIM = round(mean(DIM, na.rm = T), 1),
    CH4 = round(mean(weekly_CH4, na.rm = T), 2),
    wCH4 = round(mean(weekly_wmin_CH4, na.rm = T), 2),
    DMI = round(mean(DMI, na.rm = T), 2),
    milkE = round(mean(milkE, na.rm = T), 2),
    mBW = round(mean(mBW, na.rm = T), 2),
    deltaBW = round(mean(deltaBW, na.rm = T), 2)
  )


## Remove all the animals with less than the define threshold of visits: =14
FeedE_and_gas_expdata <- FeedE_and_gas_expdata[FeedE_and_gas_expdata$n_visits >= 14, ]

#################################################################################


#### MODELS FOR RESIDUAL FEED INTAKE AND RESIDUAL CH4 ###########################

## Defining fixed effects
### Parity
FeedE_and_gas_expdata$Parity[FeedE_and_gas_expdata$Parity > 4] <- 4
FeedE_and_gas_expdata$Parity <- as.character(FeedE_and_gas_expdata$Parity)

### Days in milk
FeedE_and_gas_expdata$DIM[FeedE_and_gas_expdata$DIM <= 110] <- "1"
FeedE_and_gas_expdata$DIM[FeedE_and_gas_expdata$DIM > 110] <- "2"


# RESIDUAL FEED INTAKE
## Calculating RFI based on linear model
model_RFI <- lm(DMI ~ milkE + mBW + deltaBW + Parity + DIM, data = FeedE_and_gas_expdata)
Anova(model_RFI)
FeedE_and_gas_expdata$RFI <- model_RFI$residuals


# RESIDUAL METHANE MODELS
## Computing the residual CH4 based on two linear models

## Model 1: CH4 = week + Parity + DIM + MilkE + mBW + e
model1.1 <- lm(CH4 ~ Parity + DIM + milkE + mBW, data = FeedE_and_gas_expdata)
model1.2 <- lm(wCH4 ~ Parity + DIM + milkE + mBW, data = FeedE_and_gas_expdata)

### Summary of the model and ANOVA
model1.1
Anova(model1.1)

model1.2
Anova(model1.2)

### Checking model assumptions
plot(residuals(model1.2) ~ fitted(model1.2), ylab = "Raw Residuals", xlab = "Fitted Values", pch = 20)
qqnorm(residuals(model1.2), pch = 15)
qqline(residuals(model1.2), col = "darkgreen", lwd = 2, lty = 3)
shapiro.test(residuals(model1.2))

### Residuals
FeedE_and_gas_expdata$"CH4|MilkE,mBW" <- model1.1$residuals
FeedE_and_gas_expdata$"wCH4|MilkE,mBW" <- model1.2$residuals


## Model 2: CH4 = week + Parity + DIM + DMI + e
model2.1 <- lm(CH4 ~ Parity + DIM + DMI, data = FeedE_and_gas_expdata)
model2.2 <- lm(wCH4 ~ Parity + DIM + DMI, data = FeedE_and_gas_expdata)

### Summary of the model and ANOVA
model2.1
Anova(model2.1)

model2.2
Anova(model2.2)

### Checking model assumptions
plot(residuals(model2.2) ~ fitted(model2.2), ylab = "Raw Residuals", xlab = "Fitted Values", pch = 20)
qqnorm(residuals(model2.2), pch = 15)
qqline(residuals(model2.2), col = "darkgreen", lwd = 2, lty = 3)
shapiro.test(residuals(model2.2))

### Residuals
FeedE_and_gas_expdata$"CH4|DMI" <- model2.1$residuals
FeedE_and_gas_expdata$"wCH4|DMI" <- model2.2$residuals


## Spearman correlations between residual traits, and with energy sinks
### Correlations between residual CH4 traits
rCH4 <- FeedE_and_gas_expdata[, c("CH4|MilkE,mBW", "wCH4|MilkE,mBW", "CH4|DMI", "wCH4|DMI")]
cor(rCH4, method = "spearman")

## Correlations between residuals CH4 traits and Feed efficiency
rCH4_FE <- FeedE_and_gas_expdata[, c("RFI", "DMI", "mBW", "milkE", "wCH4", "wCH4|MilkE,mBW", "wCH4|DMI")]
cor(rCH4_FE, method = "spearman")


## Selecting extreme positive and negative cows for CH4
ExtremeP <- as.data.table(FeedE_and_gas_expdata) %>%
  dplyr::arrange(-`wCH4|DMI`, -`wCH4|MilkE,mBW`) %>%
  dplyr::slice_head(n = 8)

ExtremeN <- as.data.table(FeedE_and_gas_expdata) %>%
  dplyr::arrange(-`wCH4|DMI`, -`wCH4|MilkE,mBW`) %>%
  dplyr::slice_tail(n = 8)

ExtremeCH4_cows <- rbind(ExtremeP, ExtremeN)


## Plot residual CH4 grouping by extreme cows
FeedE_and_gas_expdata %>%
  ggplot(aes(x = `wCH4|MilkE,mBW`, y = `wCH4|DMI`)) +
  geom_point(size = 2.5) +
  geom_point(data = FeedE_and_gas_expdata %>% filter(RFID %in% ExtremeCH4_cows$RFID)) +
  theme_classic() +
  theme(legend.position = "none") +
  labs(title = "", x = "CH4 | MilkE, mBW", y = "CH4 | DMI") +
  geom_label(
    data = subset(FeedE_and_gas_expdata, FarmName %in% ExtremeCH4_cows$FarmName),
    aes(fill = factor(FarmName), label = FarmName),
    colour = "black",
    fontface = "bold",
    size = 3
  )

## Write a table with the extreme cows to sampling in the farm
write.table(ExtremeCH4_cows, file = "~/Downloads/CowID_Sampling_05302023.txt", row.names = F, quote = F)



## Variation of methane across weeks for those selected extreme
ExtremeCH4_weekly <- WeeklyGasesPerCow[WeeklyGasesPerCow$RFID %in% ExtremeCH4_cows$RFID, ]
ExtremeCH4_weekly$group <- ifelse(ExtremeCH4_weekly$RFID %in% ExtremeP$RFID, "P", "N")

ggplot(ExtremeCH4_weekly, aes(x = week, y = weekly_wmin_CH4, group = RFID)) +
  geom_line(aes(color = group)) +
  # geom_point() +
  theme_classic() +
  theme(legend.position = "none") +
  labs(title = "CH4 Massflow per cow and per week", x = "Week", y = "Weekly CH4 (g/d)") +
  scale_y_continuous(breaks = c(seq(0, max(WeeklyGasesPerCow$weekly_wmin_CH4), 50))) +
  geom_label(
    data = subset(ExtremeCH4_weekly, `Farm Name` %in% ExtremeCH4_weekly$`Farm Name`),
    aes(fill = factor(group), label = `Farm Name`),
    colour = "black",
    fontface = "bold",
    size = 3
  )


#################################################################################
