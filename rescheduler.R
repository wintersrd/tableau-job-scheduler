
for (i in 1:number.of.vizql.tasks) {
	data.check<-nrow(sqlQuery(tableau.database,paste("select * from backgrounder_refresh where backgrounder_id = ",i-1,sep="")))
	if (is.na(data.check)) {
		sqlQuery(tableau.database,paste("insert into backgrounder_refresh values (",i-1,",'",format(Sys.time(), "%Y-%m-%d %H:%M:%S"),"');commit;",sep=""))
		} 
	}

		
# Task #1: Terminate and reschedule jobs which are running too long

# First check: Are there any currently running data connections?
running.updates<-sqlQuery(tableau.database, paste("select title
									, backgrounder_id
									, current_date + (current_timestamp - started_at) as currentRunTime
  									, subtitle as taskType
								from _background_tasks
								where started_at is not null
								and completed_at is null
								and site_id = ",site.id,"
								and job_type like '%refresh%'",sep=""))

# Second check: Find out the average run time and standard deviation of successful job completions. We will allow the job to run 20% above the mean or five minutes greater than the mean, whichever is longer
run.time.statistics<-sqlQuery(tableau.database, paste("with runTimes as (select
											title
											, avg(completed_at - started_at) as meanRunTime

											from _background_tasks
											where finish_code = 0
											and title is not null
											and job_type like '%refresh%'
											and site_id = ",site.id,"

											group by 1)
										select title
											, current_date + (case when meanRunTime * ",dynamic.interval.rate," > '",fixed.interval.minutes," minutes' then meanRunTime * (1 + ",dynamic.interval.rate,")
												else meanRunTime + '",fixed.interval.minutes," minutes' end) as runTimeAllowance
                                                     from runTimes"
                                                     , sep=""))

# This will then create a list of tasks outside their threshold
above.threshold<-merge(running.updates,run.time.statistics,by="title",all.x=T,all.y=F)
above.threshold<-above.threshold[above.threshold$currentruntime>=above.threshold$runtimeallowance,c("title","backgrounder_id","tasktype")]

if (nrow(above.threshold)>0){
ids.to.kill<-NULL
for (j in 1:nrow(above.threshold)){
	ids.to.kill<-c(ids.to.kill,unlist(strsplit(above.threshold[j,2],":"))[2])
	}
ids.to.kill<-paste("backgrounder/",ids.to.kill,sep="")

setwd(tabcmd.directory)
# Build a data frame of tasks
running.backgrounders<-data.frame(system("wmic process where caption='backgrounder.exe' get  ProcessId, commandline", intern = T))
process.table<-NULL
for (i in 2:nrow(running.backgrounders)){
	process.list<-unlist(strsplit(as.character(running.backgrounders[i,1])," start "))
	process.name<-process.list[1]
	process.id<-gsub("[^0-9]","",process.list[2])
	if(length(unique(grep(paste(ids.to.kill,collapse="|"),process.name, value=T)))>0){
		system(paste("taskkill /pid ",process.id," /F",sep=""))
		}
	}

system(paste("tabcmd login -u ", tableau.server.username," -p ",tableau.server.password,sep=""))
# Now we need to restart the processes and record the event to vertica
for (j in 1:nrow(above.threshold)){
	refresh.type<-if(above.threshold[j,"tasktype"]=="Workbook"){"workbook"}else{"datasource"}
	system(paste('tabcmd refreshextracts --',refresh.type,' "',above.threshold[j,1],'"',sep=''))
	current.runtime.seconds<-as.numeric(format(as.POSIXlt(above.threshold[j,3]),"%H")) * 3600 + as.numeric(format(as.POSIXlt(above.threshold[j,3]),"%M")) * 60 + as.numeric(format(as.POSIXlt(above.threshold[j,3]),"%S"))
	permitted.runtime.seconds<-as.numeric(format(as.POSIXlt(above.threshold[j,5]),"%H")) * 3600 + as.numeric(format(as.POSIXlt(above.threshold[j,5]),"%M")) * 60 + as.numeric(format(as.POSIXlt(above.threshold[j,5]),"%S"))
	sqlQuery(vertica, paste("insert into ",tracking.schema,".tableau_error_tracking values ('", above.threshold[j,1],"','Terminated automatically due to excessive run time','",format(Sys.time(), "%Y-%m-%d %H:%M:%S"),"',",current.runtime.seconds,",",permitted.runtime.seconds,")",sep=""))
	}
}

# Job 2: Rerun all reports/extracts until we get a successful run, controlling for retry interval
failed.jobs<-sqlQuery(tableau.database,paste("with last_run as (select title, max(created_at) as last_run 
															from _background_tasks
															group by 1)
												, lastSuccess as (select title from _background_tasks
																	where finish_code = 0
																	and completed_at >= current_timestamp - interval '",days.to.retry," days'
																	group by 1)
												select t.title
												, t.subtitle
												, notes
												, t.created_at
												from _background_tasks t
													join last_run l
														on l.title = t.title
														and l.last_run  = t.created_at

													join lastSuccess s
														on s.title = t.title
														
												where finish_code = 1 
												and completed_at is not null
												and site_id = ",site.id,"
												and created_at >= current_date - 2
												and subtitle is not null",sep=""))

run.attempts<-sqlQuery(tracking.database, paste("select jobName
									from ",tracking.schema,".tableau_error_tracking
									where reportTime >= current_timestamp - interval '", wait.hours.before.retry," hours'
									group by 1
									having count(*) >= ", retry.attempts,sep=""))

failed.jobs<-failed.jobs[!failed.jobs$title %in% run.attempts[,1],]

if (nrow(failed.jobs)>0){
system(paste("tabcmd login -u ", tabcmd.login," -p ",tabcmd.password,sep=""))
for (j in 1:nrow(failed.jobs)){
	refresh.type<-if(failed.jobs[j,"subtitle"]=="Workbook"){"workbook"}else{"datasource"}
	system(paste('tabcmd refreshextracts --',refresh.type,' "',failed.jobs[j,1],'"',sep=''))
	sqlQuery(vertica, paste("insert into ",tracking.schema,".tableau_error_tracking values ('",failed.jobs[j,1],"','",failed.jobs[j,3],"','",format(Sys.time(), "%Y-%m-%d %H:%M:%S"),"',NULL,NULL,'",format(as.POSIXlt(failed.jobs[j,4]),"%Y-%m-%d %H:%M:%S"),"')",sep=""))
}
}
setwd(default.working.directory)