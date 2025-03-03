% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_gfdata.R
\name{get_gfdata}
\alias{get_gfdata}
\title{Download Preliminary 'GreenFeed' Data via 'API'}
\usage{
get_gfdata(
  user,
  pass,
  exp = NA,
  unit,
  start_date,
  end_date = Sys.Date(),
  save_dir = tempdir()
)
}
\arguments{
\item{user}{a character string representing the user name to logging into 'GreenFeed' system}

\item{pass}{a character string representing password to logging into 'GreenFeed' system}

\item{exp}{a character string representing study name or other study identifier. It is used as file name to save the data}

\item{unit}{numeric or character vector, or a list representing one or more 'GreenFeed' unit numbers}

\item{start_date}{a character string representing the start date of the study (format: "mm/dd/yyyy")}

\item{end_date}{a character string representing the end date of the study (format: "mm/dd/yyyy")}

\item{save_dir}{a character string representing the directory to save the output file}
}
\value{
A CSV file with preliminary 'GreenFeed' data in the specified directory
}
\description{
Downloads preliminary 'GreenFeed' data from the 'C-Lock Inc.' server via an 'API'.
    Retrieves data based on specified parameters (login, date range, and units), and
    provides a CSV file with the 'GreenFeed' preliminary data.
}
\examples{
\dontshow{if (has_credentials()) (if (getRversion() >= "3.4") withAutoprint else force)(\{ # examplesIf}
# Please replace "your_username" and "your_password" with your actual 'GreenFeed' credentials.
# Example with units as a vector

get_gfdata(
   user = "your_username",
   pass = "your_password",
   exp = "StudyName",
   unit = c(304, 305),
   start_date = "2024-01-01",
   end_date = Sys.Date(),
   save_dir = tempdir()
   )
\dontshow{\}) # examplesIf}
}
