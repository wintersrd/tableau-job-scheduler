tracking.database<-odbcConnect(tracking.database.odbc.dsn)
tableau.database<-odbcConnect(tableau.odbc.dsn)

# Table structures
sqlQuery(tracking.database, paste("create table if not exists ",tracking.schema,".job_scheduler (
									jobId serial
									, dataConnector varchar(500)
									, sourceDbType varchar(500)
									, sourceServer varchar(500)
									, sourceType varchar(500)
									, odbcName varchar(500)
									, sourceFactTable varchar(500)
									, baseTimeOfDay int
									, frequency int
									, confidence decimal(10,2)
									, lastRowCount int
									, lastRun timestamp
									, modelLastUpdate timestamp
									, lastModifiedName varchar(500)
									, lastModifiedTime timestamp
									);commit;",sep=""))

sqlQuery(tracking.database, paste("create table if not exists ",tracking.schema,".job_scheduler_events (
									jobId int
									, updateTime timestamp
									, lastRowCount int
									, currentRowCount int
									);commit;", sep=""))

sqlQuery(tracking.database,paste("create table if not exists ",tracking.schema,".odbc_map (
									connectionId serial
									, odbcName varchar(500)
									, sourceDbType varchar(500)
									, sourceServer varchar(500)
									, lastModifiedName varchar(500)
									, lastModifiedTime timestamp									
									);commit;"))

# Ensure target tables exist and are populated
sqlQuery(tableau.database, "create table if not exists backgrounder_refresh
									(
									backgrounder_id int
									, last_refresh timestamp
									);commit;")

sqlQuery(tracking.database,paste("create table if not exists ",tracking.schema,".tableau_error_tracking (
									jobName varchar(500)
									, errorMessage varchar(2000)
									, reportTime timestamp
									, reportedRunTimeSeconds int
									, thresholdRunTimeSeconds int
									, originalRunTime timestamp
									); commit;",sep=""))

# Make sure all connectors are present in the necessary tables - even before able to auto-schedule, we can start gathering performance data
data.connectors<-sqlQuery(tableau.database,paste("select name as dataConnector
											, cast(null as varchar(500)) as sourceDbType
											, cast(null as varchar(500)) as sourceServer
											, 'workbook' as sourceType
											from _workbooks
											where size > ", size.estimator.threshold * 1048576,"
											and site_id = ",site.id,"
											group by 1,2,3
											union

										select name as dataConnector
											, dbclass as sourceDbType
											, server as sourceServer
											, 'datasource' as sourceType
											from _datasources
											where size > ", size.estimator.threshold * 1048576,"
											and site_id = ",site.id,"
											group by 1,2,3", sep=""), stringsAsFactors=F)

existing.data.connectors<-sqlQuery(tracking.database,paste("select dataConnector as existingConnector from ",tracking.schema,".job_scheduler",sep=""), stringsAsFactors=F)
existing.odbc.maps<-sqlQuery(tracking.database,paste("select sourceDbType as existingDb, sourceServer as existingServer from ",tracking.schema,".odbc_map",sep=""), stringsAsFactors=F)

if (nrow(existing.data.connectors)>0) {
  new.data.connectors<-data.connectors[!data.connectors$dataconnector %in% as.list(existing.data.connectors$existingconnector),]
} else {new.data.connectors<-data.connectors}

# We will initialize all connections when available to check hourly until knowing better
if (nrow(new.data.connectors)>0){
  for (i in 1:nrow(new.data.connectors)){
  	sqlQuery(tracking.database,paste("insert into ", tracking.schema,".job_scheduler (dataConnector, sourceDbType, sourceServer, sourceType, baseTimeOfDay, frequency, lastrowcount,confidence,lastRun,modelLastUpdate) 
  	                                 values ('",new.data.connectors[i,1],"','",new.data.connectors[i,2],"','",new.data.connectors[i,3],"','",new.data.connectors[i,4],"',0,24,0,0.1,current_timestamp-interval '1 hour', current_timestamp-interval '1 hour');commit;",sep=""))
  }
}
  
if (nrow(existing.odbc.maps)>0) {
  new.odbc.maps<-data.connectors[!data.connectors$sourceserver %in% as.list(existing.odbc.maps$existingserver),]
} else {new.odbc.maps<-data.connectors}
new.odbc.maps<-unique(new.odbc.maps[!is.na(new.odbc.maps$sourceserver),2:3])

if (nrow(new.odbc.maps)>0){
for (i in 1:nrow(new.odbc.maps)){
	sqlQuery(tracking.database,paste("insert into ", tracking.schema,".odbc_map (sourceDbType, sourceServer) 
	                                 values ('",new.odbc.maps[i,1],"','",new.odbc.maps[i,2],"');commit;",sep=""))
  }
}

# We want each job to use the most current ODBC information for checking, so will update the tables to align. ODBC has to be tracked on the job_scheduler table due to tableau not displaying the ODBC name publicly
try(sqlQuery(tracking.database,paste("update ", tracking.schema,".job_scheduler j
									set odbcName = o.odbcName
								from ",tracking.schema,".odbc_map o
								where j.sourceDbType = o.sourceDbType
									and j.sourceServer = o.sourceServer", sep="")),silent=F)