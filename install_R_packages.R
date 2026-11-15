# Installs the R packages this project needs. Run it once in R or RStudio (or let the notebook run it).
# Packages go into r_library/ inside this project folder, as ready-made binaries, so no administrator
# rights and no Rtools are needed. Packages you already have elsewhere are used as they are.
# Versions used for the published results (R 4.3.3): lavaan 0.7-3, semTools 0.5-10, psych 2.6.9,
# GPArotation 2026.8-2, poLCA 1.6.0.2, nnet 7.3-19.

# ---- find the project folder and load packages (details in r_scripts/00_setup.R; nothing to edit) ----
local({
  here <- c(gsub("~+~", " ", sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)), fixed = TRUE),
            unlist(lapply(sys.frames(), function(f) f$ofile)),
            tryCatch(rstudioapi::getSourceEditorContext()$path, error = function(e) NULL))
  for (d in c(dirname(here[nzchar(here)]), getwd())) {
    d <- normalizePath(d, winslash = "/", mustWork = FALSE)
    for (k in 1:6) {
      f <- file.path(d, c("00_setup.R", "r_scripts/00_setup.R", "Plastic_NG_GH_project/r_scripts/00_setup.R"))
      if (any(file.exists(f))) { source(f[file.exists(f)][1], local = globalenv()); return(invisible()) }
      d <- dirname(d)
    }
  }
  stop("Cannot find r_scripts/00_setup.R. Run this script from inside the project folder (the one that contains data/processed/).")
})
use_packages(ALL_PACKAGES)
cat("\nProject folder:", root, "\nR", paste(R.version$major, R.version$minor, sep = "."), "\n")
for (p in ALL_PACKAGES) cat(sprintf("  %-12s %s\n", p, as.character(packageVersion(p))))
cat("All R packages are ready.\n")
