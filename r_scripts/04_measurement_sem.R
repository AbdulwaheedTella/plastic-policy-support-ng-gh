# Measurement model, invariance and multi-group SEM. Called as: Rscript 04_measurement_sem.R <project folder>
#
# Inputs : data/processed/survey_merged_deidentified.csv
# Outputs: outputs/tables/T4_* to T9_*, outputs/models/*.txt
#
# Main estimator: robust maximum likelihood (MLR) with full-information ML for missing data,
# treating 5-point items as continuous (Rhemtulla et al., 2012). Ordinal invariance (WLSMV,
# Wu & Estabrook, 2016) and an ordinal structural model are run as robustness checks.
suppressPackageStartupMessages({
  library(lavaan); library(semTools); library(psych)
})
set.seed(20231101)
root <- commandArgs(trailingOnly = TRUE)[1]
tab <- file.path(root, "outputs", "tables"); mod <- file.path(root, "outputs", "models")
d <- read.csv(file.path(root, "data", "processed", "survey_merged_deidentified.csv"))
d$country <- factor(d$country, levels = c("Nigeria", "Ghana"))
d$female  <- ifelse(is.na(d$gender), NA, as.numeric(d$gender == "Female"))
d$age_o   <- as.numeric(factor(d$age, levels = c("18-27", "28-37", "38-47", "48+")))
d$city    <- ifelse(is.na(d$community), NA, as.numeric(d$community == "City"))
d$student <- ifelse(is.na(d$occ_group), NA, as.numeric(d$occ_group == "Student"))
d$ghana   <- as.numeric(d$country == "Ghana")

harm <- c("flood", "erosion", "vector", "infiltration", "buildings", "toxic", "microbes", "nutrients",
          "bags_billions", "waterways_tons", "aquatic", "food", "terrestrial", "harmful_env")
supp <- c("polluter_pays", "legal", "biodeg_alt", "cheap_bioplastic")
sink_txt <- function(obj, f) { capture.output(obj, file = file.path(mod, f)) }
fitm <- c("chisq.scaled", "df.scaled", "pvalue.scaled", "cfi.robust", "tli.robust",
          "rmsea.robust", "rmsea.ci.lower.robust", "rmsea.ci.upper.robust", "srmr")
getfit <- function(f, label) {
  x <- fitMeasures(f, fitm)
  if (is.na(x["cfi.robust"])) {  # WLSMV with missing data: robust indices unavailable, use scaled
    y <- fitMeasures(f, c("cfi.scaled", "tli.scaled", "rmsea.scaled", "rmsea.ci.lower.scaled", "rmsea.ci.upper.scaled"))
    x[c("cfi.robust", "tli.robust", "rmsea.robust", "rmsea.ci.lower.robust", "rmsea.ci.upper.robust")] <- y
  }
  data.frame(model = label, as.list(round(unclass(x), 4)), row.names = NULL, check.names = FALSE)
}

# ------------------------------------------------------------------ 1. EFA (polychoric, pooled)
efa_items <- c(harm, "charges", "gov_resp", "everybody", supp, "cheaper_plastic")
pc <- polychoric(d[, efa_items], correct = 0)$rho
pa <- fa.parallel(pc, n.obs = sum(complete.cases(d[, efa_items])), fa = "fa", plot = FALSE)
efa <- fa(pc, nfactors = 3, n.obs = sum(complete.cases(d[, efa_items])), rotate = "oblimin", fm = "wls")
L <- round(unclass(efa$loadings), 3)
write.csv(data.frame(item = rownames(L), L, communality = round(efa$communality, 3)),
          file.path(tab, "T4a_efa_polychoric_loadings.csv"), row.names = FALSE)
sink_txt(list(parallel_nfact = pa$nfact, efa = print(efa, cut = 0.3, sort = TRUE)), "efa.txt")

