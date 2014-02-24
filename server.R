source('functions.R')
source('variables.R')

load_libraries(c('shiny','shinyIncubator','ggplot2','RODBC'))

tracking.database<-odbcConnect(tracking.database.odbc.dsn)
tableau.database<-odbcConnect(tableau.odbc.dsn)

event.history<-sqlQuery(tracking.database,paste("select date_trunc('hour',updateTime) as reportHour
                                                              , count(*) as updatesScheduled
                                                            from ",tracking.schema,".job_scheduler_events
                                                            group by 1",sep=""))

subscription.times<-sqlQuery(tableau.database,"select schedule_name 
                                              from _subscriptions 
                                              group by 1 
                                              order by 1")
if(nrow(subscription.times)==0){subscription.times<-data.frame(c("None Found","Please Create At Least One Subscription"))}

shinyServer(function(input, output) {
#output$schedules<-as.list(unique(subscription.times))
emailselection<-reactive({ input$schedule })
users<-reactive({
        sqlQuery(tableau.database,paste("with lastRecord as (select user_id, max(id) as lastId
                                                                      from hist_users
                                                                      group by 1)
                                                          , currentRecord as (select h.user_id
                                                                  , email
                                                                  from hist_users h
                                                                  join lastRecord l
                                                                    on l.user_id = h.user_id
                                                                    and l.lastId =h.id)
                                                          select user_name
                                                              , email
                                                              , coalesce(workbook_url,view_url) as workbook
                                                              , case when customized_view_id is not null then 'Custom view' else NULL end as viewType 
                                                          from _subscriptions s
                                                          join currentRecord c
                                                              on c.user_id = s.user_id
                                                          where schedule_active= true
                                                              and schedule_name = '",input$schedule,"' 
                                                          order by 1",sep=""))
        })

output$odbcmap<-renderDataTable({
        sqlQuery(tracking.database,paste("select connectionId
                                                    , odbcName
                                                    , sourceDbType
                                                    , sourceServer

                                                  from ",tracking.schema,".odbc_map
                                                  order by sourceDbType, sourceServer",sep=""))
        })

output$scheduler<-renderDataTable(function(){
          sqlQuery(tracking.database,paste("select *
                                                          from ",tracking.schema,".job_scheduler
                                                          order by sourceDbType
                                                            , sourceServer
                                                            , sourceFactTable",sep="")) 
        })

output$schedulerrecenthistory<-renderDataTable(function(){
          sqlQuery(tracking.database,paste("select dataConnector
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

output$schedulertrend<-renderPlot({
          qplot(x=reporthour
                , y=updatesscheduled
                , data=event.history
                ,alpha=I(.5)
                ,main="Extracts Triggered per Hour"
                ,ylab="Number of Extracts Scheduled")  
        })

output$subscriberList<-renderTable({users()
        })
        
output$caption<-renderText({input$schedule
        })

output$downloadData<-downloadHandler(
            filename = function() {paste("Scheduler_export_",format(Sys.Date(),"%Y_%m_%d"),".csv",sep="")},
            content = function(file) {
            write.csv(users(),file)
        })


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
              msg="Changes commit immediately on click"
              return(msg)
              }

            sqlQuery(tracking.database,paste("update ",tracking.schema,".odbc_map set odbcName = '",input$newodbc,"'
                                                                          , lastModifiedName = '",Sys.getenv("USERNAME"),"'
                                                                          , lastModifiedTime = current_timestamp where connectionId = ", input$odbcid,";commit;",sep="" ))
            
            output$odbcmap<-renderDataTable({
                sqlQuery(tracking.database,paste("select connectionId
                          , odbcName
                          , sourceDbType
                          , sourceServer

                          from ",tracking.schema,".odbc_map
                          order by sourceDbType, sourceServer",sep=""))
                      }) 

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

    sqlQuery(tracking.server,paste("update ",tracking.schema,".job_scheduler set sourceFactTable = '",input$newsourcefact,"'
                                                                          , odbcName = '",input$scheduleodbc,"'
                                                                          , lastModifiedName = '",Sys.getenv("USERNAME"),"'
                                                                          , lastModifiedTime = current_timestamp where jobid in (", input$jobid,");commit;",sep="" ))
    output$scheduler<-renderDataTable(function(){sqlQuery(tracking.server,paste("select *

                  from ",tracking.schema,".job_scheduler
                  order by sourceDbType, sourceServer, sourceFactTable",sep="")) 
                  })

    # resetting projnew to 0 so that any typing in text box has no impact
    jobmodif <<- 0

    
  })

}
)