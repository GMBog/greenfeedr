% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/process_gfdata.R
\name{process_gfdata}
\alias{process_gfdata}
\title{Process Preliminary and Finalized 'GreenFeed' Data}
\arguments{
\item{data}{a data frame with preliminary or finalized 'GreenFeed' data}

\item{start_date}{a character string representing the start date of the study (format: "DD-MM-YY" or "YYYY-MM-DD")}

\item{end_date}{a character string representing the end date of the study (format: "DD-MM-YY" or "YYYY-MM-DD")}

\item{param1}{an integer representing the number of records per day to be consider for analysis}

\item{param2}{an integer representing the number of days with records per week to be consider for analysis}

\item{min_time}{an integer representing the minimum number of minutes for a records to be consider for analysis (default: 2 minutes)}

\item{transform}{A logical representing whether to transform gas production to L/d. If TRUE, gas will be converted from grams/day to liters/day.}

\item{cutoff}{an integer specifying the range for identifying outliers (default: 3 SD)}
}
\value{
A list of three data frames:
  \item{filtered_data }{data frame with filtered 'GreenFeed' data}
  \item{daily_data }{data frame with daily processed 'GreenFeed' data}
  \item{weekly_data }{data frame with weekly processed 'GreenFeed' data}
}
\description{
Processes and calculates daily and weekly averages of 'GreenFeed' data.
    Handles data filtering, aggregation, and summarization to facilitate further analysis.
}
\examples{
file <- system.file("extdata", "StudyName_GFdata.csv", package = "greenfeedr")
datafile <- readr::read_csv(file)

gf_data <- process_gfdata(
  data = datafile,
  start_date = "2024-05-13",
  end_date = "2024-05-25",
  param1 = 2,
  param2 = 3,
  min_time = 2
)
head(gf_data)

}
