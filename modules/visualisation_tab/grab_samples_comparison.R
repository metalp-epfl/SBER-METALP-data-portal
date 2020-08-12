## This module contains the code for the grab samples data comparison visualisation

## Create the UI function of the module ###############################################

grabSamplesComparisonUI <- function(id, sites, parameters) {
# Create the UI for the grabSamplesComparison module
# Parameters:
#  - id: String, the module id
#  - sites: Named list, contains all sites info, cf data_preprocessing.R
#  - parameters: Named list, contains grab samples data parameters info, cf data_preprocessing.R
# 
# Returns a list containing:
#  - inputs: the inputs UI elements of the module
#  - plots: the plots UI elements of the module
  
  # Create namespace
  ns <- NS(id)
  
  # Parse id to get the module unit nb
  splittedId <- str_split(id, '-') %>% unlist()
  unitNb <- splittedId[length(splittedId)]
  
  # Create the UI list to be returned
  list(
    # Create the UI inputs
    'inputs' = div(
      # Set UI inputs id and class
      id = str_interp('grab-vs-grab-plot-input-${id}'),
      class = 'time-serie-input',
      # Create select input for catchment selection
      selectInput(ns('site'), str_interp('Station ${unitNb}'), sites$sitesSelectOptions),
      # Inputs for X axis
      # Create a select input for parameter selection
      selectInput(
        ns('paramX'),
        # Create a label with an icon button
        tags$span(
          str_interp('Parameter X ${unitNb}'),
          # Create an icon button that trigger a modal to display the parameter description
          actionButton(ns('paramHelperX'), icon('question-circle'), class = 'icon-btn')
        ),
        parameters$selectOptions
      ),
      # Create an hidden radio buttons input group (with shinyjs) for sub parameter selection
      # Will be displayed only if there is a sub parameter selection available
      hidden(
        radioButtons(
          ns('paramfilterX'),
          str_interp('Subparameter X ${unitNb}'),
          choices = 'NULL'
        )
      ),
      # Inputs for Y axis
      # Create a select input for parameter selection
      selectInput(
        ns('paramY'),
        # Create a label with an icon button
        tags$span(
          str_interp('Parameter Y ${unitNb}'),
          # Create an icon button that trigger a modal to display the parameter description
          actionButton(ns('paramHelperY'), icon('question-circle'), class = 'icon-btn')
        ),
        parameters$selectOptions
      ),
      # Create an hidden radio buttons input group (with shinyjs) for sub parameter selection
      # Will be displayed only if there is a sub parameter selection available
      hidden(
        radioButtons(
          ns('paramfilterY'),
          str_interp('Subparameter Y ${unitNb}'),
          choices = 'NULL'
        )
      )
    ),
    # Create the UI plots
    'plots' = div(
      # Set UI plots id and class
      id = str_interp('grab-vs-grab-plots-${id}'),
      class = 'time-serie-plot point-hover-widget-plot',
      # Create a plotOutput for the grab vs grab plot
      plotOutput(
        ns('grabVsGrab'),
        # Make data points hoverable
        hover = hoverOpts(ns('grabVsGrab_hover'))
      )
    )
  )
}



## Create the server function of the module ###############################################

