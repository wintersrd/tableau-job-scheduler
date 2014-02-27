# Determine which models are old enough to justify rerunning
models.to.update<-sqlQuery(tracking.database,paste("select * from ",tracking.schema,".job_scheduler
								where modelLastUpdate < current_timestamp - interval '",remodel.frequency.hours," hours'", sep=""))
if(nrow(models.to.update)>0){
	for(i in 1:nrow(models.to.update)){ # We single thread this due to the need to do updates to the table and locking = BAD
		modeling.data<-sqlQuery(tracking.database,paste("select * from ",tracking.schema,".job_scheduler_events
													where jobid = ",models.to.update[i,"jobid"],sep=""))
		if(nrow(modeling.data)>5){
		modeling.data$hour<-as.numeric(format(modeling.data$updatetime,"%H"))
		baseline.update.time<-Mode(modeling.data$hour) # We will take the mode to determine which hour to frame our timing around
		
		updates.per.day<-table(format(modeling.data$updatetime,"%Y-%m-%d"))
		update.frequency<-ceiling(mean(updates.per.day)) # We take the mean updates per day to estimate how often new data is available. This should ideally be a weighted mean
		
		confidence<-min((nrow(modeling.data)/runs.before.confidence)^1.5,1) # Confidence will increase slowly at first (meaning the scheduler will try more often) then ramp to peak confidence. Need to integrate additional sampling

		sqlQuery(tracking.database,paste("update ",tracking.schema,".job_scheduler
										set baseTimeOfDay = ", baseline.update.time,"
										, frequency = ",update.frequency,"
										, confidence = ", confidence,"
										, modelLastUpdate = current_timestamp
										where jobid = ",models.to.update[i,"jobid"],";commit;",sep=""))
		}
	}
	# Clean up the database. If it's over the row limit, prune it back to 20% below limit
	current.row.count<-sqlQuery(tracking.database,paste("select count(*) from ",tracking.schema,".job_scheduler_events"))[1,1]
	if(current.row.count> max.event.records){
		delete.prior<-sqlQuery(tracking.database,paste("with recordSort as (select updateTime
															, row_number() over (order by updateTime desc) as rownum

															from ",tracking.schema,".job_scheduler_events
															)
															select updateTime 

															from recordsort
															
															where rownum = ", max.event.records * 0.8,sep=""))[1,1]
		sqlQuery(tracking.database,paste("delete from ",tracking.schema,".job_scheduler_events
											where updateTime <= '",format(delete.prior,"%Y-%m-%d %H:%M:%S"),"';commit;",sep=""))
	}
}