# for loading move CSV files
library(move)
# for reading files from disk
source("Helper.R")

rFunction = function(
    settings=NULL,                # MoveApps settings (unused)
    file=NULL,                    # MoveApps settings section `file` (unused)
    folder=NULL,                  # MoveApps settings section `folder` (unused)
    id=NULL,                      # The id of the file in the cloud-provider context
    fileId=NULL,                  # The id of the file (includes folder of file)
    fileName=NULL,                # The original file-name (in cloud and placed locally)
    mimeType=NULL,                # The mime-type of the file (unused)
    cloudFileLocalFolder="/tmp",  # local directory of cloud-file
    data=NULL                     # The data of the prev. apps in the workflow
) {
  Sys.setenv(tz="UTC") #fix, so that time zones will be transformed into UTC (input RDS files (or data from prev app) with tz=NULL are forced to UTC)
  
  if (! is.null(fileId)) {
    logger.info(paste("Downloaded file '", fileId, "' from cloud provider.", sep = ""))
  }
  
  cloudSource <- NULL
  result <- NULL
  
  if (! is.null(fileName)) {   
       cloudSource <- tryCatch({
        # 1: try to read input as (any) RDS file
        readInput(paste(cloudFileLocalFolder,"/",fileName,sep = ""))
      },
      error = function(readRdsError) {
        tryCatch({
          # 2 (fallback): try to read input as move CSV file
          # first clean order of file as move() needs it, just to prevent some errors
          csvSource <- read.csv(sourceFile,header=TRUE)
          o <- order(csvSource$individual.local.identifier,as.POSIXct(csvSource$timestamp))
          move(csvSource[o,], removeDuplicatedTimestamps=TRUE)
        },
        error = function(readCsvError) {
          # collect errors for report and throw custom error
          stop(paste(sourceFile, " -> readRDS(sourceFile): ", readRdsError, "move(sourceFile): ", readCsvError, sep = ""))
        })
      })      
      
    logger.info(paste0("Data from Cloud have time zone: ",attr(timestamps(cloudSource),'tzone')))
    if (is.null(attr(timestamps(cloudSource),'tzone'))) attr(timestamps(cloudSource),'tzone') <- "UTC" #maybe too much of a hack (?)
    result <- cloudSource
    logger.info("Successfully read file from cloud provider (locally).")
  }
  
  if (exists("data") && !is.null(data)) {
    logger.info("Merging input from prev. app and cloud file together.")
    logger.info(paste0("Data from prev App have time zone: ",attr(timestamps(data),'tzone')))
    if (is.null(attr(timestamps(data),'tzone'))) attr(timestamps(data),'tzone') <- "UTC" #maybe too much of a hack (?)
    logger.info(paste0("Data from Cloud have time zone: ",attr(timestamps(cloudSource),'tzone')))
    if (is.null(attr(timestamps(cloudSource),'tzone'))) attr(timestamps(cloudSource),'tzone') <- "UTC" #maybe too much of a hack (?)
    result <- moveStack(cloudSource, data,forceTz="UTC")
    
  } else {
    logger.info("No input from prev. app provided, nothing to merge. Will deliver the mapped cloud-file only.")
  }
  
  # Fallback to make sure it is always a moveStack object and not a move object.
  if (is(result,'Move')) {
    result <- moveStack(result,forceTz="UTC")
  }
  
  logger.info("I'm done.")
  result
}
