
# app_ui.R

ui <- fluidPage(
  tags$head(
    tags$link(href = "https://fonts.googleapis.com/css?family=Montserrat:700,400&display=swap", rel = "stylesheet"),
    tags$link(href = "https://fonts.googleapis.com/css?family=Merriweather:700,400&display=swap", rel = "stylesheet"),
    tags$link(rel = "shortcut icon", href = "favicon.ico"),
    tags$style(HTML("
      body, .main-panel, .form-group label, .control-label {
        font-family: 'Montserrat', Arial, sans-serif;
        font-size: 12px;
        color: #006400;
      }
      .top-bar {
        font-family: 'Merriweather', serif;
        background-color: #124B12;
        color: white;
        padding: 10px 20px;
        font-size: 23px;
        font-weight: bold;
        text-align: center;
        letter-spacing: 2px;
        border-radius: 0 0 18px 18px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.04);
      }
      .tab-content, .main-panel, .sidebar-panel, .welcome-container {
        background: #f7fff7;
        border-radius: 15px;
        box-shadow: 0 6px 24px rgba(18,75,18,0.08), 0 1.5px 5px rgba(18,75,18,0.04);
        padding: 10px;
        margin-bottom: 10px;
      }
      .btn, .action-button, .download-button {
        background: linear-gradient(90deg, #198754 0%, #124B12 100%);
        border: none;
        color: white !important;
        font-weight: bold;
        border-radius: 5px !important;
        font-size: 12px !important;
        transition: background 0.2s;
      }
      .btn:hover, .action-button:hover, .download-button:hover {
        background: #0e2e0e !important;
        color: #c1ffc1 !important;
      }
      .nav-tabs > li > a, .nav-tabs > li.active > a {
        color: #006400 !important;
        font-weight: bold;
        font-size: 12px !important;
      }
      .tab-content > .tab-pane {
        opacity: 0;
        transition: opacity 0.5s;
      }
      .tab-content > .active {
        opacity: 1;
      }
      #download, #run_report, #run_pellin, #run_viseat, #run_eval_param, #run_process, #run_compare {
        animation: pulse 1.5s infinite alternate;
      }
      @keyframes pulse {
        from { box-shadow: 0 0 0 0 rgba(24, 135, 84, 0.7); }
        to   { box-shadow: 0 0 12px 6px rgba(24, 135, 84, 0.15); }
      }
      .form-group .btn-default,
      .form-group .btn-default:focus,
      .form-group .btn-default:active,
      .form-group .btn-default:hover {
        background: linear-gradient(90deg, #B4E197 0%, #6FCF97 100%) !important;
        color: #124B12 !important;
        border: none;
        border-radius: 8px !important;
        font-weight: bold;
        font-size: 12px !important;
        box-shadow: none !important;
        transition: background 0.2s;
      }
      .form-group .btn-default:hover {
        background: #a0d883 !important;
        color: #124B12 !important;
      }
      /* Make sure action/download buttons don't pick up the .btn-default style */
      .action-button, .download-button {
        background: linear-gradient(90deg, #198754 0%, #124B12 100%) !important;
        color: white !important;
      }
      /* Reduce font size inside input boxes, select boxes, date pickers */
      .form-control,
      .selectize-input,
      input[type='text'],
      input[type='password'],
      input[type='number'],
      input[type='date'] {
        font-size: 11px !important;
      }
    "))
  ),
  div(class = "top-bar", "greenfeedr app"),
  # Main UI layout with tabs
  tabsetPanel(

    # Welcome tab
    tabPanel(
      "Welcome",
      div(
        class = "welcome-container",
        style = "
      max-width: 900px;
      margin: 40px auto;
      padding: 30px 32px 36px 32px;
      background: #f7fafc;
      border-radius: 16px;
      box-shadow: 0 2px 12px rgba(0,0,0,0.07);
    ",
        tags$img(
          src = "GFSticker.png",
          width = "120px",
          style = "display: block; margin: 0 auto 24px auto;"
        ),
        tags$h2(
          "Welcome to the GreenFeedr App",
          style = "text-align: center; margin-bottom: 18px; color: #2e7d32;"
        ),
        tags$p(
          style = "font-size: 1.15em; text-align: center; margin-bottom: 24px;",
          "This Shiny application helps you download, visualize, process, and analyze GreenFeed data for your research."
        ),
        tags$div(
          style = "margin-bottom: 28px;",
          tags$b("What you can do:"),
          tags$ul(
            style = "margin-bottom: 10px;",
            tags$li(tags$b("Downloading Data:"), " Retrieve GreenFeed data (visits or emissions, feed, rfids, commands) efficiently"),
            tags$li(tags$b("Checking Data:"), " Quickly review visits and calculate intakes for your GreenFeed units"),
            tags$li(tags$b("Reporting Data:"), " Create interactive visualization of records for your GreenFeed units"),
            tags$li(tags$b("Processing Data:"), " Evaluate parameters and process GreenFeed data"),
            tags$li(tags$b("Analyzing Data:"), " Compare groups and perform Tukey tests for gases production"),
          )
        ),
        tags$div(
          style = "margin-bottom: 24px;",
          tags$b("How to use:"),
          tags$ol(
            tags$li("Download preliminary data (emissions, intakes, commands) directly from the C-Lock server"),
            tags$li("Monitor visits to your GreenFeed units and calculate animal feed intake during trials"),
            tags$li("Visualize GreenFeed records by day and animal, track gas production, and make informed decisions"),
            tags$li("Evaluate and apply optimal parameters to process gas production data"),
            tags$li("Analyze and compare group/treatment means, including Tukey tests for each gas"),
          )
        ),
        tags$hr(style = "margin: 28px 0;"),
        tags$p(
          style = "margin-bottom: 10px;",
          "The ",
          tags$b("greenfeedr"),
          " package is open-source and developed by ",
          tags$a(href = "https://github.com/GMBog", "Guillermo Martinez-Boggio"),
          "."
        ),
        tags$p(
          "All functions and documentation for GreenFeed data processing are available both ",
          tags$a(href = "https://gmbog.shinyapps.io/shinyapp/", "online via shinyapps.io"),
          " and for direct use in ",
          tags$a(href = "https://cran.r-project.org/package=greenfeedr", "R"),
          "."
        )
      )
    ),

    tabPanel("Downloading Data",
             sidebarLayout(
               sidebarPanel(
                 textInput("user", "Username:", placeholder = "Enter your username"),
                 passwordInput("pass", "Password:", placeholder = "Enter your password"),
                 textInput("unit", "GreenFeed Unit(s):", placeholder = "e.g. 55 or 100,101"),
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date() - 1),
                 selectInput("d", "Data Type:", choices = c("visits", "feed", "rfid", "cmds")),
                 fluidRow(
                   column(6, actionButton("load_data", "Load Data", icon = icon("sync"))),
                   column(6, uiOutput("download_ui"))
                 )
               ),
               mainPanel(
                 uiOutput("error_message_download"),
                 uiOutput("summary_card_download"),
                 div(style = "margin-bottom: 15px;"),
                 uiOutput("preview")
               )
             )
    ),

    tabPanel("Checking Data",
             sidebarLayout(
               sidebarPanel(
                 textInput("user", "Username:", placeholder = "Enter your username"),
                 passwordInput("pass", "Password:", placeholder = "Enter your password"),
                 textInput("unit", "GreenFeed Unit(s):", placeholder = "e.g. 55 or 100,101"),
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date()),
                 actionButton("run_viseat", "Run Viseat", icon = icon("running")),
                 div(style = "margin-bottom: 25px;"),
                 textInput("gcup", "Grams per Cup:", placeholder = "e.g. 34 or 34,35"),
                 actionButton("run_pellin", "Run Pellin", icon = icon("running"))
               ),
               mainPanel(
                 textOutput("viseat_status"),
                 uiOutput("summary_card_viseat"),
                 uiOutput("error_message_viseat"),
                 div(style = "margin-bottom: 15px;"),
                 plotlyOutput("plot2_1"),
                 plotlyOutput("plot2_2"),
                 div(style = "margin-bottom: 15px;"),
                 hr(),

                 verbatimTextOutput("pellin_status"),
                 uiOutput("summary_card_pellin"),
                 uiOutput("error_message_pellin"),
                 uiOutput("pellin_table"),
                 conditionalPanel(
                   condition = "input.run_pellin > 0",
                   downloadButton("download_pellin", "Download Intakes")
                 )
             )
          )
    ),

    tabPanel("Reporting Data",
             sidebarLayout(
               sidebarPanel(
                 textInput("user", "Username:", placeholder = "Enter your username"),
                 passwordInput("pass", "Password:", placeholder = "Enter your password"),
                 textInput("unit", "GreenFeed Unit(s):", placeholder = "e.g. 55 or 100,101"),
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date() - 1),
                 fileInput("rfid_file2", "Upload RFID file (optional):"),
                 actionButton("run_report", "Report Data", icon = icon("file-alt")),
                 div(style = "margin-bottom: 15px;"),
                 selectInput(
                   "which_plot", "Show Plot:",
                   choices = c(
                     "Records Per Day" = "plot_1",
                     "Records Per Animal" = "plot_2",
                     "Gas Production Across The Day" = "plot_3"
                   ),
                   selected = "plot_1"
                 ),
                 conditionalPanel(
                   condition = "input.which_plot == 'plot_3'",
                   checkboxGroupInput(
                     inputId = "plot3_gas",
                     label = "Select gases to plot:",
                     choices = list("CH4" = "ch4", "CO2" = "co2", "O2" = "o2", "H2" = "h2"),
                     selected = "ch4"
                   )
                 )
               ),
               mainPanel(
                 uiOutput("error_message_report"),
                 uiOutput("summary_card_report"),
                 uiOutput("report_preview"),
                 div(style = "margin-bottom: 15px;"),
                 uiOutput("chosen_plot")
               )
             )
    ),

    tabPanel("Processing Data",
             sidebarLayout(
               sidebarPanel(
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date() - 1),
                 radioButtons(
                   inputId = "gas",
                   label = "Gas to evaluate:",
                   choices = c("CH4", "CO2", "O2", "H2"),
                   selected = "CH4",
                   inline = TRUE
                 ),
                 fileInput("gf_file1", "Upload GreenFeed Data:"),
                 actionButton("run_eval_param", "Evaluate Parameters", icon = icon("search")),
                 div(style = "margin-bottom: 15px;"), hr(),
                 numericInput("param1", "N Records-Day (Param1):", value = 2, min = 1),
                 numericInput("param2", "N Days-Week (Param2):", value = 3, min = 1),
                 numericInput("min_time", "Min. minutes per record (Min_time):", value = 2),
                 checkboxInput("transform", "Transform gases to L/d?", value = FALSE),
                 numericInput("cutoff", "Outlier SD cutoff:", value = 3, min = 1),
                 actionButton("run_process", "Process Data", icon = icon("sync"))
               ),
               mainPanel(
                 conditionalPanel(
                   condition = "input.run_eval_param > 0 || input.run_process > 0",
                   uiOutput("summary_card_eval"),
                   div(style = "margin-bottom: 15px;")
                 ),
                 conditionalPanel(
                   condition = "input.run_eval_param > 0",
                   DTOutput("eval_param_table"),
                   uiOutput("error_message_eval")
                 ),
                 conditionalPanel(
                   condition = "input.run_process > 0",
                   div(style = "margin-bottom: 15px;"),
                   hr(),
                   uiOutput("summary_card_process"),
                   uiOutput("error_message_process"),
                   div(style = "margin-bottom: 25px;"),
                   fluidRow(
                     column(4, downloadButton("download_filtered", "Download Filtered Data")),
                     column(4, downloadButton("download_daily", "Download Daily Data")),
                     column(4, downloadButton("download_weekly", "Download Weekly Data"))
                   )
                 )
               )
             )
  ),

  tabPanel("Analyzing Data",
           sidebarLayout(
             sidebarPanel(
               dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date() - 1),
               fileInput("gf_file2", "Upload GreenFeed Data:"),
               fileInput("rfid_file3", "Upload Groups File:"),
               numericInput("param1", "N Records-Day (Param1):", value = 2, min = 1),
               numericInput("param2", "N Days-Week (Param2):", value = 3, min = 1),
               numericInput("min_time", "Min. minutes per record (Min_time):", value = 2),
               numericInput("cutoff", "Outlier SD cutoff:", value = 3, min = 1),
               actionButton("run_analysis", "Analyze Data", icon = icon("sync"))
             ),
             mainPanel(
               conditionalPanel(
                 condition = "input.run_analysis > 0",
                 uiOutput("summary_card_analysis"),
                 uiOutput("error_message_analysis"),
                 div(style = "margin-bottom: 15px;"),
                 tableOutput("group_summary_table"),
                 div(style = "margin-bottom: 15px;"),
                 hr(),
                 radioButtons("selected_gas", "Select Gas:",
                             choices = c("CO2" = "CO2GramsPerDay",
                                         "CH4" = "CH4GramsPerDay",
                                         "O2" = "O2GramsPerDay",
                                         "H2" = "H2GramsPerDay"),
                             selected = "CH4GramsPerDay",
                             inline = TRUE
                 ),
                 tableOutput("tukey_table")
               )
             )
           )
  ),

  tags$footer(
    style = "text-align: center; padding: 10px 0; color: #999; font-size: 13px; margin-top: 30px;",
    "2025 greenfeedr | Develop by Guillermo Martinez-Boggio"
  ))
  )


