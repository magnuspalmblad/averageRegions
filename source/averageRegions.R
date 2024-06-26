#
# averageRegions.R
#
# MIT License
#
# Copyright (c) 2024 Magnus Palmblad
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

#   The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

print("The output in this window is for debugging and troubleshooting only.")

# Ensure the tcltk package is loaded:
packageName <- "SCiLSLabClient"
if (!requireNamespace(packageName, quietly = TRUE)) {
  # The package is not installed; run the external script to install it
  message(sprintf(
    "Package '%s' is not installed. Attempting to install...",
    packageName
  ))
  
  # Specify the path to your external R script that installs the package:
  pathToScript <-
    "C:/Program Files/SCiLS/SCiLS Lab/APIClients/R/install_SCiLSLab_API_client.R"
  # Run the external script:
  source(pathToScript)
  
  # Optionally, you can check again if the package was successfully installed:
  if (!requireNamespace(packageName, quietly = TRUE)) {
    stop(
      sprintf(
        "Failed to install the package '%s'. Please check for errors and try again.",
        packageName
      )
    )
  } else {
    message(sprintf("Package '%s' has been successfully installed.", packageName))
  }
} else {
  message(sprintf("Package '%s' is already installed.", packageName))
}

# Ensure the tcltk package is loaded:
if (!requireNamespace("tcltk"))
  install.packages("tcltk")
library(tcltk)

# Initialize file path variables:
file1 <- ""
file2 <- ""

# Create the main window:
win <- tktoplevel()
tkwm.title(win, "averageRegions")

# Set the window size:
tkwm.geometry(win, "730x235")


# Initialize text entries for displaying file names:
entryFile1 <- tkentry(win, width = 80)
entryFile2 <- tkentry(win, width = 80)

# Define function to update file path variables and display file names:
updateFilePath <- function(id, path) {
  path <- as.character(path)
  if (id == 1 && length(path) > 0) {
    file1 <<- path
    tkdelete(entryFile1, 0, "end")
    tkinsert(entryFile1, 0, basename(path))
  } else if (id == 2 && length(path) > 0) {
    file2 <<- path
    tkdelete(entryFile2, 0, "end")
    tkinsert(entryFile2, 0, basename(path))
  }
}

