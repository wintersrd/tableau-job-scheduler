source('functions.R')
source('variables.R')

load_libraries(c('shiny','shinyIncubator'))


odbc.connections<-sqlQuery(tracking.database,paste("select connectionId
									, odbcName
									, sourceDbType
									, sourceServer

									from ",tracking.schema,".odbc_map
									order by odbcName asc",sep=""))
scheduler.tasks<-sqlQuery(tracking.database,paste("select *

									from ",tracking.schema,".job_scheduler
									order by jobid",sep=""))

shinyUI(pageWithSidebar(
  
  # Application title
  headerPanel("Manage Tableau Scheduler"),
  
  sidebarPanel(
 
    # main type of view to select
    selectInput("menutype","Select your activity",
                choices=c("ChooseOne","Update Data Source to ODBC Map","Update Workbook/Data Source Information","See Job Scheduler History"))
    
    ),
  
  mainPanel(
     
    # view if Projects -> Modify existing project is selected
    conditionalPanel(
      condition = "input.menutype == 'Update Data Source to ODBC Map'",
      HTML("<h3> Update Data Source to ODBC Map</h3>"),
      
      selectInput("odbcid","Select Connection Id", choices=as.list(odbc.connections$connectionid)),
      textInput("newodbc","New ODBC connection"),
      br(),
      actionButton("odbcmodif","Update Database"),
      verbatimTextOutput("modifodbc"),
      br(),
      dataTableOutput("odbcmap")
      ),

      conditionalPanel(
      condition = "input.menutype == 'Update Workbook/Data Source Information'",
      HTML("<h3>Update Workbook/Data Source Information</h3>"),
      
      textInput("jobid","Enter a Connection ID"),
      textInput("newsourcefact","Fact Table to Monitor (Format: schema.table)"),
      br(),
      actionButton("jobmodif","Update Reference Table"),
      verbatimTextOutput("modifjob"),
      br(),
      dataTableOutput("scheduler")
      ),

      conditionalPanel(
      condition = "input.menutype == 'See Job Scheduler History'",
      HTML("<h3>Update Workbook/Data Source Information</h3>"),
      plotOutput("schedulertrend"),
      dataTableOutput("schedulerrecenthistory")  
      )
    )
  ))