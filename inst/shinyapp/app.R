# app.R

# Load required packages
library(shiny)
library(greenfeedr)
library(readr)
library(readxl)
library(plotly)
library(fontawesome)
library(ggplot2)
library(dplyr)
library(tidyr)
library(DT)
library(stringr)
library(httr)
library(rlang)

# Set upload size limit
options(shiny.maxRequestSize = 100 * 1024^2)

# Source UI and server
source("app_ui.R")
source("app_server.R")

# Launch the app
shinyApp(ui, server)
