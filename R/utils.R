
.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    "Thank you for using the greenfeedr package!\n",
    "Cite: Martinez-Boggio et al. (2024). Greenfeedr: an R-package for processing and reporting GreenFeed data.\n",
    "Type 'help(greenfeedr)' for summary information"
  )
}

#' @name has_credentials
#' @title Check for 'API' Credentials
#'
#' @description Check if necessary 'API' credentials are available in the environment.
#'
#' @return A logical value: `TRUE` if both `API_USER` and `API_PASS` environment variables are set (i.e., not `NA`); `FALSE` otherwise
#' @examples
#' # Example 1: When environment variables are set
#' Sys.setenv(API_USER = "my_username", API_PASS = "my_password")
#' has_credentials()
#' # Expected output: TRUE
#'
#' # Example 2: When one or both environment variables are not set
#' Sys.unsetenv("API_USER")
#' Sys.unsetenv("API_PASS")
#' has_credentials()
#' # Expected output: FALSE
#'
#' # Clean up by removing environment variables
#' Sys.unsetenv("API_USER")
#' Sys.unsetenv("API_PASS")
#'
#' @export
#' @keywords internal
has_credentials <- function() {
  !is.na(Sys.getenv("API_USER", unset = NA)) && !is.na(Sys.getenv("API_PASS", unset = NA))
}


#' @name ensure_date_format
#' @title Check date format and transform in a usable one
#'
#' @description Check date format. If the format is wrong ('NA') an error message is printed,
#'     else it will formatted the date in the correct way (YYYY-MM-DD)
#'
#' @param date_input Date included as input
#'
#' @return A character string representing the date in 'YYYY-MM-DD' format
#' @examples
#' # Example of correct date formats
#' ensure_date_format("2024-08-30") # "2024-08-30"
#' ensure_date_format("08/30/2024") # "2024-08-30"
#' ensure_date_format("30/08/2024") # "2024-08-30"
#'
#' # Example of incorrect date formats
#' tryCatch(
#'   {
#'     ensure_date_format("Aug-30")
#'   },
#'   error = function(e) {
#'     message(e$message)
#'   }
#' )
#'
#' @export
#' @keywords internal
ensure_date_format <- function(date_input) {
  # Attempt to parse the input into a Date object
  date_obj <- tryCatch(
    {
      # Use lubridate's parsing functions
      parsed_date <- ymd(date_input, quiet = TRUE)
      if (is.na(parsed_date)) parsed_date <- mdy(date_input, quiet = TRUE)
      if (is.na(parsed_date)) parsed_date <- dmy(date_input, quiet = TRUE)

      # Check if the date is still NA
      if (is.na(parsed_date)) stop("Invalid date format. Please provide a recognizable date format.")

      return(parsed_date)
    },
    error = function(e) {
      stop("Error processing date: ", e$message)
    }
  )

  # Return the date in 'YYYY-MM-DD' format
  return(format(date_obj, "%Y-%m-%d"))
}


#' @name filter_within_range
#' @title Detect outliers in data using mean and standard deviation
#'
#' @description Detect outliers using the mean and standard deviation.
#'
#' @param v A vector with data
#' @param cutoff A threshold or cutoff value that defines the range (e.g., 3)
#'
#' @return A logical vector of the same length as `v`, where each element is `TRUE` if the corresponding value in `v` falls within the specified range, and `FALSE` otherwise.
#' @examples
#' # Sample data
#' data <- c(10, 12, 14, 15, 20, 25, 30, 100)
#'
#' # Detect values within 3 standard deviations from the mean
#' filter_within_range(data, cutoff = 3)
#'
#' # Result:
#' # [1] TRUE TRUE TRUE TRUE TRUE TRUE TRUE TRUE
#' # Explanation: All values fall within 2.5 standard deviations from the mean.
#'
#' # Detect values within 1 standard deviation from the mean
#' filter_within_range(data, cutoff = 1)
#'
#' # Result:
#' # [1] TRUE TRUE TRUE TRUE TRUE TRUE TRUE FALSE
#' # Explanation: All values except 100 fall within 1 standard deviation from the mean.
#'
#' @export
#' @keywords internal
filter_within_range <- function(v, cutoff) {
  mean_v <- mean(v, na.rm = TRUE)
  sd_v <- sd(v, na.rm = TRUE)
  v >= (mean_v - cutoff * sd_v) & v <= (mean_v + cutoff * sd_v)
}


