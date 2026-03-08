#!/usr/bin/env Rscript
# Core DNA statistical analyses (no plotting).
# Computes alpha-diversity metrics and tests differences by System/Treatment,
# plus beta-diversity PERMANOVA and dispersion checks.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(vegan)
  library(car)
  library(rstatix)
  library(readr)
})

# ---- Inputs ----
asv_path <- "data/asv_table_filtered.tsv"
meta_path <- "data/sample_metadata_filtered.tsv"

# ---- Outputs ----
out_dir <- "analysis_outputs"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# ---- Load data ----
asv <- read_tsv(asv_path, show_col_types = FALSE)
meta <- read_tsv(meta_path, show_col_types = FALSE)

# First column is SampleID
sample_ids <- asv[[1]]
asv <- asv[,-1]
asv <- as.data.frame(asv)
rownames(asv) <- sample_ids

# Ensure numeric
asv[] <- lapply(asv, function(x) as.numeric(x))
asv[is.na(asv)] <- 0

# Align metadata order
meta <- meta %>% filter(SampleID %in% rownames(asv))
meta <- meta %>% mutate(SampleID = factor(SampleID, levels = rownames(asv))) %>% arrange(SampleID)

# ---- Alpha diversity ----
richness <- rowSums(asv > 0)
shannon <- diversity(asv, index = "shannon")
# Evenness: Shannon / log(richness)
shannon_evenness <- shannon / log(richness)
# Dominance: 1 - Simpson
dominance <- 1 - diversity(asv, index = "simpson")

alpha <- tibble(
  SampleID = rownames(asv),
  Richness = richness,
  Shannon = shannon,
  Evenness = shannon_evenness,
  Dominance = dominance
) %>%
  left_join(meta, by = "SampleID")

write_csv(alpha, file.path(out_dir, "alpha_diversity_metrics.csv"))

# ---- Statistical tests ----
run_omnibus <- function(df, response, group_var) {
  f <- as.formula(paste(response, "~", group_var))

  # Normality (Shapiro) on residuals
  lm_fit <- lm(f, data = df)
  shapiro_p <- tryCatch(shapiro.test(residuals(lm_fit))$p.value, error = function(e) NA)

  # Homogeneity of variance (Levene)
  levene_p <- tryCatch(car::leveneTest(f, data = df)$`Pr(>F)`[1], error = function(e) NA)

  use_anova <- !is.na(shapiro_p) && !is.na(levene_p) && shapiro_p > 0.05 && levene_p > 0.05

  if (use_anova) {
    aov_fit <- aov(f, data = df)
    omnibus <- summary(aov_fit)[[1]]
    omni_row <- tibble(
      method = "ANOVA",
      response = response,
      group = group_var,
      p_value = omnibus$`Pr(>F)`[1]
    )
    posthoc <- TukeyHSD(aov_fit)[[1]] %>%
      as.data.frame() %>%
      tibble::rownames_to_column("comparison") %>%
      mutate(method = "TukeyHSD", response = response, group = group_var)
  } else {
    kw <- kruskal.test(f, data = df)
    omni_row <- tibble(
      method = "Kruskal-Wallis",
      response = response,
      group = group_var,
      p_value = kw$p.value
    )
    # Dunn test with Holm correction
    posthoc <- rstatix::dunn_test(df, formula = f, p.adjust.method = "holm") %>%
      mutate(method = "Dunn", response = response, group = group_var)
  }

  list(omnibus = omni_row, posthoc = posthoc,
       shapiro_p = shapiro_p, levene_p = levene_p, use_anova = use_anova)
}

metrics <- c("Richness","Shannon","Evenness","Dominance")

omni_rows <- list()
posthoc_rows <- list()
assumption_rows <- list()

for (m in metrics) {
  for (grp in c("System","Treatment")) {
    res <- run_omnibus(alpha, m, grp)
    omni_rows[[length(omni_rows)+1]] <- res$omnibus
    posthoc_rows[[length(posthoc_rows)+1]] <- res$posthoc
    assumption_rows[[length(assumption_rows)+1]] <- tibble(
      response = m, group = grp,
      shapiro_p = res$shapiro_p,
      levene_p = res$levene_p,
      use_anova = res$use_anova
    )
  }
}

# Within-system treatment tests
within_rows <- list()
within_posthoc <- list()
for (m in metrics) {
  for (sys in unique(alpha$System)) {
    df_sys <- alpha %>% filter(System == sys)
    if (n_distinct(df_sys$Treatment) < 2) next
    res <- run_omnibus(df_sys, m, "Treatment")
    within_rows[[length(within_rows)+1]] <- res$omnibus %>% mutate(System = sys)
    within_posthoc[[length(within_posthoc)+1]] <- res$posthoc %>% mutate(System = sys)
  }
}

omni_tbl <- bind_rows(omni_rows)
posthoc_tbl <- bind_rows(posthoc_rows)
assump_tbl <- bind_rows(assumption_rows)
within_tbl <- bind_rows(within_rows)
within_post <- bind_rows(within_posthoc)

write_csv(omni_tbl, file.path(out_dir, "alpha_omnibus_tests.csv"))
write_csv(posthoc_tbl, file.path(out_dir, "alpha_posthoc_tests.csv"))
write_csv(assump_tbl, file.path(out_dir, "alpha_assumption_checks.csv"))
write_csv(within_tbl, file.path(out_dir, "alpha_within_system_tests.csv"))
write_csv(within_post, file.path(out_dir, "alpha_within_system_posthoc.csv"))

# ---- Beta diversity (Bray-Curtis) ----
# Distance matrix
bray <- vegdist(asv, method = "bray")

# PERMANOVA
permanova <- adonis2(bray ~ System * Treatment, data = meta, permutations = 999)

# Dispersion (betadisper)
# Test dispersion by System and Treatment
bd_system <- betadisper(bray, meta$System)
bd_treatment <- betadisper(bray, meta$Treatment)

permanova_df <- as.data.frame(permanova)
write_csv(permanova_df, file.path(out_dir, "beta_permanova.csv"))

# Dispersion ANOVA tables
bd_sys_aov <- anova(bd_system)
bd_trt_aov <- anova(bd_treatment)

write_csv(as.data.frame(bd_sys_aov), file.path(out_dir, "beta_betadisper_system.csv"))
write_csv(as.data.frame(bd_trt_aov), file.path(out_dir, "beta_betadisper_treatment.csv"))

message("Analysis complete. Outputs in ", out_dir)
