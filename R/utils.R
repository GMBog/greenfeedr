.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    "Thank you for using the greenfeedr package!\n",
    "Cite: Martinez-Boggio et al. (2025). Greenfeedr: An R-package for processing and reporting GreenFeed data.\n",
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
  # Check if the input is already in YYYY-MM-DD format (does nothing in this case)
  if (grepl("^\\d{4}-\\d{2}-\\d{2}$", date_input)) {
    # Return the date as is
    return(date_input)
  }

  # Attempt to parse the input into a Date object
  date_obj <- tryCatch(
    {
      # Try to parse as day-month-year (DD/MM/YY) format first
      parsed_date <- lubridate::dmy(date_input, quiet = TRUE)

      # If that fails, try parsing as day-month-year (DD/MM/YYYY) format
      if (is.na(parsed_date)) parsed_date <- lubridate::dmy(date_input, quiet = TRUE, truncated = 3)

      # If still NA, raise an error
      if (is.na(parsed_date)) stop("Invalid date format. Please provide a valid date in DD/MM/YY or DD/MM/YYYY format.")

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
#' @param t Type of function (opts: 1 and 2).
#'
#' @return A character string of the unit(s) in the correct comma-separated format.
#'
#' @examples
#' # Example 1: Providing unit as a character vector
#' unit <- c("592", "593")
#' convert_unit(unit, 1)
#'
#' # Example 2: Providing unit as a single numeric
#' unit <- 592
#' convert_unit(unit, 1)
#'
#' # Example 3: Providing unit as a comma-separated character string
#' unit <- "592, 593"
#' convert_unit(unit, 1)
#'
#' # Example 4: Providing unit as a list
#' unit <- list(592, 593)
#' convert_unit(unit, 1)
#'
#' @export
#' @keywords internal
convert_unit <- function(unit, t) {
  if (t == 1) {
    # Handle case for numeric or character vectors, lists, and single values
    if (is.numeric(unit)) {
      unit <- as.character(unit)  # Convert numeric to character
    } else if (is.character(unit)) {
      unit <- gsub(" ", "", unit) # Remove spaces from character string
    } else if (is.list(unit) || is.vector(unit)) {
      unit <- as.character(unlist(unit))  # Flatten list/vector and convert to character
    }

    # Collapse into a comma-separated string if the length is greater than 1
    unit <- paste(unit, collapse = ",")

  } else if (t == 2) {
    # Handle comma-separated strings and lists
    if (is.character(unit)) {
      unit <- strsplit(unit, ",")[[1]]  # Split by comma if it's a string
    } else if (is.list(unit) || is.vector(unit)) {
      unit <- as.character(unlist(unit))  # Convert lists or vectors to character
    }

    # Convert to character
    unit <- as.character(unit)
  }

  return(unit)
}


#' @name eval_gfparam
#' @title Evaluate all combination of parameters
#'
#' @description Evaluate parameters that best fit your 'GreenFeed' data
#'
#' @param data a data frame with preliminary or finalized 'GreenFeed' data
#' @param start_date a character string representing the start date of the study (format: "dd/mm/yyyy")
#' @param end_date a character string representing the end date of the study (format: "dd/mm/yyyy")
#' @param cutoff an integer specifying the range for identifying outliers (default: 3 SD)
#'
#' @return A data frame with the mean, SD, and CV for gas production using all possible combination of parameters
#'
#' @examples
#' file <- readr::read_csv(system.file("extdata", "StudyName_GFdata.csv", package = "greenfeedr"))
#' eval <- eval_gfparam(data = file,
#'                      start_date = "2024-05-13",
#'                      end_date = "2024-05-20"
#'                     )
#'
#' @export
#' @keywords internal
eval_gfparam <- function(data, start_date, end_date, cutoff) {
  # Define the parameter space for param1 (i), param2 (j), and min_time (k):
  i <- seq(1, 5)
  j <- seq(1, 7)
  k <- seq(2, 4)

  # Generate all combinations of i, j, and k
  param_combinations <- expand.grid(param1 = i, param2 = j, min_time = k)

  # Check date format
  start_date <- ensure_date_format(start_date)
  end_date <- ensure_date_format(end_date)

  message("All parameter combinations are being evaluated...\n")

  # Define the function
  process_and_summarize <- function(param1, param2, min_time) {
    processed_data <- suppressMessages({
      result <- process_gfdata(
        data = data,
        start_date = start_date,
        end_date = end_date,
        param1 = param1,
        param2 = param2,
        min_time = min_time
      )
    })
    result
  }

  # Call the function for each parameter combination
  processed_data_list <- lapply(1:nrow(param_combinations), function(idx) {
    params <- param_combinations[idx, ]
    process_and_summarize(params$param1, params$param2, params$min_time)
  })

  message("Done!")

  # Extract daily_data and weekly_data from each result
  daily_data_list <- lapply(processed_data_list, function(x) x$daily_data)
  weekly_data_list <- lapply(processed_data_list, function(x) x$weekly_data)

  # Helper function to compute mean, SD, and CV safely
  compute_metrics <- function(x) {
    mean_x <- mean(x, na.rm = TRUE)
    sd_x <- sd(x, na.rm = TRUE)
    CV_x <- ifelse(mean_x == 0, NA, (sd_x / mean_x)*100)
    return(c(mean = round(mean_x, 1), sd = round(sd_x, 1), CV = round(CV_x, 2)))
  }

  # Compute metrics for CH4 and CO2
  results <- param_combinations %>%
    purrr::pmap_dfr(function(param1, param2, min_time) {
      daily_data <- daily_data_list[[which(param_combinations$param1 == param1 & param_combinations$param2 == param2 & param_combinations$min_time == min_time)]]
      weekly_data <- weekly_data_list[[which(param_combinations$param1 == param1 & param_combinations$param2 == param2 & param_combinations$min_time == min_time)]]

      #CH4_day <- compute_metrics(daily_data$CH4GramsPerDay)
      #CO2_d <- compute_metrics(daily_data$CO2GramsPerDay)
      CH4_week <- compute_metrics(weekly_data$CH4GramsPerDay)
      #CO2_w <- compute_metrics(weekly_data$CO2GramsPerDay)

      data.frame(
        param1 = param1,
        param2 = param2,
        min_time = min_time,
        #drecords = nrow(daily_data),
        #dcows = length(unique(daily_data$RFID)),
        #dCH4 = CH4_day["mean"],
        #sd_dCH4 = CH4_day["sd"],
        #CV_dCH4 = CH4_day["CV"],
        #mean_dCO2 = CO2_d["mean"], sd_dCO2 = CO2_d["sd"], CV_dCO2 = CO2_d["CV"],
        records = nrow(weekly_data),
        N = length(unique(weekly_data$RFID)),
        mean = CH4_week["mean"],
        SD = CH4_week["sd"],
        CV = CH4_week["CV"],
        #mean_wCO2 = CO2_w["mean"], sd_wCO2 = CO2_w["sd"], CV_wCO2 = CO2_w["CV"],
        row.names = NULL
      )
    })

  return(results)
}