#' @name process_rfid_data
#' @title Process RFID Data
#'
#' @description Processes RFID data from animals in the study.
#'
#' @param rfid_file Path or data frame containing RFID data.
#'
#' @return A data frame with standardized column names (`FarmName` and `RFID`). If the input is invalid or if no valid data is provided, the function returns `NULL`.
#'
#' @examples
#' # Example with a data frame
#' df <- data.frame(
#'   V1 = c("Farm1", "Farm2", "Farm3"),
#'   V2 = c("12345", "67890", "54321")
#' )
#' processed_df <- process_rfid_data(df)
#' message(processed_df)
#'
#' # Example with invalid input
#' invalid_data <- process_rfid_data(NULL)
#' # Expected output: message "RFID is NA. It is recommended to include it." and NULL
#' message(invalid_data)
#'
#' # Example with unsupported file format
#' # Assuming 'rfid_data.docx' is an unsupported file format
#' invalid_file <- process_rfid_data("path/to/rfid_data.docx")
#' # Expected output: error message "Unsupported file format."
#' message(invalid_file)
#'
#' @export
#' @keywords internal
process_rfid_data <- function(rfid_file) {
  # Standardize column names function
  standardize_columns <- function(df) {
    if (ncol(df) < 2) {
      stop("The data frame must contain at least two columns.")
    }
    names(df)[1:2] <- c("FarmName", "RFID")
    df <- df %>%
      dplyr::mutate(across(1:2, as.character))
    return(df)
  }

  # Check if rfid_file is NA
  if (is.null(rfid_file)) {
    message("RFID is NULL. It is recommended to include it.")
    return(NULL)
  }

  # Check if rfid_file is a data frame
  if (is.data.frame(rfid_file)) {
    rfid_file <- standardize_columns(rfid_file)
    return(rfid_file)
  }

  # Check if rfid_file is a file path
  if (is.character(rfid_file) && file.exists(rfid_file)) {
    file_extension <- tolower(tools::file_ext(rfid_file))
    tryCatch(
      {
        if (file_extension == "csv") {
          rfid_file <- readr::read_csv(rfid_file, col_types = readr::cols(.default = readr::col_character()))
        } else if (file_extension %in% c("xls", "xlsx")) {
          rfid_file <- readxl::read_excel(rfid_file) %>%
            dplyr::mutate(across(everything(), as.character))
        } else if (file_extension == "txt") {
          rfid_file <- readr::read_table(rfid_file, col_types = readr::cols(.default = readr::col_character()))
        } else {
          stop("Unsupported file format.")
        }
        rfid_file <- standardize_columns(rfid_file)
        return(rfid_file)
      },
      error = function(e) {
        stop("An error occurred while reading the file: ", e$message)
      }
    )
  }

  # If none of the conditions are met
  message("No valid data provided. Please include a valid 'rfid_file' parameter.")
  return(NULL)
}



#' @name convert_unit
#' @title Convert 'GreenFeed' Unit Number
#'
#' @description Processes the parameter unit to format it correctly as a comma-separated string,
#'     regardless of whether it is provided as a numeric, character, or list/vector.
#'
#' @param unit Number of the 'GreenFeed' unit(s). Can be a numeric, character, list, or vector.
#'
#' @return A character string of the unit(s) in the correct comma-separated format.
#'
#' @examples
#' # Example 1: Providing unit as a character vector
#' unit <- c("592", "593")
#' convert_unit(unit)
#'
#' # Example 2: Providing unit as a single numeric
#' unit <- 592
#' convert_unit(unit)
#'
#' # Example 3: Providing unit as a comma-separated character string
#' unit <- "592, 593"
#' convert_unit(unit)
#'
#' # Example 4: Providing unit as a list
#' unit <- list(592, 593)
#' convert_unit(unit)
#'
#' @export
#' @keywords internal
convert_unit <- function(unit) {
  if (is.numeric(unit)) {
    unit <- as.character(unit)
  } else if (is.character(unit)) {
    unit <- gsub(" ", "", unit) # Remove spaces from the character string
  } else if (is.list(unit) || is.vector(unit)) {
    unit <- as.character(unlist(unit)) # Flatten and convert list/vector to character
  }

  if (length(unit) > 1) {
    unit <- paste(unit, collapse = ",") # Collapse into comma-separated string if needed
  }

  return(unit)
}
