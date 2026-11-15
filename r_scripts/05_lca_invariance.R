# Are the three latent classes the same in both countries? Called as: Rscript 05_lca_invariance.R <project folder>
# Compares a homogeneous model (same item-response probabilities in both countries, class sizes free by country)
# with a heterogeneous model (a separate 3-class model in each country), following Kankaras et al. (2018).
suppressPackageStartupMessages(library(poLCA))
set.seed(20231101)
root <- commandArgs(trailingOnly = TRUE)[1]; tab <- file.path(root, "outputs", "tables")
d <- read.csv(file.path(root, "data", "processed", "survey_merged_deidentified.csv"))
d <- d[d$flag_no_likert == 0, ]
harm <- c("flood", "erosion", "vector", "infiltration", "buildings", "toxic", "microbes", "nutrients",
          "bags_billions", "waterways_tons", "aquatic", "food", "terrestrial", "harmful_env")
d$HARM <- rowMeans(d[, harm], na.rm = TRUE); d$HARM[is.nan(d$HARM)] <- NA
d$SUPPORT <- rowMeans(d[, c("polluter_pays", "legal", "biodeg_alt", "cheap_bioplastic")], na.rm = TRUE)
d$SUPPORT[is.nan(d$SUPPORT)] <- NA
cut3c <- function(x) as.integer(cut(x, c(-Inf, 2.999, 3.999, Inf)))
cut3i <- function(x) as.integer(cut(x, c(-Inf, 2.5, 3.5, Inf)))
L <- data.frame(HARM = cut3c(d$HARM), SUPPORT = cut3c(d$SUPPORT), everybody = cut3i(d$everybody),
                charges = cut3i(d$charges), gov_resp = cut3i(d$gov_resp), cheaper_plastic = cut3i(d$cheaper_plastic),
                engagement = as.integer(cut(d$engagement, c(-Inf, 1.01, 2.01, Inf))), ghana = as.numeric(d$country == "Ghana"))
f0 <- cbind(HARM, SUPPORT, everybody, charges, gov_resp, cheaper_plastic, engagement) ~ 1
fit <- function(f, dat) poLCA(f, dat, nclass = 3, nrep = 50, maxiter = 5000, na.rm = FALSE, verbose = FALSE)

hom <- fit(cbind(HARM, SUPPORT, everybody, charges, gov_resp, cheaper_plastic, engagement) ~ ghana, L)
ng <- fit(f0, L[L$ghana == 0, ]); gh <- fit(f0, L[L$ghana == 1, ])
N <- nrow(L)
ll_het <- ng$llik + gh$llik; np_het <- ng$npar + gh$npar
res <- data.frame(model = c("Homogeneous (equal item probabilities, class sizes by country)", "Heterogeneous (separate model per country)"),
                  loglik = c(hom$llik, ll_het), npar = c(hom$npar, np_het))
res$BIC <- -2 * res$loglik + res$npar * log(N); res$AIC <- -2 * res$loglik + 2 * res$npar
res$LR <- c(NA, 2 * (ll_het - hom$llik)); res$df <- c(NA, np_het - hom$npar)
res$p <- c(NA, pchisq(res$LR[2], res$df[2], lower.tail = FALSE))
write.csv(res, file.path(tab, "T10j_lca_invariance.csv"), row.names = FALSE)

# Class profiles per country, ordered like the pooled model (class 1 = highest support)
prof <- function(m, lab) { ord <- order(-sapply(1:3, function(j) m$probs$SUPPORT[j, 3]))
  do.call(rbind, lapply(names(m$probs), function(v) data.frame(model = lab, indicator = v, class = 1:3,
    p_high = round(m$probs[[v]][ord, 3], 3), p_low = round(m$probs[[v]][ord, 1], 3), share = round(m$P[ord], 3)))) }
pr <- rbind(prof(ng, "Nigeria only"), prof(gh, "Ghana only"), prof(hom, "Pooled homogeneous"))
write.csv(pr, file.path(tab, "T10k_lca_profiles_by_country.csv"), row.names = FALSE)
print(res); print(pr[pr$indicator %in% c("HARM", "SUPPORT", "cheaper_plastic"), ])