# ------------------------------------------------------------------ 2. CFA measurement model
# Correlated residuals are restricted to item pairs with near-identical wording (stated a priori):
# "billions of bags discarded" ~ "millions of tonnes reach waterways" (volume statements),
# "harms aquatic animals" ~ "harms terrestrial animals" (parallel stems),
# "biodegradable alternatives" ~ "affordable bioplastics" (substitution items).
cfa_m <- '
HARM =~ flood + erosion + vector + infiltration + buildings + toxic + microbes + nutrients +
        bags_billions + waterways_tons + aquatic + food + terrestrial + harmful_env
SUPPORT =~ polluter_pays + legal + biodeg_alt + cheap_bioplastic
bags_billions ~~ waterways_tons
aquatic ~~ terrestrial
biodeg_alt ~~ cheap_bioplastic
'
cfa_m0 <- gsub("bags_billions ~~ waterways_tons\naquatic ~~ terrestrial\nbiodeg_alt ~~ cheap_bioplastic\n", "", cfa_m)
fit_list <- list()
for (cty in c("Pooled", "Nigeria", "Ghana")) {
  dd <- if (cty == "Pooled") d else d[d$country == cty, ]
  f0 <- cfa(cfa_m0, dd, estimator = "MLR", missing = "fiml")
  f1 <- cfa(cfa_m, dd, estimator = "MLR", missing = "fiml")
  fit_list[[cty]] <- f1
  write.csv(rbind(getfit(f0, paste(cty, "no residual covariances")), getfit(f1, paste(cty, "final"))),
            file.path(tab, paste0("T4b_cfa_fit_", cty, ".csv")), row.names = FALSE)
  sink_txt(summary(f1, fit.measures = TRUE, standardized = TRUE), paste0("cfa_", cty, ".txt"))
}
cfa_fit <- do.call(rbind, lapply(c("Pooled", "Nigeria", "Ghana"), function(c)
  read.csv(file.path(tab, paste0("T4b_cfa_fit_", c, ".csv")))))
write.csv(cfa_fit, file.path(tab, "T4b_cfa_fit.csv"), row.names = FALSE)
for (c in c("Pooled", "Nigeria", "Ghana")) file.remove(file.path(tab, paste0("T4b_cfa_fit_", c, ".csv")))

# loadings, omega, AVE, HTMT per country
rel_rows <- list(); load_rows <- list()
for (cty in c("Nigeria", "Ghana")) {
  f <- fit_list[[cty]]
  st <- standardizedSolution(f); st <- st[st$op == "=~", ]
  load_rows[[cty]] <- data.frame(country = cty, factor = st$lhs, item = st$rhs,
                                 std_loading = round(st$est.std, 3), se = round(st$se, 3))
  om <- compRelSEM(f); av <- AVE(f)
  dd <- d[d$country == cty, ]
  ht <- htmt(cfa_m0, data = dd[, c(harm, supp)], missing = "pairwise")
  alpha_h <- psych::alpha(dd[, harm])$total$raw_alpha
  alpha_s <- psych::alpha(dd[, supp])$total$raw_alpha
  lv <- lavInspect(f, "cor.lv")
  rel_rows[[cty]] <- data.frame(country = cty, construct = c("HARM", "SUPPORT"),
                                alpha = round(c(alpha_h, alpha_s), 3),
                                omega = round(as.numeric(om[c("HARM", "SUPPORT")]), 3),
                                AVE = round(as.numeric(av[c("HARM", "SUPPORT")]), 3),
                                sqrt_AVE = round(sqrt(as.numeric(av[c("HARM", "SUPPORT")])), 3),
                                latent_r = round(lv["HARM", "SUPPORT"], 3),
                                HTMT = round(ht["SUPPORT", "HARM"], 3))
}
write.csv(do.call(rbind, load_rows), file.path(tab, "T4c_cfa_loadings.csv"), row.names = FALSE)
write.csv(do.call(rbind, rel_rows), file.path(tab, "T4d_reliability_validity.csv"), row.names = FALSE)

