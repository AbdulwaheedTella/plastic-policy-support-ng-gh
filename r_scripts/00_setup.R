# Shared setup for every R script in this project. Nothing here needs editing.
#
# 1. Finds the project folder by itself (the folder that holds data/processed/survey_merged_deidentified.csv),
#    whether the script is run from the notebook, with Rscript, or with source() / Run in RStudio.
# 2. Uses a package library inside the project folder (r_library/), so no administrator rights are needed
#    and everything stays in the one folder.
# 3. Installs any missing package as a ready-made CRAN binary (no Rtools or compiler needed on Windows).

DATA_FILE <- file.path("data", "processed", "survey_merged_deidentified.csv")
CRAN <- "https://cloud.r-project.org"
ALL_PACKAGES <- c("lavaan", "semTools", "psych", "GPArotation", "poLCA", "nnet")

find_project_root <- function() {
  starts <- character(0)
  given <- commandArgs(trailingOnly = TRUE)                        # folder passed by the notebook, if any
  if (length(given) && nzchar(given[1]) && dir.exists(given[1])) starts <- c(starts, given[1])
  file_arg <- gsub("~+~", " ", sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)), fixed = TRUE)
  if (length(file_arg)) starts <- c(starts, dirname(file_arg[1]))
  for (i in rev(seq_len(sys.nframe()))) {                          # source("script.R")
    of <- sys.frame(i)$ofile
    if (!is.null(of)) starts <- c(starts, dirname(of))
  }
  p <- tryCatch(rstudioapi::getSourceEditorContext()$path, error = function(e) "")   # Run lines in RStudio
  if (length(p) == 1 && nzchar(p)) starts <- c(starts, dirname(p))
  starts <- c(starts, getwd())
  for (s in starts) {
    d <- normalizePath(s, winslash = "/", mustWork = FALSE)
    for (k in 1:6) {                                               # look in this folder and up to 5 above it
      if (file.exists(file.path(d, DATA_FILE))) return(d)
      if (file.exists(file.path(d, "Plastic_NG_GH_project", DATA_FILE))) return(file.path(d, "Plastic_NG_GH_project"))
      up <- dirname(d); if (up == d) break; d <- up
    }
  }
  stop("Could not find the project folder. Open or run this script from inside the project folder (the one that contains data/processed/).",
       call. = FALSE)
}

use_packages <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    message("Installing missing R packages into ", LIB, ": ", paste(missing, collapse = ", "))
    type <- if (.Platform$OS.type == "windows" || Sys.info()[["sysname"]] == "Darwin") "binary" else "source"
    for (p in missing) {
      ok <- tryCatch({ suppressWarnings(install.packages(p, lib = LIB, repos = CRAN, type = type, quiet = TRUE))
                       requireNamespace(p, quietly = TRUE) }, error = function(e) FALSE)
      if (!isTRUE(ok) && type == "binary") {                       # no binary for this R version: try "both"
        ok <- tryCatch({ suppressWarnings(install.packages(p, lib = LIB, repos = CRAN, type = "both", quiet = TRUE))
                         requireNamespace(p, quietly = TRUE) }, error = function(e) FALSE)
      }
      if (!isTRUE(ok)) stop("Could not install the R package '", p, "'. Check your internet connection, then run ",
                            "install_R_packages.R once in R or RStudio and read the message it prints.", call. = FALSE)
    }
  }
  for (p in pkgs) suppressPackageStartupMessages(library(p, character.only = TRUE))
  invisible(TRUE)
}

root <- find_project_root()
LIB <- file.path(root, "r_library", paste0("R-", R.version$major, ".", sub("\\..*", "", R.version$minor)))
dir.create(LIB, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(LIB, .libPaths()))
tab <- file.path(root, "outputs", "tables"); mod <- file.path(root, "outputs", "models")
for (p in c(tab, mod, file.path(root, "outputs", "logs"))) dir.create(p, recursive = TRUE, showWarnings = FALSE)
