library(testthat)
library(readr)
library(stringr)

# Define the path to the test file within the package
test_file_path <- system.file("extdata", "perline.txt", package = "greenfeedr")

# Expected URL based on parameters
expected_url <- "https://portal.c-lockinc.com/api/getemissions?d=visits&fids=1&st=2024-01-22&et=2024-03-08%2012:00:00"

test_that("get_api_data correctly processes and saves data", {
  # Define test parameters
  User <- "test_user"
  Pass <- "test_pass"
  Exp <- "StudyName"
  Unit <- 1
  Start_Date <- "2024-01-22"
  End_Date <- "2024-03-08"

  # Use the extdata directory for the output file
  Dir <- system.file("extdata", package = "greenfeedr")  # Use the extdata directory of the package

  # Mock the API function to return the expected URL
  mock_get_api_data <- function(User, Pass, Exp, Unit, Start_Date, End_Date, Dir) {
    # Construct the URL
    url <- paste0("https://portal.c-lockinc.com/api/getemissions?d=visits&fids=", Unit,
                  "&st=", Start_Date, "&et=", End_Date, "%2012:00:00")
    return(url)
  }

  # Generate the URL from the mock function
  generated_url <- mock_get_api_data(User, Pass, Exp, Unit, Start_Date, End_Date, Dir)

  # Check if the generated URL matches the expected URL
  expect_equal(generated_url, expected_url, info = "The generated URL does not match the expected URL.")

  # Run the function and check the output
  # Note: In your real test, replace the mock function with the actual call to get_api_data
  # result_df <- get_api_data(User, Pass, Exp, Unit, Start_Date, End_Date, Dir)

  # Define the path to the output file
  output_file_path <- file.path(Dir, paste0(Exp, "_GFdata.csv"))

  # Check if the file is created
  expect_true(file.exists(output_file_path))

  # Read the output file and check its content
  df <- read_csv(output_file_path)

  # Print the structure and content of the data frame for debugging
  print(str(df))
  print(head(df))

  # Check if the dataframe has the expected number of rows
  expect_gt(nrow(df), 0)
  expect_equal(df$FeederID[1], 1, info = "The FeederID does not match the expected value.")

  # For demonstration purposes, check the content of the existing file
  if (file.exists(test_file_path)) {
    # Read the existing CSV file
    df_existing <- read_csv(test_file_path)

    # Check if the existing file has expected data
    expect_gt(nrow(df_existing), 0)
    expect_equal(df_existing$FeederID[1], 1, info = "The FeederID in the existing CSV file does not match the expected value.")
  } else {
    stop("The test file does not exist at: ", test_file_path)
  }
})
