#' @name run_gfapp
#' @title Run the 'greenfeedr' Shiny App locally
#'
#' @description Launches the 'greenfeedr' Shiny application on your computer.
#' The app provides an interactive interface for 'GreenFeed' data analysis, visualization, and reporting.
#'
#' @return This function launches the Shiny app in your default web browser; it does not return a value.
#'
#' @examples
#' \dontrun{
#'   greenfeedr::run_gfapp()
#' }
#'
#' @export
run_gfapp <- function() {
  appDir <- system.file("shinyapp", package = "greenfeedr")
  if (appDir == "" || !dir.exists(appDir)) {
    stop("Could not find the Shiny app directory. Try reinstalling the package.")
  }
  shiny::runApp(appDir, display.mode = "normal")
}
