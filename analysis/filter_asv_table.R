#!/usr/bin/env Rscript
# Filter ASV table using study thresholds (strict or relaxed).
# Input table must be samples x ASVs (TSV with SampleID as first column).

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

args <- commandArgs(trailingOnly = TRUE)

# Defaults (strict filter used for main analyses)
input_path <- "data/asv_table_raw.tsv"
output_path <- "analysis_outputs/asv_table_filtered.tsv"
remove_singletons <- TRUE
min_total_abundance <- 10
min_relative_abundance <- 5e-5
min_sample_reads <- 100
min_richness <- 5

# Simple arg parser: --key=value
for (a in args) {
  if (!grepl("=", a)) next
  kv <- strsplit(sub("^--", "", a), "=", fixed = TRUE)[[1]]
  if (length(kv) != 2) next
  key <- kv[1]; val <- kv[2]
  if (key == "input") input_path <- val
  if (key == "output") output_path <- val
  if (key == "remove_singletons") remove_singletons <- tolower(val) %in% c("true","1","yes")
  if (key == "min_total_abundance") min_total_abundance <- as.numeric(val)
  if (key == "min_relative_abundance") min_relative_abundance <- as.numeric(val)
  if (key == "min_sample_reads") min_sample_reads <- as.numeric(val)
  if (key == "min_richness") min_richness <- as.numeric(val)
}

message("Reading ", input_path)
mat <- read_tsv(input_path, show_col_types = FALSE)

# First column is SampleID
sample_ids <- mat[[1]]
mat <- mat[,-1]
mat <- as.data.frame(mat)
rownames(mat) <- sample_ids

# Ensure numeric
mat[] <- lapply(mat, function(x) as.numeric(x))
mat[is.na(mat)] <- 0

# Filter samples by total reads
sample_reads <- rowSums(mat)
keep_samples <- sample_reads >= min_sample_reads

# Filter ASVs by abundance criteria
asv_totals <- colSums(mat)
keep_asv <- asv_totals >= min_total_abundance

if (remove_singletons) {
  asv_present <- colSums(mat > 0)
  keep_asv <- keep_asv & (asv_present > 1)
}

if (min_relative_abundance > 0) {
  rel_abund <- asv_totals / sum(asv_totals)
  keep_asv <- keep_asv & (rel_abund >= min_relative_abundance)
}

# Apply ASV filters
mat_f <- mat[, keep_asv, drop = FALSE]

# Filter samples by richness after ASV filtering
richness <- rowSums(mat_f > 0)
keep_samples <- keep_samples & (richness >= min_richness)
mat_f <- mat_f[keep_samples, , drop = FALSE]

# Write output
out_dir <- dirname(output_path)
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

out_df <- cbind(SampleID = rownames(mat_f), mat_f)
write_tsv(out_df, output_path)

message("Wrote ", output_path)
message("Samples kept: ", nrow(mat_f), "; ASVs kept: ", ncol(mat_f))
