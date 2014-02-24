source('functions.R')
source('variables.R')

load_libraries(c('shiny','shinyIncubator','RODBC'))
tracking.database<-odbcConnect(tracking.database.odbc.dsn)
tableau.database<-odbcConnect(tableau.odbc.dsn)

odbc.connections<-sqlQuery(tracking.database,paste("select connectionId
									, odbcName
									, sourceDbType
									, sourceServer

									from ",tracking.schema,".odbc_map
									order by odbcName asc",sep=""))
if(nrow(odbc.connections)==0){odbc.connections<-data.frame(connectionid=c("None Found","Please Create At Least One Connection"),odbcname=c("None Found","Please Create At Least One Connection"))}

subscription.times<-sqlQuery(tableau.database,"select schedule_name 
                                              from _subscriptions 
                                              group by 1 
                                              order by 1
                                              ")
if(nrow(subscription.times)==0){subscription.times<-data.frame(schedule_name=c("None Found","Please Create At Least One Subscription"))}

shinyUI(pageWithSidebar(
  
  # Application title
  headerPanel("Manage Tableau Scheduler"),
  
  sidebarPanel(
 
    # main type of view to select
    selectInput("menutype","Select your activity",
                choices=c("ChooseOne","Update Data Source to ODBC Map","Update Workbook/Data Source Information","See Job Scheduler History","See Subscription Information")),
    conditionalPanel(
      condition = "input.menutype == 'See Subscription Information' ",
      selectInput("schedule","Schedule Time",choices=as.list(subscription.times$schedule_name ) ),
      br(),
          downloadButton("downloadData","Download Subscriber List") 
      )
    

    ),
  
  mainPanel(
     
    # view if Projects -> Modify existing project is selected
    conditionalPanel(
      condition = "input.menutype == 'Update Data Source to ODBC Map'",
      HTML("<h3> Update Data Source to ODBC Map</h3>"),
      
      selectInput("odbcid","Select Connection Id", choices=  as.list(odbc.connections$connectionid)),
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
      selectInput("scheduleodbc","Choose an ODBC connection to use",choices= as.list(odbc.connections$odbcname)),
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
      ),

      conditionalPanel(
      condition = "input.menutype == 'See Subscription Information'",
      HTML("<h3>Subscription Information</h3>"),
      textOutput("caption"),
      tableOutput("subscriberList") 
      )
    )
  ))