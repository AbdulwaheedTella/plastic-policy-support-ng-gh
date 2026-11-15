# Latent class analysis of policy orientations (pooled sample). Run from the notebook, with Rscript, or with source() in RStudio
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
use_packages(c("poLCA", "nnet"))
set.seed(20231101)
d <- read.csv(file.path(root, "data", "processed", "survey_merged_deidentified.csv"))
d <- d[d$flag_no_likert == 0, ]
harm <- c("flood", "erosion", "vector", "infiltration", "buildings", "toxic", "microbes", "nutrients",
          "bags_billions", "waterways_tons", "aquatic", "food", "terrestrial", "harmful_env")
d$HARM <- rowMeans(d[, harm], na.rm = TRUE); d$HARM[is.nan(d$HARM)] <- NA
d$SUPPORT <- rowMeans(d[, c("polluter_pays", "legal", "biodeg_alt", "cheap_bioplastic")], na.rm = TRUE)
d$SUPPORT[is.nan(d$SUPPORT)] <- NA
cut3c <- function(x) as.integer(cut(x, c(-Inf, 2.999, 3.999, Inf)))   # composite: <3, 3 to <4, >=4
cut3i <- function(x) as.integer(cut(x, c(-Inf, 2.5, 3.5, Inf)))       # single item: disagree, neutral, agree
L <- data.frame(HARM = cut3c(d$HARM), SUPPORT = cut3c(d$SUPPORT), everybody = cut3i(d$everybody),
                charges = cut3i(d$charges), gov_resp = cut3i(d$gov_resp), cheaper_plastic = cut3i(d$cheaper_plastic),
                engagement = as.integer(cut(d$engagement, c(-Inf, 1.01, 2.01, Inf))))
f <- cbind(HARM, SUPPORT, everybody, charges, gov_resp, cheaper_plastic, engagement) ~ 1
entropy_r2 <- function(m) { p <- m$posterior; k <- ncol(p); if (k == 1) return(NA)
  1 - sum(-p * log(pmax(p, 1e-12))) / (nrow(p) * log(k)) }

# fit 1 to 7 classes, 50 random starts each
fits <- list(); rows <- list()
for (k in 1:7) {
  m <- poLCA(f, L, nclass = k, nrep = 50, maxiter = 5000, na.rm = FALSE, verbose = FALSE)
  fits[[k]] <- m; modal <- apply(m$posterior, 1, which.max)
  rows[[k]] <- data.frame(k = k, loglik = m$llik, npar = m$npar, BIC = m$bic, AIC = m$aic,
                          aBIC = -2 * m$llik + m$npar * log((m$N + 2) / 24), entropy_R2 = entropy_r2(m),
                          smallest_class_pct = 100 * min(tabulate(modal, k)) / length(modal),
                          avg_post_min = if (k == 1) 1 else min(sapply(1:k, function(j) mean(m$posterior[modal == j, j]))),
                          Gsq = m$Gsq, resid_df = m$resid.df)
}
fs <- do.call(rbind, rows); write.csv(round(fs, 3), file.path(tab, "T10a_lca_model_selection.csv"), row.names = FALSE)
ok <- fs[fs$smallest_class_pct >= 5 & (fs$entropy_R2 >= 0.70 | fs$k == 1), ]
K <- ok$k[which.min(ok$BIC)]; m <- fits[[K]]
ord <- order(-sapply(1:K, function(j) m$probs$SUPPORT[j, 3]))   # class 1 = highest support
post <- m$posterior[, ord, drop = FALSE]
d$class <- apply(post, 1, which.max); d$class_post <- apply(post, 1, max)

ip <- do.call(rbind, lapply(names(m$probs), function(v) { pr <- m$probs[[v]][ord, , drop = FALSE]
  data.frame(indicator = v, class = 1:K, p_low = round(pr[, 1], 3), p_mid = round(pr[, 2], 3), p_high = round(pr[, 3], 3)) }))
write.csv(ip, file.path(tab, "T10b_lca_item_probabilities.csv"), row.names = FALSE)

ct <- table(d$class, d$country)[, c("Nigeria", "Ghana")]; cs <- suppressWarnings(chisq.test(ct))
pw <- sapply(c("Nigeria", "Ghana"), function(c) colSums(post[d$country == c, , drop = FALSE]) / sum(d$country == c) * 100)
comp <- data.frame(class = 1:K, Nigeria_n = as.integer(ct[, 1]), Ghana_n = as.integer(ct[, 2]),
                   Nigeria_pct = round(100 * ct[, 1] / sum(ct[, 1]), 1), Ghana_pct = round(100 * ct[, 2] / sum(ct[, 2]), 1),
                   Nigeria_pct_postweighted = round(pw[, 1], 1), Ghana_pct_postweighted = round(pw[, 2], 1),
                   class_size_pct = round(100 * colMeans(post), 1), mean_posterior = round(tapply(d$class_post, d$class, mean), 3),
                   chi2 = round(cs$statistic, 2), df = cs$parameter, p = signif(cs$p.value, 3),
                   cramers_v = round(sqrt(cs$statistic / (sum(ct) * (min(dim(ct)) - 1))), 3), selected_k = K)
write.csv(comp, file.path(tab, "T10c_lca_country_composition.csv"), row.names = FALSE)

# membership adjusted for demographics (multinomial logit; reference = largest class)
d$ghana <- as.numeric(d$country == "Ghana"); d$female <- ifelse(is.na(d$gender), NA, as.numeric(d$gender == "Female"))
d$age_o <- as.numeric(factor(d$age, levels = c("18-27", "28-37", "38-47", "48+")))
d$city <- ifelse(is.na(d$community), NA, as.numeric(d$community == "City"))
d$student <- ifelse(is.na(d$occ_group), NA, as.numeric(d$occ_group == "Student"))
ref <- which.max(table(d$class)); d$class_f <- relevel(factor(d$class), ref = as.character(ref))
mn <- multinom(class_f ~ ghana + female + age_o + city + income_top + student, data = d, trace = FALSE)
co <- summary(mn)$coefficients; se <- summary(mn)$standard.errors
if (is.null(dim(co))) { co <- t(as.matrix(co)); se <- t(as.matrix(se)); rownames(co) <- rownames(se) <- levels(d$class_f)[2] }
mt <- do.call(rbind, lapply(rownames(co), function(r) data.frame(contrast = paste0("C", r, " vs C", ref), term = colnames(co),
  b = round(co[r, ], 3), rrr = round(exp(co[r, ]), 3), se = round(se[r, ], 3), p = signif(2 * pnorm(-abs(co[r, ] / se[r, ])), 3), row.names = NULL)))
write.csv(mt, file.path(tab, "T10d_lca_multinomial_membership.csv"), row.names = FALSE)
cm <- aggregate(d[, c("HARM", "SUPPORT", "everybody", "charges", "gov_resp", "cheaper_plastic", "engagement")],
                list(class = d$class), function(x) round(mean(x, na.rm = TRUE), 2))
write.csv(cm, file.path(tab, "T10e_lca_class_means.csv"), row.names = FALSE)
write.csv(d[, c("resp_id", "country", "class", "class_post")], file.path(tab, "T10f_lca_assignments.csv"), row.names = FALSE)
print(fs); print(comp); print(cm)
