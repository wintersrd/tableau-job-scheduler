# Our scheduler needs to smartly interpret the data to determine if it's time for another run
current.hour<-as.numeric(format(as.POSIXlt(Sys.time(),tz="UTC"),"%H"))

# Retrieve the list of schedules
potential.jobs<-sqlQuery(tracking.database, paste("select dataConnector
													, odbcName
													, sourceFactTable
													, baseTimeOfDay
													, frequency
													, lastRun
													, lastRowCount
													, jobId
													, confidence
													, sourceType

													from ", tracking.schema,".job_scheduler

													where odbcName is not null
														and sourceFactTable is not null

													"), stringsAsFactors=F)

if(nrow(potential.jobs)==0){break()} # Terminate the instance if the number of potential jobs is zero

job.list<-NULL
for (i in 1:nrow(potential.jobs)){
	jobs.per.day<-potential.jobs[i,5]*(1/if(potential.jobs[i,9]<0.1){0.1} else {potential.jobs[i,9]})
	jobs.per.day<-if(jobs.per.day>max.jobs.per.day){max.jobs.per.day} else {jobs.per.day}
	hours.to.run<-potential.jobs[i,4]+seq(0,(jobs.per.day-1))*round(24/jobs.per.day,0) # Determine the programmatic hours per day to run
	hours.to.run<-c(hours.to.run[hours.to.run<24],hours.to.run[hours.to.run>=24]-24) # Wrap hours > 23 around the clock
	last.run.hour<-as.numeric(format(potential.jobs[i,6],"%H"))
	next.expected.run<-last.run.hour+round(24/jobs.per.day,0) # If it's been too long since the last run, we'll also reschedule
	next.expected.run<-if(next.expected.run<24){next.expected.run} else {next.expected.run - 24}

	if(current.hour %in% hours.to.run) {
		job.list<-rbind(job.list,potential.jobs[i,])
	}
	if(current.hour>next.expected.run){
		job.list<-rbind(job.list,potential.jobs[i,])
	}
}
if(length(job.list)==0){break()} # Terminate the instance if there are no jobs to check

job.list<-unique(job.list)

updated.datasources<-NULL
for (i in 1:nrow(job.list)) { # This loop will check corresponding fact tables for new data and create a record on the fact table
						db.connection<-odbcConnect(job.list[i,2])
						db.check<-sqlQuery(db.connection,paste("select count(*) as currentRowCount
																from ",job.list[i,3],"
																having count(*) > ",job.list[i,7],sep=""))
						if(nrow(db.check)>0){
							output.record<-c(job.list[i,1],job.list[i,8],job.list[i,7],db.check[1,1],job.list[i,10])
							names(output.record)<-c("dataconnector","jobid","lastrowcount","currentrowcount","sourcetype")
							updated.datasources<-rbind(updated.datasources,output.record)
						}
						odbcClose(db.connection)
					}
updated.datasources<-data.frame(updated.datasources)

# In the event that no new records were found, we'll increment the scheduler by our chosen interval so it will run again
stale.datasources<-job.list[!job.list$jobid %in% as.list(updated.datasources$jobid),8]
if(length(stale.datasources)>0){
	stale.datasources<-paste(as.character(stale.datasources),collapse=",")

	sqlQuery(tracking.database,paste("update ",tracking.schema,".job_scheduler
									set lastRun = lastRun + interval '",update.recheck.interval.hours," hours'
									where jobId in (",stale.datasources,");commit;",sep=""))
}

if(nrow(updated.datasources)==0){break()} # Exit if there are no extracts to refresh

setwd(tabcmd.directory)
system(paste("tabcmd login -s ",tableau.server.path," -u ",tableau.server.username," -p ",tableau.server.password,sep=""), wait=T)

for(i in 1:nrow(updated.datasources)){
	sqlQuery(tracking.database, paste("insert into ",tracking.schema,".job_scheduler_events values (",updated.datasources[i,2],", current_timestamp ,",updated.datasources[i,3],",",updated.datasources[i,4],");commit;",sep=""))
	sqlQuery(tracking.database,paste("update ",tracking.schema,".job_scheduler
										set lastRun = current_timestamp
										, lastRowCount = ", updated.datasources[i,4],"
										where jobid = ", updated.datasources[i,2], sep=""))
	system(paste('tabcmd refreshextracts --', updated.datasources[i,5], ' "',updated.datasources[i,1],'"',sep=''), wait=T)
}
setwd(default.working.directory)