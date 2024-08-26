# Define paths to example files in the extdata directory
feedtimes_file <- system.file("extdata", "feedtimes.csv", package = "greenfeedr")
rfid_file <- system.file("extdata", "RFID_file.txt", package = "greenfeedr")

RFID_file <- read_table(rfid_file, col_types = cols(RFID = col_character()))

# Test if pellin processes data correctly
test_that("pellin processes data correctly", {
  # Ensure the files exist
  expect_true(file.exists(feedtimes_file))
  expect_true(file.exists(rfid_file))

  # Run pellin function
  result <- pellin(
    file_path = feedtimes_file,
    unit = 1,
    gcup = 34,
    start_date = "2024-05-13",
    end_date = "2024-05-25",
    save_dir = tempdir(),
    rfid_file = rfid_file
  )

  # Example assertions to check the output
  expect_s3_class(result, "data.frame") # Assuming pellin returns a data frame
  expect_true(nrow(result) > 0) # Check that the result is not empty

  # Assert that no RFID tags are missing
  expect_equal(length(unique(result$FarmName)), nrow(RFID_file))
})

# Test handling of missing RFID file
test_that("pellin handles missing RFID file", {
  # Run pellin function with missing RFID file
  result <- pellin(
    file_path = feedtimes_file,
    unit = 1,
    gcup = 34,
    start_date = "2024-05-13",
    end_date = "2024-05-25",
    save_dir = tempdir()
  )

  # Example assertions to check the output when RFID file is missing
  expect_s3_class(result, "data.frame") # Assuming pellin returns a data frame
  expect_true(nrow(result) > 0) # Check that the result is not empty
})
