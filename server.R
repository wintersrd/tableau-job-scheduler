source('functions.R')

load_libraries(c('shiny','shinyIncubator','ggplot2','RODBC'))

source('variables.R')

event.history<-sqlQuery(tracking.database,paste("select date_trunc('hour',updateTime) as reportHour
                    , count(*) as updatesScheduled

                  from ",tracking.schema,".job_scheduler_events
                  group by 1",sep=""))

shinyServer(function(input, output) {


output$odbcmap<-renderDataTable({sqlQuery(tracking.database,paste("select connectionId
                  , odbcName
                  , sourceDbType
                  , sourceServer

                  from ",tracking.schema,".odbc_map
                  order by sourceDbType, sourceServer",sep=""))})

output$scheduler<-renderDataTable(function(){sqlQuery(tracking.database,paste("select *

                  from ",tracking.schema,".job_scheduler
                  order by sourceDbType, sourceServer, sourceFactTable",sep="")) 
                  })

output$schedulerrecenthistory<-renderDataTable(function(){sqlQuery(tracking.database,paste("select dataConnector
                                                      , sourceServer
                                                      , sourceFactTable
                                                      , updateTime
                                                      , e.lastRowCount as priorRowCount
                                                      , currentRowCount as mostRecentRowCount

                                                      from ",tracking.schema,".job_scheduler_events e 
                                                        join ",tracking.schema,".job_scheduler s 
                                                          on s.jobId = e.jobId
                                                      order by updateTime desc limit 50",sep="")) 
                                                      })
output$schedulertrend<-renderPlot({qplot(x=reporthour
                                          , y=updatesscheduled
                                          , data=event.history
                                          ,alpha=I(.5)
                                          ,main="Extracts Triggered per Hour"
                                          ,ylab="Number of Extracts Scheduled")  
                  })
output
# odbcmodif is the variable that is set to 1 when a project is modified and reset to 0 
  # immediately after that. This ensures that subsequent typing in text box doesn't have any impact
  # unless button is clicked again
  odbcmodif <<- 0
  modifodbc=reactive(function(){
    input$odbcmodif
    if(input$odbcmodif > 0) {odbcmodif <<- 1}
  })
  
  
  output$modifodbc=reactivePrint(function(){
    
    # call to reactive function that responds to clicking modify project button
    modifodbc()
    
    # Message when button is not clicked
    if(odbcmodif == 0) {
      # I am not sure why the following line is needed here but somehow had problems without this line
      input$odbcmodif 
      msg="Click modify to update database"
      return(msg)
    }

    sqlQuery(tracking.database,paste("update ",tracking.schema,".odbc_map set odbcName = '",input$newodbc,"'
                                                                  , lastModifiedName = '",Sys.getenv("USERNAME"),"'
                                                                  , lastModifiedTime = current_timestamp where connectionId = ", input$odbcid,";commit;",sep="" ))
    output$odbcmap<-renderDataTable({sqlQuery(tracking.database,paste("select connectionId
                  , odbcName
                  , sourceDbType
                  , sourceServer

                  from ",tracking.schema,".odbc_map
                  order by sourceDbType, sourceServer",sep=""))}) 

    # resetting projnew to 0 so that any typing in text box has no impact
    odbcmodif <<- 0
   })

# replicated again for job scheduling
  jobmodif <<- 0
  modifjob=reactive(function(){
    input$jobmodif
    if(input$jobmodif > 0) {jobmodif <<- 1}
  })
  
  
  output$modifjob=reactivePrint(function(){
    
    # call to reactive function that responds to clicking modify project button
    modifjob()
    
    # Message when button is not clicked
    if(jobmodif == 0) {
      # I am not sure why the following line is needed here but somehow had problems without this line
      input$jobmodif 
      msg="Click modify to update database"
      return(msg)
    }

    sqlQuery(tracking.database,paste("update ",tracking.schema,".job_scheduler set sourceFactTable = '",input$newsourcefact,"'
                                                                          , odbcName = '",input$odbcname,"'
                                                                          , lastModifiedName = '",Sys.getenv("USERNAME"),"'
                                                                          , lastModifiedTime = current_timestamp where jobid in (", input$jobid,");commit;",sep="" ))
    output$scheduler<-renderDataTable(function(){sqlQuery(tracking.database,paste("select *

                  from ",tracking.schema,".job_scheduler
                  order by sourceDbType, sourceServer, sourceFactTable",sep="")) 
                  })

    # resetting projnew to 0 so that any typing in text box has no impact
    jobmodif <<- 0

    
  })

}
)