#' Run the GreenFeed Shiny App on your computer
#'
#' @export
run_gfapp <- function() {
  appDir <- system.file("shinyapp", package = "greenfeedr")
  if (appDir == "") {
    stop("Could not find the Shiny app directory. Try reinstalling the package.")
  }
  shiny::runApp(appDir, display.mode = "normal")
}
