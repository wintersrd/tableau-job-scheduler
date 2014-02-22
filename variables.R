# Database variables
number.of.cores<-4 # Increasing the number will allow modeling and data checks to happen faster but will impact network and CPU
tableau.server<-odbcConnect('tableau_server')
tracking.database<-odbcConnect('tableau_server')
tracking.schema<-"public"

# Script control variables
size.estimator.threshold<-1 # Size in MB used to determine whether or not the scheduler should try and schedule a job
remodel.frequency.hours<-24 # How often the server should try to improve accuracy in times a day to run the model
update.recheck.interval.hours<-1 # In the event that a planned schedule results in no data, the scheduler will automatically retry after the given interval
max.jobs.per.day<-24 # Determines what frequency the scheduler will allow
runs.before.confidence<-50 # How many times the script has to run an extract update to determine timing
max.event.records<-5000 # Limit how large your event tracking database can get. If using the Tableau server to track extracts, this should be fairly low

# Credentials for tableau server
tableau.server.username<-"myServerUsername"
tableau.server.password<-"myServerPassword"

# Directories for utilities and local data storage. Note the slash direction
tabcmd.directory<-"C:/Program Files/Tableau/Tableau Server/8.1/bin/"
working.directory<-"X:/Models/"