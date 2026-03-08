#!/usr/bin/env bash
# QIIME 2 + DADA2 metabarcoding pipeline used for the QBS-DNA study.
# Processes raw Illumina reads to generate ASV tables and representative sequences.
# Steps:
# 1. Import reads
# 2. (Optional) Primer removal with cutadapt
# 3. DADA2 denoising (single-end or paired-end)
# 4. Export feature table and representative sequences
# 5. Filter representative sequences to ASVs in the final table

set -euo pipefail

# ---- User settings (edit as needed) ----
RAW_READS_DIR="raw_reads"          # folder with *_R1_001.fastq.gz and *_R2_001.fastq.gz
OUT_DIR="output/qiime2"            # all QIIME2 outputs
USE_SINGLE_END_R1=true             # true = denoise-single on R1; false = denoise-paired
RUN_CUTADAPT=true                  # set false if primers already removed

# Primer sequences (Leray COI; update if different)
PRIMER_F="GGWACWGGWTGAACWGTWTAYCCYCC"
PRIMER_R="TAIACYTCIGGRTGICCRAARAAYCA"
CUTADAPT_ERROR_RATE=0.1
CUTADAPT_MIN_OVERLAP=10

# DADA2 parameters (tune based on quality profiles)
TRIM_LEFT_F=0
TRIM_LEFT_R=0
TRUNC_LEN_F=145
TRUNC_LEN_R=0
MAX_EE_F=2
MAX_EE_R=2

# ---------------------------------------

mkdir -p "$OUT_DIR"
EXPORT_DIR="$OUT_DIR/exported"
mkdir -p "$EXPORT_DIR"

# 1) Import reads (Casava format, no manifest)
qiime tools import \
  --type 'SampleData[PairedEndSequencesWithQuality]' \
  --input-path "$RAW_READS_DIR" \
  --input-format CasavaOneEightSingleLanePerSampleDirFmt \
  --output-path "$OUT_DIR/paired-end-demux.qza"

# 2) Optional primer trimming
if [[ "$RUN_CUTADAPT" == "true" ]]; then
  qiime cutadapt trim-paired \
    --i-demultiplexed-sequences "$OUT_DIR/paired-end-demux.qza" \
    --p-front-f "$PRIMER_F" \
    --p-front-r "$PRIMER_R" \
    --p-error-rate "$CUTADAPT_ERROR_RATE" \
    --p-overlap "$CUTADAPT_MIN_OVERLAP" \
    --p-match-read-wildcards \
    --o-trimmed-sequences "$OUT_DIR/trimmed-paired.qza" \
    --verbose
  DEMUX_INPUT="$OUT_DIR/trimmed-paired.qza"
else
  DEMUX_INPUT="$OUT_DIR/paired-end-demux.qza"
fi

# 3) DADA2 denoising
if [[ "$USE_SINGLE_END_R1" == "true" ]]; then
  # Export, drop R2, re-import R1 as single-end
  TRIM_EXPORT="$OUT_DIR/trimmed-export"
  mkdir -p "$TRIM_EXPORT"
  qiime tools export --input-path "$DEMUX_INPUT" --output-path "$TRIM_EXPORT"
  find "$TRIM_EXPORT" -type f -name "*_R2_001.fastq.gz" -delete
  rm -f "$TRIM_EXPORT/MANIFEST" "$TRIM_EXPORT/metadata.yml" || true

  qiime tools import \
    --type 'SampleData[SequencesWithQuality]' \
    --input-path "$TRIM_EXPORT" \
    --input-format CasavaOneEightSingleLanePerSampleDirFmt \
    --output-path "$OUT_DIR/trimmed-R1.qza"

  qiime dada2 denoise-single \
    --i-demultiplexed-seqs "$OUT_DIR/trimmed-R1.qza" \
    --p-trim-left "$TRIM_LEFT_F" \
    --p-trunc-len "$TRUNC_LEN_F" \
    --p-max-ee "$MAX_EE_F" \
    --p-n-threads 1 \
    --o-table "$OUT_DIR/COI-table.qza" \
    --o-representative-sequences "$OUT_DIR/COI-rep-seqs.qza" \
    --o-denoising-stats "$OUT_DIR/COI-denoising-stats.qza" \
    --verbose
else
  qiime dada2 denoise-paired \
    --i-demultiplexed-seqs "$DEMUX_INPUT" \
    --p-trim-left-f "$TRIM_LEFT_F" \
    --p-trim-left-r "$TRIM_LEFT_R" \
    --p-trunc-len-f "$TRUNC_LEN_F" \
    --p-trunc-len-r "$TRUNC_LEN_R" \
    --p-max-ee-f "$MAX_EE_F" \
    --p-max-ee-r "$MAX_EE_R" \
    --p-n-threads 1 \
    --o-table "$OUT_DIR/COI-table.qza" \
    --o-representative-sequences "$OUT_DIR/COI-rep-seqs.qza" \
    --o-denoising-stats "$OUT_DIR/COI-denoising-stats.qza" \
    --verbose
fi

# 4) Export feature table and representative sequences
qiime tools export --input-path "$OUT_DIR/COI-table.qza" --output-path "$EXPORT_DIR"
qiime tools export --input-path "$OUT_DIR/COI-rep-seqs.qza" --output-path "$EXPORT_DIR"

# 5) Convert BIOM to TSV
biom convert \
  -i "$EXPORT_DIR/feature-table.biom" \
  -o "$EXPORT_DIR/feature-table.tsv" \
  --to-tsv --table-type="OTU table"

# 6) Filter representative sequences to valid ASVs
cut -f1 "$EXPORT_DIR/feature-table.tsv" | tail -n +2 > "$EXPORT_DIR/filtered-otu-ids.txt"
if [[ -f "$EXPORT_DIR/dna-sequences.fasta" ]]; then
  mv "$EXPORT_DIR/dna-sequences.fasta" "$EXPORT_DIR/dna-sequences-all.fasta"
  if command -v seqkit >/dev/null 2>&1; then
    seqkit grep -f "$EXPORT_DIR/filtered-otu-ids.txt" "$EXPORT_DIR/dna-sequences-all.fasta" > "$EXPORT_DIR/dna-sequences-validated.fasta"
  else
    cp -f "$EXPORT_DIR/dna-sequences-all.fasta" "$EXPORT_DIR/dna-sequences-validated.fasta"
  fi
fi

echo "Done. Outputs in $EXPORT_DIR"
