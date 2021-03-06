## This module contains the UI and server code for the stations management tab

## Create module UI ###############################################################

stationsManagementUI <- function(id) {
# Create the UI for the stationsManagement module
# Parameters:
#  - id: String, the module id
# 
# Returns a tagList with the layout
  
  # Create namespace
  ns <- NS(id)
  
  # Create and return the layout
  tagList(
    instructionsPanelUI(
      ns('info'),
      htmlTemplate('./html_components/stations_tab_info.html'),
      initStateHidden = TRUE
    ),  
    editableDTUI(ns('stations'),  canReorder = TRUE)
  )
}



## Create module server function ##################################################

stationsManagement <- function(input, output, session, pool) {
# Create the logic for the stationsManagement module
# Parameters:
#  - input, output, session: Default needed parameters to create a module
#  - pool: The pool connection to the database
# 
# Returns NULL
  
  # Call instruction panel module
  callModule(instructionsPanel, 'info', initStateHidden = TRUE)
  
  # Call editableDT module
  callModule(editableDT, 'stations', pool = pool, tableName = 'stations', element = 'station',
             canReorder = TRUE,
             tableLoading = expression(
               getRows(pool, 'stations') %>%
                 # Cast data types
                 mutate(
                   catchment = as.factor(catchment),
                   across(ends_with('_at'), ymd_hms)
                 )
             ),
             templateInputsCreate = expression(
               inputsTemplate %>% select(name, full_name, catchment, color, elevation)
             ),
             templateInputsEdit = expression(
               selectedRow %>% select(id, name, full_name, catchment, color, elevation)
             ),
             creationExpr = expression(
               createStation(
                 pool = pool,
                 name = input$name,
                 full_name = input$full_name,
                 catchment = input$catchment,
                 color = input$color,
                 elevation = input$elevation
               )
             ),
             updateExpr = expression(
               updateStation(
                 pool = pool,
                 station = editedRow(),
                 name = input$name,
                 full_name = input$full_name,
                 catchment = input$catchment,
                 color = input$color,
                 elevation = input$elevation
               )
             ),
             deleteExpr = expression(
               deleteRows(
                 pool = pool,
                 table = 'stations',
                 ids = selectedRowIds
               )
             ))
}
