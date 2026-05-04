#!/usr/bin/env bash
# QIIME 2 + DADA2 paired-end COI metabarcoding pipeline used for the QBS-DNA study.
# This script documents the processing settings reported in the manuscript.

set -euo pipefail

# ---- User settings ----
MANIFEST_FILE="manifest.tsv"       # QIIME 2 paired-end manifest file
OUT_DIR="output/qiime2"            # all QIIME 2 outputs
THREADS=1

# DADA2 parameters used for the manuscript analyses
TRIM_LEFT_F=20
TRIM_LEFT_R=20
TRUNC_LEN_F=230
TRUNC_LEN_R=180
MAX_EE_F=2
MAX_EE_R=2
TRUNC_Q=2
MIN_OVERLAP=12
CHIMERA_METHOD="consensus"
POOLING_METHOD="independent"
# -----------------------

mkdir -p "$OUT_DIR"
EXPORT_DIR="$OUT_DIR/exported"
mkdir -p "$EXPORT_DIR"

[[ -s "$MANIFEST_FILE" ]] || {
  echo "ERROR: manifest file not found or empty: $MANIFEST_FILE" >&2
  exit 1
}

# 1) Import demultiplexed paired-end reads using a manifest file.
qiime tools import \
  --type 'SampleData[PairedEndSequencesWithQuality]' \
  --input-path "$MANIFEST_FILE" \
  --input-format PairedEndFastqManifestPhred33V2 \
  --output-path "$OUT_DIR/paired-end-demux.qza"

# 2) Summarize sequence quality profiles to document trimming/truncation choices.
qiime demux summarize \
  --i-data "$OUT_DIR/paired-end-demux.qza" \
  --o-visualization "$OUT_DIR/paired-end-demux.qzv"

# 3) DADA2 denoising, paired-end merging, chimera removal, and dereplication.
qiime dada2 denoise-paired \
  --i-demultiplexed-seqs "$OUT_DIR/paired-end-demux.qza" \
  --p-trim-left-f "$TRIM_LEFT_F" \
  --p-trim-left-r "$TRIM_LEFT_R" \
  --p-trunc-len-f "$TRUNC_LEN_F" \
  --p-trunc-len-r "$TRUNC_LEN_R" \
  --p-max-ee-f "$MAX_EE_F" \
  --p-max-ee-r "$MAX_EE_R" \
  --p-trunc-q "$TRUNC_Q" \
  --p-min-overlap "$MIN_OVERLAP" \
  --p-chimera-method "$CHIMERA_METHOD" \
  --p-pooling-method "$POOLING_METHOD" \
  --p-n-threads "$THREADS" \
  --o-table "$OUT_DIR/COI-table.qza" \
  --o-representative-sequences "$OUT_DIR/COI-rep-seqs.qza" \
  --o-denoising-stats "$OUT_DIR/COI-denoising-stats.qza" \
  --verbose

qiime metadata tabulate \
  --m-input-file "$OUT_DIR/COI-denoising-stats.qza" \
  --o-visualization "$OUT_DIR/COI-denoising-stats.qzv"

# 4) Export feature table and representative sequences.
qiime tools export --input-path "$OUT_DIR/COI-table.qza" --output-path "$EXPORT_DIR"
qiime tools export --input-path "$OUT_DIR/COI-rep-seqs.qza" --output-path "$EXPORT_DIR"

# 5) Convert BIOM feature table to TSV.
biom convert \
  -i "$EXPORT_DIR/feature-table.biom" \
  -o "$EXPORT_DIR/feature-table.tsv" \
  --to-tsv --table-type="OTU table"

echo "Done. Outputs in $EXPORT_DIR"
