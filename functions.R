load_libraries <- function(libraries, silent=F) {
    for(l in libraries) {
        if (silent) {
            if (suppressMessages(suppressWarnings(!require(l, character.only = TRUE)))) {
                    install.packages(l, repos = "http://lib.stat.cmu.edu/R/CRAN")
                    suppressMessages(suppressWarnings(library(l, character.only = TRUE)))
                }
        } else {
            if (suppressWarnings(!require(l, character.only = TRUE))) {
                install.packages(l, repos = "http://lib.stat.cmu.edu/R/CRAN")
                suppressWarnings(library(l, character.only = TRUE))
            }
        }
    }
    
}

Mode <- function(x) {
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}