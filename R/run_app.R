#' Launch the Greenfeedr Shiny App locally
#'
#' This function launches the Greenfeedr Shiny app on your computer.
#' @export
run_app <- function() {
  app_dir <- system.file("app", package = "greenfeedr")
  shiny::runApp(app_dir)
}