# Define function to be executed when the button is pressed:
runScriptOnFiles <- function() {
  if (file2 != "") {
    library(SCiLSLabClient)
    
    # select image file:
    temporary_directory <- tempfile(pattern = "slxdir")
    datafile <- file.path(file2)
    
    # direct load (development, remove later):
    # setwd('D:/Users/nmpalmblad/Desktop')
    # datafile <- 'D:/Users/nmpalmblad/Desktop/cerebella.slx'
    
    output_directory <- strsplit(datafile, "\\.slx$")[[1]]
    if (file.exists(output_directory)) {
      print("Warning: Output directory already exists!")
    } else {
      # Create a new subdirectory based on the SLX filename
      dir.create(output_directory)
    }
    
    # start the local server session:
    for (tryCount in 1:30) {
      tryPort <- sample(8082:65535, 1)
      dummy <- c()
      dummy$filelock = FALSE
      data <-
        tryCatch(
          SCiLSLabOpenLocalSession(datafile, port = tryPort),
          error = function(e) {
            print(e$message)
            if (grepl("File is locked by another instance", e$message))
              dummy$filelock = TRUE
            dummy$server_up = FALSE
            return(dummy)
          }
        )
      if (data$server_up)
        # we're good to go...
        break
      if (data$filelock) {
        button <- tk_messageBox(type = "retrycancel",
                                message = "File is locked by another instance.",
                                default = "retry")
        if (button == "cancel") {
          tkdestroy(win)
          quit(save = "no", status = 0)
        }
      }
    }
    
    if (!data$server_up) {
      button <- tk_messageBox(type = "ok",
                              message = "Failed to open file.",
                              default = "ok")
      if (button == "ok") {
        tkdestroy(win)
        quit(save = "no", status = 0)
      }
    }
    
    # import the region list from a CSV file (saved from SCiLS Lab):
    if (file1 != "") {
      regions_file <- file.path(file1)
      regions <- read.csv(regions_file, skip = 8, sep = ";")
    }
    
    # get regions and coordinates from data:
    regTree <- getRegionTree(data)
    
    for (i in 1:length(regTree$subregions)) {
      print(paste(
        "Extracting average spectrum from region",
        regTree$subregions[[i]]$name
      ))
      averageSpectrum <-
        getMeanSpectrum(data, regionId = regTree$subregions[[i]]$uniqueId)
      # plot cerebella region spectra for debugging
      # plot(
      #   x = averageSpectrum$mz,
      #   y = averageSpectrum$intensities,
      #   col = c("red", "blue", "green")[i],
      #   type = "l"
      # )
      
      if (tclvalue(renameState) == "1") {
        x <- 0
        y <- 0
        n <- 0
        for (j in 1:length(regTree$subregions[[i]]$polygons)) {
          x <- x + sum(regTree$subregions[[i]]$polygons[[j]]$x)
          y <- y + sum(regTree$subregions[[i]]$polygons[[j]]$y)
          n <- n + length(regTree$subregions[[i]]$polygons[[j]]$x)
        }
        average_x <- round(x / n)
        average_y <- round(y / n)
        output_file <-
          paste0(output_directory,
                 "/x",
                 average_x,
                 "_",
                 "y",
                 average_y,
                 ".xy")
        file.create(output_file)
      } else {
        output_file <-
          paste0(output_directory,
                 "/",
                 strsplit(regTree$subregions[[i]]$name, "/")[[1]][2],
                 ".xy")
        file.create(output_file)
      }
      
      # store spectrum in matrix for faster write to file
      averageSpectrumMatrix <-
        matrix(
          c(averageSpectrum$mz, averageSpectrum$intensities),
          ncol = 2,
          byrow = FALSE
        )
      
      if (tclvalue(normalizeState) == "1") {
        TIC <- sum(averageSpectrumMatrix[, 2])
        averageSpectrumMatrix[, 2] <-
          averageSpectrumMatrix[, 2] / TIC
      }
      write.table(
        averageSpectrumMatrix,
        file = output_file,
        row.names = FALSE,
        col.names = FALSE
      )
    }
    
    # cleanup (run these before switching to SCiLS Lab - R session can be kept open):
    close(data)
    Sys.sleep(1)
    unlink(temporary_directory, recursive = TRUE)
    
    if (tclvalue(normalizeState) == "0")
      endMessage <-
      paste0(
        "Average spectra for regions have been exported to the Bruker .xy format in ",
        output_directory,
        "."
      )
    if (tclvalue(normalizeState) == "1")
      endMessage <-
      paste0(
        "Normalized average spectra for regions have been exported to the Bruker .xy format in ",
        output_directory,
        "."
      )
    
    # Display a confirmation message when done:
    tkmessageBox(
      message = endMessage,
      title = "Confirmation",
      icon = "info",
      type = "ok"
    )
    
    # Then close the GUI window:
    tkdestroy(win)
    
  } else {
    tkmessageBox(message = "Please select at least an .slx file before running averageRegions.")
  }
}

# Create tooltip:
# Function to create a tooltip
createTooltip <- function(x, y, text) {
  tooltip <- tktoplevel(win, takefocus = NA)
  tkwm.overrideredirect(tooltip, TRUE) # Make it a borderless window
  tkwm.geometry(tooltip, paste("+", x, "+", y, sep = "")) # Position near the cursor/button
  label <-
    tklabel(
      tooltip,
      text = text,
      justify = "left",
      background = "yellow",
      relief = "solid",
      borderwidth = 1
    )
  tkpack(label)
  return(tooltip)
}

btnFile1 <-
  tkbutton(
    win,
    text = "Select regions (.csv) file",
    padx = 3,
    command = function() {
      filePath <-
        tkgetOpenFile(filetypes = "{{CSV files} {.csv}} {{All files} {*}}")
      if (!is.null(filePath) && length(filePath) > 0) {
        updateFilePath(1, filePath)
      }
    }
  )
tkgrid(
  btnFile1,
  row = 1,
  column = 1,
  padx = 10,
  pady = 20
)

