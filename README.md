This is a simple scheduled utility plus front end to manage database connections between Tableau Server and any number of databases (must be accessible via ODBC). 

Key Features:
* Self-learning model, initially actively searches for data updates then uses the data to determine what time(s) per day to check
* Automatic rescheduling when data is expected but not present (ex. due to slow ETL)
* Automatic rescheduling of failed extract jobs
* Automatic killing/rescheduling of runaway jobs (based on a time variance versus average)
* Termination of idle connections to databases after a specified interval (currently only for Vertica)
* Tracks extract failures and incremental data updates to core fact tables
* Change tracking for management data in scheduler

To get started:
1) Clone the repository
2) Ensure that the following components are installed on your Tableau server:
	<a href="http://cran.r-project.org/bin/windows/Rtools/">R Tools</a>
	<a href="http://cran.r-project.org/web/packages/shiny/shiny.pdf">Shiny (install.packages('shiny') )</a>
	<a href="https://github.com/rstudio/shiny-incubator"> Shiny Incubator</a>
3) Configure variables.R with your credentials
4) Set the working directory in main.R and interface.R
5) Configure Tableau server to allow access to the database and set up an ODBC link

Running the utility:
1) Schedule a task to run "Rscript /path/to/main.R" on a regular basis; ours runs every ten minutes
2) Schedule a task on server startup to run "Rscript /path/to/interface.R"

Using the utility:
On first run, the script will create the database structure and capture all necessary information from Tableau's database. Navigating to http://localhost:9100 will expose the interface with three options:
	<b>Manage ODBC links:</b> All native database connections will be available, add a corresponding ODBC DSN. This information will be passed to the job scheduler table on next scheduled run and will be available for all new data connections added from the same source.
	<b>Manage job schedules:</b> Provide a corresponding fact table to monitor for updates (uses a simple count). Any connections via ODBC or directly embedded in workbooks are not available from tableau and so must be manually added using the dropdown.
	<b>Monitor scheduler:</b> A simple view to see the number of jobs scheduled per hour and the results of the last 50 scheduled runs.