#' @name has_credentials
#' @title Check for API Credentials
#'
#' @description `has_credentials()` is a helper function to check
#'     if the necessary API credentials are available in the environment
#'
#' @export
has_credentials <- function() {
  !is.na(Sys.getenv("API_USER", unset = NA)) && !is.na(Sys.getenv("API_PASS", unset = NA))
}


#' @name ensure_date_format
#' @title Check date format and transform in a usable one
#'
#' @description `ensure_date_format()` is a helper function to check date format.
#'     If the format is wrong 'NA' an error message is printed, else it will
#'     formatted the date in the correct way (YYYY-MM-DD)
#'
#' @param date_input Date included as input
#'
#' @export
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
#' @description `filter_within_range()` is a helper function to detect
#'     outliers in data using the mean and sd
#'
#' @param v A vector with data
#' @param cutoff A threshold or cutoff value that defines the range (e.g., 2.5)
#'
#' @export
filter_within_range <- function(v, cutoff) {
  mean_v <- mean(v, na.rm = TRUE)
  sd_v <- sd(v, na.rm = TRUE)
  v >= (mean_v - cutoff * sd_v) & v <= (mean_v + cutoff * sd_v)
}
