# R 4.3.3 was used. Install the exact package versions used for the published results.
if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes", repos = "https://cloud.r-project.org")
pk <- c(lavaan = "0.7-3", semTools = "0.5-10", psych = "2.6.9", GPArotation = "2026.8-2", poLCA = "1.6.0.2", nnet = "7.3-19")
for (p in names(pk)) remotes::install_version(p, version = pk[[p]], repos = "https://cloud.r-project.org", upgrade = "never")
