setwd('X:/TableauScheduler/') # R needs to know where to find all the files

source('functions.R') # Load the necessary functions
source('variables.R')

load_libraries(c('RODBC','nnet','snow','doSNOW','foreach')) # NOTE: SNOW is for Windows only. Alternate code for linux is below
cl<-makeCluster(rep("localhost",number.of.cores),type="SOCK") 
registerDoSNOW(cl)

source('database_manager.R') # This script ensures that all the necessary tables are up to date and available

source('modeling.R') # This script determines how often an update should be run
source('scheduler.R') # This script runs the actual task of checking for new data and, if necessary, triggering a tableau update


# Alternate code to use on a Linux machine
# load_libraries(c('RODBC','nnet','doMC','foreach'))
# registerDoMC(number.of.cores)