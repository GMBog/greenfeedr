test_that("process_gfdata works correctly", {
  # Define parameters for the test
  start_date <- "2024-05-13"
  end_date <- "2024-05-25"
  param1 <- 2
  param2 <- 3
  min_time <- 2

  # Use a small sample of GreenFeed data for testing purposes
  file <- system.file("extdata", "StudyName_FinalReport.xlsx", package = "greenfeedr")
  data <- read_excel(file)

  # Suppress warnings and run the function
  result <- process_gfdata(data, start_date, end_date, param1, param2, min_time)

  # Check that the result is a list with two elements
  expect_type(result, "list")
  expect_length(result, 2)

  # Check that the list contains data frames
  expect_s3_class(result$daily_data, "data.frame")
  expect_s3_class(result$weekly_data, "data.frame")

  # Check that the daily data has the expected columns
  expect_true(all(c("RFID", "week", "n", "minutes", "CH4GramsPerDay", "CO2GramsPerDay", "O2GramsPerDay", "H2GramsPerDay") %in% colnames(result$daily_data)))

  # Check that the weekly data has the expected columns
  expect_true(all(c("RFID", "week", "nDays", "nRecords", "TotalMin", "CH4GramsPerDay", "CO2GramsPerDay", "O2GramsPerDay", "H2GramsPerDay") %in% colnames(result$weekly_data)))

  # Check that the daily data has filtered out days with less than `param1` records
  expect_true(all(result$daily_data$n >= param1))

  # Check that the weekly data has filtered out weeks with less than `param2` days
  expect_true(all(result$weekly_data$nDays >= param2))

  # Check for valid mean, sd, and CV calculations
  expect_true(!is.na(mean(result$weekly_data$CH4GramsPerDay)))
  expect_true(!is.na(sd(result$weekly_data$CH4GramsPerDay)))
  expect_true(!is.na(sd(result$weekly_data$CH4GramsPerDay) / mean(result$weekly_data$CH4GramsPerDay) * 100))
})