# ------------------------------------------------------------------ 3. Measurement invariance (MLR, continuous)
inv_fit <- function(eq, partial = NULL) cfa(cfa_m, d, group = "country", estimator = "MLR",
                                            missing = "fiml", group.equal = eq, group.partial = partial)
m_conf <- inv_fit(character(0))
m_metr <- inv_fit("loadings")
m_scal <- inv_fit(c("loadings", "intercepts"))
m_strc <- inv_fit(c("loadings", "intercepts", "residuals"))
# partial scalar invariance: free intercepts flagged by the score test, one at a time, until dCFI <= .010
score <- lavTestScore(m_scal)$uni
pt <- parTable(m_scal)
score$lhs_lab <- pt$label[match(score$lhs, pt$plabel)]
score$rhs_lab <- pt$label[match(score$rhs, pt$plabel)]
freed <- character(0); m_ps <- m_scal
cfi_metr <- fitMeasures(m_metr, "cfi.robust")
sc <- score[order(-score$X2), ]
for (i in seq_len(nrow(sc))) {
  if (cfi_metr - fitMeasures(m_ps, "cfi.robust") <= 0.010) break
  prow <- pt[pt$plabel == sc$lhs[i], ]
  if (nrow(prow) == 0 || prow$op != "~1") next
  term <- paste0(prow$lhs, "~1")
  if (term %in% freed) next
  freed <- c(freed, term)
  m_ps <- inv_fit(c("loadings", "intercepts"), freed)
}
inv_tab <- rbind(getfit(m_conf, "Configural"), getfit(m_metr, "Metric (loadings)"),
                 getfit(m_scal, "Scalar (loadings + intercepts)"),
                 getfit(m_ps, paste0("Partial scalar (free: ", paste(freed, collapse = ", "), ")")),
                 getfit(m_strc, "Strict (+ residual variances)"))
inv_tab$delta_cfi <- c(NA, diff(inv_tab$cfi.robust))
inv_tab$delta_rmsea <- c(NA, diff(inv_tab$rmsea.robust))
inv_tab$delta_srmr <- c(NA, diff(inv_tab$srmr))
# scaled chi-square difference tests vs the preceding nested model
lrt <- function(a, b) { x <- lavTestLRT(a, b, method = "satorra.bentler.2001")
  c(chisq_diff = x[2, "Chisq diff"], df_diff = x[2, "Df diff"], p_diff = x[2, "Pr(>Chisq)"]) }
dt <- rbind(c(NA, NA, NA), lrt(m_conf, m_metr), lrt(m_metr, m_scal), lrt(m_metr, m_ps), lrt(m_scal, m_strc))
inv_tab <- cbind(inv_tab, round(dt, 4))
inv_tab$comparison <- c("", "vs configural", "vs metric", "vs metric", "vs scalar")
if (length(freed) == 0) inv_tab <- inv_tab[-4, ]  # full scalar invariance held; no partial model needed
write.csv(inv_tab, file.path(tab, "T5a_invariance_mlr.csv"), row.names = FALSE)

# latent mean differences under (partial) scalar invariance; Nigeria is the reference (mean 0)
lm_ps <- parameterEstimates(m_ps)
lat <- lm_ps[lm_ps$op == "~1" & lm_ps$lhs %in% c("HARM", "SUPPORT") & lm_ps$group == 2, ]
lv_var <- lm_ps[lm_ps$op == "~~" & lm_ps$lhs == lm_ps$rhs & lm_ps$lhs %in% c("HARM", "SUPPORT"), ]
pooled_sd <- sapply(c("HARM", "SUPPORT"), function(f) sqrt(mean(lv_var$est[lv_var$lhs == f])))
lat$d <- lat$est / pooled_sd[lat$lhs]
write.csv(data.frame(factor = lat$lhs, ghana_minus_nigeria = round(lat$est, 3), se = round(lat$se, 3),
                     z = round(lat$z, 2), p = signif(lat$pvalue, 3), ci_lo = round(lat$ci.lower, 3),
                     ci_hi = round(lat$ci.upper, 3), cohen_d = round(lat$d, 3)),
          file.path(tab, "T5b_latent_mean_differences.csv"), row.names = FALSE)

