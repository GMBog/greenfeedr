# Define the paths to the files in the package's extdata directory
feedtimes_file <- system.file("extdata", "feedtimes.csv", package = "greenfeedr")
rfid_file <- system.file("extdata", "RFID_file.csv", package = "greenfeedr")

# Tests
test_that("viseat handles unsupported file formats", {
  # Create a dummy unsupported file
  unsupported_file <- tempfile(fileext = ".docx")
  writeLines(c("dummy data"), unsupported_file)

  expect_error(
    {
      result <- viseat(
        unit = 1,
        start_date = "2024-05-13",
        end_date = "2024-05-25",
        rfid_file = unsupported_file,
        file_path = feedtimes_file
      )
    },
    "Unsupported file format."
  )
})

test_that("viseat returns a list with the correct structure", {
  result <- viseat(
    file_path = feedtimes_file,
    unit = 1,
    start_date = "2024-05-13",
    end_date = "2024-05-25",
    rfid_file = rfid_file
  )

  expect_type(result, "list")
  expect_length(result, 3)
  expect_true("feedtimes" %in% names(result))
  expect_true("visits_per_day" %in% names(result))
  expect_true("visits_per_animal" %in% names(result))

  expect_s3_class(result$visits_per_day, "data.frame")
  expect_s3_class(result$visits_per_animal, "data.frame")
})

test_that("viseat returns correct content in data frames", {
  result <- viseat(
    unit = 1,
    start_date = "2024-05-13",
    end_date = "2024-05-25",
    rfid_file = rfid_file,
    file_path = feedtimes_file
  )

  # Check content of visits_per_unit
  expect_equal(nrow(result$visits_per_day), 156) # Adjust based on actual data
  expect_equal(names(result$visits_per_day), c("FarmName", "Date", "FoodType", "ndrops", "visits"))

  # Check content of visits_per_animal
  expect_equal(nrow(result$visits_per_animal), 12) # Adjust based on actual data
  expect_equal(names(result$visits_per_animal), c("FarmName", "FoodType", "total_drops", "total_visits", "mean_drops", "mean_visits"))
})
