setWd('X:/TableauScheduler/') # Working Directory where main can find all the utilities

source('functions.R') # Load the necessary functions

load_libraries(c('RODBC','nnet','snow','doSNOW','foreach')) # NOTE: SNOW is for Windows only. Alternate code for linux is below

source('variables.R')

cl<-makeCluster(rep("localhost",number.of.cores),type="SOCK") 
registerDoSNOW(cl)

source('database_manager.R') # This script ensures that all the necessary tables are up to date and available

source('modeling.R') # This script determines how often an updates should be run
source('scheduler.R') # This script runs the actual task of checking for new data and, if necessary, triggering a tableau update
source('rescheduler.R') # This script will kill and restart any runaway jobs and reschedule jobs which have failed in the past

# Alternate code to use on a Linux machine
# load_libraries(c('RODBC','nnet','doMC','foreach'))
# registerDoMC(number.of.cores)