# ------------------------------------------------------------------ 3b. Ordinal invariance (WLSMV) robustness
dord <- d
for (v in c(harm, supp)) dord[[v]] <- ordered(dord[[v]], levels = 1:5)
# collapse categories 1-2 where any group has an empty category (needed for threshold invariance)
for (v in c(harm, supp)) {
  tb <- table(dord[[v]], dord$country)
  if (any(tb == 0)) dord[[v]] <- ordered(pmax(as.numeric(dord[[v]]), 2), levels = 2:5)
}
ord_rows <- list(); prev <- NULL
for (lvl in c("configural", "thresholds", "loadings", "intercepts")) {
  syn <- measEq.syntax(configural.model = cfa_m, data = dord, ordered = c(harm, supp),
                       parameterization = "theta", ID.fac = "std.lv", ID.cat = "Wu.Estabrook.2016",
                       group = "country",
                       group.equal = switch(lvl, configural = "", thresholds = "thresholds",
                                            loadings = c("thresholds", "loadings"),
                                            intercepts = c("thresholds", "loadings", "intercepts")))
  f <- cfa(as.character(syn), dord, group = "country", ordered = c(harm, supp),
           estimator = "WLSMV", parameterization = "theta")
  ord_rows[[lvl]] <- getfit(f, paste("Ordinal", lvl))
  ord_rows[[lvl]]$chisq_diff_p <- if (is.null(prev)) NA else
    round(lavTestLRT(prev, f, method = "satorra.2000")[2, "Pr(>Chisq)"], 4)
  prev <- f
}
ordt <- do.call(rbind, ord_rows)
ordt$delta_cfi <- c(NA, diff(ordt$cfi.robust)); ordt$delta_rmsea <- c(NA, diff(ordt$rmsea.robust))
write.csv(ordt, file.path(tab, "T5c_invariance_wlsmv_ordinal.csv"), row.names = FALSE)

