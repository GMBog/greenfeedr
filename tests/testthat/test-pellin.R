# Define paths to example files in the extdata directory
feedtimes_file <- system.file("extdata", "feedtimes.csv", package = "greenfeedr")
rfid_file_path <- system.file("extdata", "RFID_file.csv", package = "greenfeedr")

# Read RFID file for comparison
rfid_file <- read_csv(rfid_file_path, col_types = cols(.default = col_character()))

# Test if pellin processes data correctly
test_that("pellin processes data correctly", {
  # Ensure the files exist
  expect_true(file.exists(feedtimes_file))
  expect_true(file.exists(rfid_file_path))

  # Define the save directory and output file path
  save_dir <- tempdir()
  output_file <- file.path(save_dir, paste0("Pellet_Intakes_", "2024-05-13", "_", "2024-05-25", ".csv"))

  # Run pellin function
  pellin(
    unit = 1,
    gcup = 34,
    start_date = "2024-05-13",
    end_date = "2024-05-25",
    save_dir = save_dir,
    rfid_file = rfid_file,
    file_path = feedtimes_file
  )

  # Check if the file was created
  expect_true(file.exists(output_file))

  # Read and validate the content of the saved file
  result <- read_csv(output_file, col_types = cols(.default = col_character()))

  # Example assertions to check the output
  expect_s3_class(result, "data.frame") # Ensure the output is a data frame
  expect_true(nrow(result) > 0) # Check that the result is not empty

  # Validate the structure and contents of the result
  expect_true("Date" %in% names(result))
  expect_true("PIntake_kg" %in% names(result))
})

# Test handling of missing RFID file
test_that("pellin handles missing RFID file", {
  # Define the save directory and output file path
  save_dir <- tempdir()
  output_file <- file.path(save_dir, paste0("Pellet_Intakes_", "2024-05-13", "_", "2024-05-25", ".csv"))

  # Run pellin function with missing RFID file
  pellin(
    file_path = feedtimes_file,
    unit = 1,
    gcup = 34,
    start_date = "2024-05-13",
    end_date = "2024-05-25",
    save_dir = save_dir
  )

  # Check if the file was created
  expect_true(file.exists(output_file))

  # Read and validate the content of the saved file
  result <- read_csv(output_file, col_types = cols(.default = col_character()))

  # Example assertions to check the output
  expect_s3_class(result, "data.frame") # Ensure the output is a data frame
  expect_true(nrow(result) > 0) # Check that the result is not empty

  # Validate the structure and contents of the result
  expect_true("Date" %in% names(result))
  expect_true("PIntake_kg" %in% names(result))
})