grabSamplesComparison <- function(input, output, session, df, dateRange, sites, parameters) {
# Create the logic for the grabSamplesComparison module
# Parameters:
#  - input, output, session: Default needed parameters to create a module
#  - df: Data.frame, the grab samples data
#  - dateRange: Reactive expression that returns the date range to filter the data with.
#               Date range format must be a list containing:
#               + min: Date, the lower bound to filter the date
#               + max: Date, the upper bound to filter the data
#  - sites: Named list, contains all sites info, cf data_preprocessing.R
#  - parameters: Named list, contains grab samples data parameters info, cf data_preprocessing.R
# 
# Returns NULL
  

  ## Sub parameter update logic ###################################################
  
  # X parameter
  # Create an observeEvent that react to the param select input
  observeEvent(input$paramX,{
    # Get parameter info
    dataColumns <- parameters$parameters %>% filter(param_name == input$paramX) %>% select(data) %>% str_split(',') %>% unlist()
    
    # Update sub parameter radio buttons group input with current parameter info
    updateRadioButtons(session, 'paramfilterX',
                             choices = dataColumns,
                             selected = dataColumns[1])
    
    # Toggle sub parameter radio buttons group input visibility
    # In function of the number of sub parameters
    # length(dataColumns) > 1 == TRUE -> show else hide
    toggleElement('paramfilterX', condition = length(dataColumns) > 1)
  })
  
  
  # Y parameter
  # Create an observeEvent that react to the param select input
  observeEvent(input$paramY,{
    # Get parameter info
    dataColumns <- parameters$parameters %>% filter(param_name == input$paramY) %>% select(data) %>% str_split(',') %>% unlist()
    
    # Update sub parameter radio buttons group input with current parameter info
    updateRadioButtons(session, 'paramfilterY',
                       choices = dataColumns,
                       selected = dataColumns[1])
    
    # Toggle sub parameter radio buttons group input visibility
    # In function of the number of sub parameters
    # length(dataColumns) > 1 == TRUE -> show else hide
    toggleElement('paramfilterY', condition = length(dataColumns) > 1)
  })
  
  
  
  # Create a reactive expression returning the parameter info as a named list:
  #  - filter(X|Y): the sub parameters to display
  #  - param(X|Y): the parameter info
  paramfilter <- reactive({
    # Save the parameter and sub parameters into variables
    inputParamX <- input$paramX
    paramToDisplayX <- input$paramfilterX
    inputParamY <- input$paramY
    paramToDisplayY <- input$paramfilterY
    
    # If either paramToDisplay(X|Y) or inputParam(X|Y) is NULL
    # Return a list of NULL values
    if (is.null(paramToDisplayX) | is.null(inputParamX) | is.null(paramToDisplayY) | is.null(inputParamY)) return(list(
      'filterX' = NULL,
      'paramX' = NULL,
      'filterY' = NULL,
      'paramY' = NULL
    ))
    
    # Otherwise get parameter info
    paramX <- parameters$parameters %>% filter(param_name == inputParamX)
    paramY <- parameters$parameters %>% filter(param_name == inputParamY)
    # Return the sub parameters and parameter info
    return(list(
      'filterX' = paramToDisplayX,
      'paramX' = paramX,
      'filterY' = paramToDisplayY,
      'paramY' = paramY
    ))
  })
  
  
  
  ## Data manipulation logic ######################################################
  
  # Create a data reactive expression that return a subset of the data
  # Using the dateRange, sites and paramfilter reactive expressions
  data <- reactive({
    # Save the sub parameters to display
    paramColsX <- paramfilter()$filterX
    paramColsY <- paramfilter()$filterY
    
    # If there is no sub parameter return NULL
    if (is.null(paramColsX) | is.null(paramColsY)) return(NULL)
    
    # Filter the data using the selected sites and the date range
    df <- df %>% filter(
      Site_ID %in% input$site,
      DATE_reading >= dateRange()$min,
      DATE_reading <= dateRange()$max
    )
    
    # If there is no data return NULL
    if (dim(df)[1] == 0) return(NULL)
    
    # Select all relevant data.frame columns
    df <- df %>% select(Site_ID, DATETIME_GMT, all_of(c(paramColsX, paramColsY)))
    
    # Return the formatted data
    df
  })
  
  
  
  ## Plots output logic ###########################################################
  
  # Render the regular timeserie plot
  output$grabVsGrab <- renderPlot({
    # If there are no data return NULL
    if (data() %>% is.null()) return(NULL)

    # Get unitNb
    splittedId <- str_split(session$ns('0'), '-') %>% unlist()
    unitNb <- splittedId[length(splittedId) - 1]
    
    # Get current site name and color
    currentSite <- sites$sites %>% filter(sites_short == input$site) %>% pull(sites_full)
    currentColor <- sites$sites %>% filter(sites_short == input$site) %>% pull(sites_color)

    # Create and return a onVsOne plot
    onVsOnePlot(
      df = data(),
      x = paramfilter()$filterX,
      y = paramfilter()$filterY,
      parameterX = paramfilter()$paramX,
      parameterY  = paramfilter()$paramY,
      plotTitle = str_interp('${currentSite} Grab VS Grab ${unitNb}'),
      color = currentColor
    )
  })

  
  
  
  ## Plot hovering logic ##########################################################
  
  # Activate the hover widget for the regular timeserie plot
  pointHoverWidgetServer(session, 'grabVsGrab', data, reactive(input$grabVsGrab_hover))

  
  
  
  ## Parameter description modal logic ############################################
  
  # X parameter
  # Create an observeEvent that react to the parameter helper icon button
  observeEvent(input$paramHelperX, {
    # Render the description UI in the modal
    output$description <- renderUI(tags$p(
      class = 'description',
      parameters$parameters %>% filter(param_name == input$paramX) %>% pull(description)
    ))
    
    # Create modal with the corresponding htmlOutput
    showModal(modalDialog(
      title = 'Parameters description',
      htmlOutput(session$ns('description')),
      easyClose = TRUE
    ))
  })
  
  
  # Y parameter
  # Create an observeEvent that react to the parameter helper icon button
  observeEvent(input$paramHelperY, {
    # Render the description UI in the modal
    output$description <- renderUI(tags$p(
      class = 'description',
      parameters$parameters %>% filter(param_name == input$paramY) %>% pull(description)
    ))
    
    # Create modal with the corresponding htmlOutput
    showModal(modalDialog(
      title = 'Parameters description',
      htmlOutput(session$ns('description')),
      easyClose = TRUE
    ))
  })
}
