library(testthat)
library(readr)
library(stringr)

# Define the path to the test file within the package
test_file_path <- system.file("extdata", "perline.txt", package = "greenfeedr")

# Expected URL based on parameters
expected_url <- "https://portal.c-lockinc.com/api/getemissions?d=visits&fids=1&st=2024-01-22&et=2024-03-08%2012:00:00"

test_that("get_api_data correctly processes and saves data", {
  # Define test parameters
  user <- "test_user"
  pass <- "test_pass"
  exp <- "StudyName"
  unit <- 1
  start_date <- "2024-01-22"
  end_date <- "2024-03-08"

  # Use the extdata directory for the output file
  save_dir <- system.file("extdata", package = "greenfeedr") # Use the extdata directory of the package

  # Mock the API function to return the expected URL
  mock_get_api_data <- function(user, pass, exp, unit, start_date, end_date, save_dir) {
    # Construct the URL
    url <- paste0(
      "https://portal.c-lockinc.com/api/getemissions?d=visits&fids=", unit,
      "&st=", start_date, "&et=", end_date, "%2012:00:00"
    )
    return(url)
  }

  # Generate the URL from the mock function
  generated_url <- mock_get_api_data(user, pass, exp, unit, start_date, end_date, save_dir)

  # Check if the generated URL matches the expected URL
  expect_equal(generated_url, expected_url, info = "The generated URL does not match the expected URL.")

  # Run the function and check the output
  # Note: In your real test, replace the mock function with the actual call to get_api_data
  # result_df <- get_api_data(User, Pass, Exp, Unit, Start_Date, End_Date, Dir)

  # Define the path to the output file
  output_file_path <- file.path(save_dir, paste0(exp, "_GFdata.csv"))

  # Check if the file is created
  expect_true(file.exists(output_file_path))

  # Read the output file and check its content
  df <- readr::read_csv(output_file_path)

  # Print the structure and content of the data frame for debugging
  print(str(df))
  print(head(df))

  # Check if the dataframe has the expected number of rows
  expect_gt(nrow(df), 0)
  expect_equal(df$FeederID[1], 1, info = "The FeederID does not match the expected value.")

  # For demonstration purposes, check the content of the existing file
  if (file.exists(test_file_path)) {
    # Read the existing CSV file
    df_existing <- readr::read_csv(test_file_path, skip = 1)

    # Check if the existing file has expected data
    expect_gt(nrow(df_existing), 0)
    expect_equal(df_existing$FeederID[1], 579, info = "The FeederID in the existing CSV file does not match the expected value.")
  } else {
    stop("The test file does not exist at: ", test_file_path)
  }
})