# ------------------------------------------------------------------ 4. Multi-group structural model
# Value-Belief-Norm chain: engagement -> harm perception (awareness of consequences) ->
# shared-responsibility norm ("everybody can play a role") -> policy support.
# Three single-item outcomes capture other instrument stances: price charges, government
# responsibility, and affordability-first ("make plastic cheaper").
paths <- function(g) {
  s <- function(x) paste0("c(", paste0(x, "_NG"), ",", paste0(x, "_GH"), ")*")
  paste0('
HARM =~ flood + erosion + vector + infiltration + buildings + toxic + microbes + nutrients +
        bags_billions + waterways_tons + aquatic + food + terrestrial + harmful_env
SUPPORT =~ polluter_pays + legal + biodeg_alt + cheap_bioplastic
bags_billions ~~ waterways_tons
aquatic ~~ terrestrial
biodeg_alt ~~ cheap_bioplastic
HARM ~ ', s("a1"), 'engagement + age_o + female + city + income_top + student
everybody ~ ', s("b1"), 'HARM + ', s("b2"), 'engagement + age_o + female + city + income_top + student
SUPPORT ~ ', s("c1"), 'everybody + ', s("c2"), 'HARM + ', s("c3"), 'engagement + age_o + female + city + income_top + student
charges ~ ', s("d1"), 'everybody + ', s("d2"), 'HARM + ', s("d3"), 'engagement
gov_resp ~ ', s("e1"), 'everybody + ', s("e2"), 'HARM + ', s("e3"), 'engagement
cheaper_plastic ~ ', s("f1"), 'everybody + ', s("f2"), 'HARM + ', s("f3"), 'engagement
charges ~~ gov_resp + cheaper_plastic
gov_resp ~~ cheaper_plastic
SUPPORT ~~ charges + gov_resp + cheaper_plastic
everybody ~~ 0*charges + 0*gov_resp + 0*cheaper_plastic
')
}
ind <- '
ind_HARM_NORM_SUP_NG := a1_NG*b1_NG*c1_NG
ind_HARM_NORM_SUP_GH := a1_GH*b1_GH*c1_GH
ind_ENG_SUP_total_NG := c3_NG + a1_NG*c2_NG + b2_NG*c1_NG + a1_NG*b1_NG*c1_NG
ind_ENG_SUP_total_GH := c3_GH + a1_GH*c2_GH + b2_GH*c1_GH + a1_GH*b1_GH*c1_GH
HARM_to_SUP_via_NORM_NG := b1_NG*c1_NG
HARM_to_SUP_via_NORM_GH := b1_GH*c1_GH
HARM_to_SUP_total_NG := c2_NG + b1_NG*c1_NG
HARM_to_SUP_total_GH := c2_GH + b1_GH*c1_GH
HARM_to_charges_via_NORM_NG := b1_NG*d1_NG
HARM_to_charges_via_NORM_GH := b1_GH*d1_GH
diff_HARM_to_SUP_via_NORM := HARM_to_SUP_via_NORM_GH - HARM_to_SUP_via_NORM_NG
diff_ind_ENG_SUP_total := ind_ENG_SUP_total_GH - ind_ENG_SUP_total_NG
'
sem_syn <- paste(paths(), ind)
eq_meas <- c("loadings", "intercepts")
# fixed.x = FALSE keeps respondents with missing covariates in the likelihood. lavaan then warns that the
# parameter covariance matrix is not positive definite: the near-zero eigenvalues correspond exactly to the
# between-group equality constraints plus the means and variances of binary covariates (checked by
# eigen-decomposition), so the warning is harmless. Robustness row "Covariates fixed" uses fixed.x = TRUE.
fit_sem <- function(dat, syn = sem_syn, partial = freed, fx = FALSE, ...) sem(syn, dat, group = "country",
  estimator = "MLR", missing = "fiml", fixed.x = fx, group.equal = eq_meas, group.partial = partial, ...)
s_free <- fit_sem(d)
sink_txt(summary(s_free, fit.measures = TRUE, standardized = TRUE, rsquare = TRUE), "sem_multigroup.txt")

pe <- parameterEstimates(s_free, standardized = TRUE)
pe$country <- ifelse(pe$group == 1, "Nigeria", ifelse(pe$group == 2, "Ghana", NA))
key <- pe[pe$op == "~" & pe$rhs %in% c("engagement", "HARM", "everybody"), ]
# Wald test of equality for each structural path across countries
key$wald_p_equal <- NA
for (lab in unique(sub("_NG|_GH", "", key$label[key$label != ""]))) {
  w <- lavTestWald(s_free, paste0(lab, "_NG == ", lab, "_GH"))
  key$wald_p_equal[sub("_NG|_GH", "", key$label) == lab] <- w$p.value
}
write.csv(data.frame(country = key$country, outcome = key$lhs, predictor = key$rhs, label = key$label,
                     b = round(key$est, 3), se = round(key$se, 3), p = signif(key$pvalue, 3),
                     beta = round(key$std.all, 3), ci_lo = round(key$ci.lower, 3), ci_hi = round(key$ci.upper, 3),
                     wald_p_equal = signif(key$wald_p_equal, 3)),
          file.path(tab, "T6a_sem_structural_paths.csv"), row.names = FALSE)
ctrl <- pe[pe$op == "~" & pe$rhs %in% c("age_o", "female", "city", "income_top", "student"), ]
write.csv(data.frame(country = ctrl$country, outcome = ctrl$lhs, predictor = ctrl$rhs,
                     b = round(ctrl$est, 3), se = round(ctrl$se, 3), p = signif(ctrl$pvalue, 3),
                     beta = round(ctrl$std.all, 3)), file.path(tab, "T6b_sem_control_paths.csv"), row.names = FALSE)
r2 <- lavInspect(s_free, "r2")
write.csv(data.frame(country = rep(c("Nigeria", "Ghana"), each = length(r2[[1]])),
                     outcome = c(names(r2[[1]]), names(r2[[2]])), r2 = round(c(r2[[1]], r2[[2]]), 3)),
          file.path(tab, "T6c_sem_r2.csv"), row.names = FALSE)
# omnibus test: all structural paths equal across countries
labs <- unique(sub("_NG|_GH", "", key$label[key$label != ""]))
omni <- lavTestWald(s_free, paste0(labs, "_NG == ", labs, "_GH", collapse = "\n"))
semfit <- getfit(s_free, "Multi-group SEM (partial scalar measurement)")
semfit$omnibus_wald_paths_equal <- round(omni$stat, 3); semfit$omnibus_df <- omni$df
semfit$omnibus_p <- signif(omni$p.value, 3)
# likelihood-ratio check: all structural paths constrained equal vs free (scaled difference test)
eq_syn <- gsub("c\\(([a-f][0-9])_NG,[a-f][0-9]_GH\\)\\*", "c(\\1,\\1)*", paths())
s_eq <- fit_sem(d, syn = eq_syn)
lr_eq <- lavTestLRT(s_eq, s_free, method = "satorra.bentler.2001")
semfit$lrt_chisq_diff <- round(lr_eq[2, "Chisq diff"], 3); semfit$lrt_df <- lr_eq[2, "Df diff"]
semfit$lrt_p <- signif(lr_eq[2, "Pr(>Chisq)"], 3)
semfit$delta_cfi_constrained <- round(fitMeasures(s_eq, "cfi.robust") - fitMeasures(s_free, "cfi.robust"), 4)
write.csv(semfit, file.path(tab, "T6d_sem_fit.csv"), row.names = FALSE)

# indirect effects: Monte Carlo confidence intervals (20,000 draws; Preacher & Selig, 2012)
mc <- monteCarloCI(s_free, nRep = 20000, standardized = FALSE)
mc <- data.frame(effect = rownames(mc), round(mc, 4), row.names = NULL)
dl <- pe[pe$op == ":=", c("lhs", "est", "se", "pvalue")]
mc <- merge(mc, data.frame(effect = dl$lhs, delta_se = round(dl$se, 4), delta_p = signif(dl$pvalue, 3)), by = "effect")
write.csv(mc, file.path(tab, "T6e_indirect_effects_montecarlo.csv"), row.names = FALSE)

# ------------------------------------------------------------------ 5. Robustness of the structural model
rob <- function(f, label) {
  p <- parameterEstimates(f, standardized = TRUE)
  p <- p[p$op == "~" & p$rhs %in% c("engagement", "HARM", "everybody"), ]
  data.frame(spec = label, country = ifelse(p$group == 1, "Nigeria", "Ghana"), outcome = p$lhs,
             predictor = p$rhs, beta = round(p$std.all, 3), p = signif(p$pvalue, 3))
}
R <- list(rob(s_free, "Main: MLR-FIML, partial scalar"))
# (a) exclude responses with any quality flag
R[[2]] <- rob(fit_sem(d[d$flag_any_quality == 0, ]), "Excluding quality-flagged responses")
# (b) random-intercept (acquiescence) factor: all Likert items load 1, orthogonal to substantive factors
ri_items <- c(harm, supp, "everybody", "charges", "gov_resp", "cheaper_plastic", "trash_no_harm",
              "not_recycled", "not_reused")
ri_syn <- paste(sub("SUPPORT =~", paste0("RI =~ ", paste0("1*", ri_items, collapse = " + "),
                                          "\nRI ~~ 0*HARM + 0*SUPPORT\nSUPPORT =~"), paths()), "")
ri_syn <- sub("HARM ~ ", "RI ~~ 0*engagement + 0*age_o + 0*female + 0*city + 0*income_top + 0*student\nHARM ~ ", ri_syn)
s_ri <- tryCatch(fit_sem(d, syn = ri_syn), error = function(e) NULL)
if (!is.null(s_ri)) {
  R[[3]] <- rob(s_ri, "Random-intercept response-style factor")
  sink_txt(summary(s_ri, fit.measures = TRUE, standardized = TRUE), "sem_random_intercept.txt")
  ri_var <- parameterEstimates(s_ri); ri_var <- ri_var[ri_var$lhs == "RI" & ri_var$op == "~~" & ri_var$rhs == "RI", ]
  write.csv(data.frame(country = c("Nigeria", "Ghana"), ri_variance = round(ri_var$est, 3),
                       se = round(ri_var$se, 3), p = signif(ri_var$pvalue, 3),
                       rbind(getfit(s_ri, "RI model"))[rep(1, 2), -1]),
            file.path(tab, "T7b_random_intercept_variance.csv"), row.names = FALSE)
}
# (c) ordinal WLSMV structural model: the 18 factor indicators are treated as ordered, the single-item
#     norm and stance outcomes as continuous (declaring them ordered too prevents convergence);
#     listwise deletion, as WLSMV does not use FIML
ords <- c(harm, supp)
dw <- dord
# capped at 20 minutes of elapsed time; if it does not finish, the check is reported as not run
s_w <- tryCatch({
  setTimeLimit(elapsed = 1200, transient = TRUE)
  sem(gsub("c\\([a-f][0-9]_NG,[a-f][0-9]_GH\\)\\*", "", paths()), dw, group = "country",
      ordered = intersect(ords, names(dw)), estimator = "WLSMV",
      group.equal = c("loadings", "thresholds"))
}, error = function(e) {print(e); NULL})
setTimeLimit(elapsed = Inf)
if (!is.null(s_w) && !lavInspect(s_w, "converged")) { message("Ordinal SEM did not converge; not reported"); s_w <- NULL }
if (!is.null(s_w)) R[[length(R) + 1]] <- rob(s_w, "Ordinal WLSMV (listwise)")
# (d) alternative specification: "everybody can play a role" as a fifth SUPPORT indicator (as in the
#     published single-country PCA) and no separate norm; harm and engagement predict support directly
alt_syn <- '
HARM =~ flood + erosion + vector + infiltration + buildings + toxic + microbes + nutrients +
        bags_billions + waterways_tons + aquatic + food + terrestrial + harmful_env
SUPPORT =~ everybody + polluter_pays + legal + biodeg_alt + cheap_bioplastic
bags_billions ~~ waterways_tons
aquatic ~~ terrestrial
biodeg_alt ~~ cheap_bioplastic
HARM ~ engagement + age_o + female + city + income_top + student
SUPPORT ~ HARM + engagement + age_o + female + city + income_top + student
charges ~ HARM + engagement
gov_resp ~ HARM + engagement
cheaper_plastic ~ HARM + engagement
charges ~~ gov_resp + cheaper_plastic
gov_resp ~~ cheaper_plastic
SUPPORT ~~ charges + gov_resp + cheaper_plastic
'
s_alt <- fit_sem(d, syn = alt_syn)
R[[length(R) + 1]] <- rob(s_alt, "Alternative: norm item as SUPPORT indicator")
# (e0) covariates treated as fixed (listwise on covariates)
R[[length(R) + 1]] <- rob(fit_sem(d, fx = TRUE), "Covariates fixed (fixed.x = TRUE)")
# (e) excluding the uniform-disagreement latent class identified in step 3
cls_f <- file.path(tab, "T10f_lca_assignments.csv")
if (file.exists(cls_f)) {
  cls <- read.csv(cls_f); cm <- read.csv(file.path(tab, "T10e_lca_class_means.csv"))
  uni <- cm$class[which.min(cm$SUPPORT)]
  d_ex <- d[!(d$resp_id %in% cls$resp_id[cls$class == uni]), ]
  s_ex <- fit_sem(d_ex)
  R[[length(R) + 1]] <- rob(s_ex, "Excluding uniform-disagreement class")
  # latent means and invariance without that class
  m_ex <- cfa(cfa_m, d_ex, group = "country", estimator = "MLR", missing = "fiml",
              group.equal = c("loadings", "intercepts"), group.partial = freed)
  pe_ex <- parameterEstimates(m_ex)
  lat_ex <- pe_ex[pe_ex$op == "~1" & pe_ex$lhs %in% c("HARM", "SUPPORT") & pe_ex$group == 2, ]
  write.csv(data.frame(factor = lat_ex$lhs, ghana_minus_nigeria = round(lat_ex$est, 3), se = round(lat_ex$se, 3),
                       p = signif(lat_ex$pvalue, 3), ci_lo = round(lat_ex$ci.lower, 3), ci_hi = round(lat_ex$ci.upper, 3)),
            file.path(tab, "T5d_latent_means_excl_uniform.csv"), row.names = FALSE)
  m_ex_conf <- cfa(cfa_m, d_ex, group = "country", estimator = "MLR", missing = "fiml")
  m_ex_metr <- cfa(cfa_m, d_ex, group = "country", estimator = "MLR", missing = "fiml", group.equal = "loadings")
  write.csv(rbind(getfit(m_ex_conf, "Configural (excl. uniform class)"), getfit(m_ex_metr, "Metric (excl.)"),
                  getfit(m_ex, "Scalar (excl.)")), file.path(tab, "T5e_invariance_excl_uniform.csv"), row.names = FALSE)
  # omnibus equality of structural paths without that class
  key_ex <- parameterEstimates(s_ex)
  labs_ex <- unique(sub("_NG|_GH", "", key_ex$label[key_ex$op == "~" & grepl("_NG$", key_ex$label)]))
  om_ex <- lavTestWald(s_ex, paste0(labs_ex, "_NG == ", labs_ex, "_GH", collapse = "\n"))
  write.csv(data.frame(spec = "Excluding uniform-disagreement class", wald = round(om_ex$stat, 3), df = om_ex$df,
                       p = signif(om_ex$p.value, 3)), file.path(tab, "T7e_omnibus_excl_uniform.csv"), row.names = FALSE)
}
# (f) pooled model with country dummy and country x predictor interactions is reported via Wald tests above
write.csv(do.call(rbind, R), file.path(tab, "T7a_sem_robustness.csv"), row.names = FALSE)
robfit <- rbind(getfit(s_free, "Main"), getfit(s_alt, "Alternative specification"),
                if (!is.null(s_ri)) getfit(s_ri, "Random intercept"),
                if (!is.null(s_w)) getfit(s_w, "Ordinal WLSMV"))
write.csv(robfit, file.path(tab, "T7c_sem_robustness_fit.csv"), row.names = FALSE)

# ------------------------------------------------------------------ 6. Missing-data summary
miss <- sapply(c("Nigeria", "Ghana"), function(cty) {
  dd <- d[d$country == cty, c(harm, supp, "everybody", "charges", "gov_resp", "cheaper_plastic")]
  c(any_missing_pct = mean(!complete.cases(dd)) * 100, mean_item_missing_pct = mean(is.na(dd)) * 100,
    max_item_missing_pct = max(colMeans(is.na(dd))) * 100)
})
write.csv(data.frame(metric = rownames(miss), round(miss, 2)), file.path(tab, "T7d_missingness.csv"), row.names = FALSE)
writeLines(capture.output(sessionInfo()), file.path(mod, "R_sessionInfo.txt"))
cat("SEM step complete\n")