# Bind mouse events to the button to show and hide the tooltip:
tooltip <- NULL
tkbind(btnFile1, "<Enter>", function(...) {
  info <- .Tcl("winfo pointerxy .")
  coords <- strsplit(as.character(info), " ")
  x <- as.numeric(coords[1]) + 10
  y <- as.numeric(coords[2]) + 10
  tooltip <<-
    createTooltip(x, y, "Select the file listing the regions (optional)")
})
tkbind(btnFile1, "<Leave>", function(...) {
  if (!is.null(tooltip)) {
    tkdestroy(tooltip)
    tooltip <<- NULL
  }
})

# Add the text entry for File 1 next to its button:
tkgrid(
  entryFile1,
  row = 1,
  column = 2,
  columnspan = 2,
  padx = 10,
  pady = 10
)

# Add file selection button for File 2 with padding and text entry:
btnFile2 <-
  tkbutton(
    win,
    text = "Select SCiLS Lab .slx file",
    padx = 5,
    command = function() {
      filePath <-
        tkgetOpenFile(filetypes = "{{SLX files} {.slx}} {{All files} {*}}")
      if (!is.null(filePath) && length(filePath) > 0) {
        updateFilePath(2, filePath)
      }
    }
  )
tkgrid(
  btnFile2,
  row = 2,
  column = 1,
  padx = 10,
  pady = 10
)

# Position the text entry for File 2 next to its button:
tkgrid(
  entryFile2,
  row = 2,
  column = 2,
  columnspan = 2,
  padx = 10,
  pady = 10
)

# Bind mouse events to the button to show and hide the tooltip:
tooltip <- NULL
tkbind(btnFile2, "<Enter>", function(...) {
  info <- .Tcl("winfo pointerxy .")
  coords <- strsplit(as.character(info), " ")
  x <- as.numeric(coords[1]) + 10
  y <- as.numeric(coords[2]) + 10
  tooltip <<- createTooltip(x, y, "Select the SCiLS Lab dataset")
})
tkbind(btnFile2, "<Leave>", function(...) {
  if (!is.null(tooltip)) {
    tkdestroy(tooltip)
    tooltip <<- NULL
  }
})

# Add button to run the script on the selected files with padding:
btnRunScript <-
  tkbutton(win, text = "Average spectra per region", command = runScriptOnFiles)
tkgrid(
  btnRunScript,
  row = 4,
  column = 1,
  columnspan = 3,
  padx = 10,
  pady = 5
)

# Bind mouse events to the button to show and hide the tooltip:
tooltip <- NULL
tkbind(btnRunScript, "<Enter>", function(...) {
  info <- .Tcl("winfo pointerxy .")
  coords <- strsplit(as.character(info), " ")
  x <- as.numeric(coords[1]) + 10
  y <- as.numeric(coords[2]) + 10
  tooltip <<-
    createTooltip(x, y, "Run averageRegions on selected regions and SCiLS Lab file")
})
tkbind(btnRunScript, "<Leave>", function(...) {
  if (!is.null(tooltip)) {
    tkdestroy(tooltip)
    tooltip <<- NULL
  }
})


# Variable to hold the state of the checkbox (1 for checked, 0 for unchecked):
normalizeState <- tclVar(0)

# Create a checkbox
chkBox <-
  tkcheckbutton(win,
                padx = 15,
                text = "Normalize spectra to 1",
                variable = normalizeState)

tkgrid(
  chkBox,
  row = 3,
  column = 1,
  columnspan = 1,
  padx = 10,
  pady = 20
)

# Variable to hold the state of the checkbox (1 for checked, 0 for unchecked):
renameState <- tclVar(0)

# Create a checkbox
chkBox <-
  tkcheckbutton(win, text = "(Re)name spectra by coordinates", variable = renameState)

tkgrid(
  chkBox,
  row = 3,
  column = 2,
  columnspan = 1,
  padx = 10,
  pady = 20
)

# Variable to hold the state of the checkbox (1 for checked, 0 for unchecked):
alignmentState <- tclVar(0)

# Create a checkbox
chkBox <-
  tkcheckbutton(win, text = "Align spectra", variable = alignmentState)

tkgrid(
  chkBox,
  row = 3,
  column = 3,
  columnspan = 1,
  padx = 10,
  pady = 20
)

# Start the Tcl/Tk event loop:
tkwait.window(win)
