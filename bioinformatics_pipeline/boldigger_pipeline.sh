#!/usr/bin/env bash
# BOLDigger3 identification (chunked, resumable) for ASV representative sequences.
# Produces chunked results and a merged parquet file.

set -euo pipefail

# ---- User settings ----
INPUT_FASTA="output/qiime2/exported/dna-sequences-validated.fasta"
RESULTS_DIR="output/boldigger"
DB=3                     # 1-8 (3 = animal library public+private)
MODE=3                   # 1=rapid, 2=genus+species, 3=exhaustive
THRESHOLDS=(97 95 90 85) # species/genus/family/order; class default = 75
CHUNK_SIZE=120
WORKERS=1
MAX_RETRIES=2
RETRY_INTERVAL=8
# ------------------------

mkdir -p "$RESULTS_DIR"

if ! command -v boldigger3 >/dev/null 2>&1; then
  echo "ERROR: boldigger3 is not on PATH. Activate your environment and retry." >&2
  exit 1
fi

[[ -s "$INPUT_FASTA" ]] || { echo "ERROR: FASTA not found or empty: $INPUT_FASTA" >&2; exit 1; }

# Helper: split FASTA into N-record chunks
split_fasta_by_records() {
  local in="$1" per="$2" outdir="$3" prefix
  prefix="${outdir}/chunk_"
  mkdir -p "$outdir"
  awk -v n="$per" -v p="$prefix" '
    BEGIN{filei=0; rec=0}
    /^>/{ if(rec % n == 0){ filei++; close(out); out=sprintf("%s%03d.fasta", p, filei) } rec++ }
    { print >> out }
  ' "$in"
}

# Create chunks
CHUNK_DIR="${RESULTS_DIR}/chunks"
mkdir -p "$CHUNK_DIR"
if ! ls -1 "${CHUNK_DIR}"/chunk_*.fasta >/dev/null 2>&1; then
  rm -f "${CHUNK_DIR}"/chunk_*.fasta 2>/dev/null || true
  split_fasta_by_records "$INPUT_FASTA" "$CHUNK_SIZE" "$CHUNK_DIR"
fi
mapfile -t CHUNKS < <(ls -1 "${CHUNK_DIR}"/chunk_*.fasta 2>/dev/null || true)
(( ${#CHUNKS[@]} > 0 )) || { echo "ERROR: No chunks produced." >&2; exit 1; }

# Detect optional flags
HAS_WORKERS=0
if boldigger3 identify --help 2>/dev/null | grep -q -- '--workers'; then HAS_WORKERS=1; fi
HAS_THRESHOLDS=0
if boldigger3 identify --help 2>/dev/null | grep -q -- '--thresholds'; then HAS_THRESHOLDS=1; fi

# Process each chunk
idx=0
for CHUNK in "${CHUNKS[@]}"; do
  idx=$((idx+1))
  part_tag=$(printf "%03d" "$idx")
  base="dna-sequences-validated"

  part_xlsx="${RESULTS_DIR}/${base}_bold_results_part_${part_tag}.xlsx"
  part_parq="${RESULTS_DIR}/${base}_identification_result_part_${part_tag}.parquet.snappy"

  if [[ -s "$part_xlsx" && -s "$part_parq" ]]; then
    echo "Skipping chunk ${idx} (already processed)."
    continue
  fi

  chunk_base="$(basename "$CHUNK" .fasta)"
  chunk_out_dir="${CHUNK_DIR}/boldigger3_data"
  mkdir -p "$chunk_out_dir"

  expected_parq="${chunk_out_dir}/${chunk_base}_identification_result.parquet.snappy"
  expected_xlsx_primary="${chunk_out_dir}/${chunk_base}_bold_results.xlsx"
  expected_xlsx_alt1="${chunk_out_dir}/${chunk_base}_bold_results_part_1.xlsx"
  expected_xlsx_alt2="${chunk_out_dir}/${chunk_base}_identification_result.xlsx"

  attempt=0
  while :; do
    if BOLDIGGER3_DATA_DIR="$chunk_out_dir" \
       boldigger3 identify "$CHUNK" --db "$DB" --mode "$MODE" \
         $( ((HAS_WORKERS)) && printf -- '--workers %d' "$WORKERS" ) \
         $( ((HAS_THRESHOLDS)) && printf -- '--thresholds %d %d %d %d' "${THRESHOLDS[@]}" ); then
      :
    fi

    out_xlsx=""
    if [[ -s "$expected_xlsx_primary" ]]; then
      out_xlsx="$expected_xlsx_primary"
    elif [[ -s "$expected_xlsx_alt1" ]]; then
      out_xlsx="$expected_xlsx_alt1"
    elif [[ -s "$expected_xlsx_alt2" ]]; then
      out_xlsx="$expected_xlsx_alt2"
    fi

    if [[ -s "$expected_parq" && -n "$out_xlsx" ]]; then
      cp -f "$out_xlsx" "$part_xlsx"
      cp -f "$expected_parq" "$part_parq"
      break
    fi

    attempt=$((attempt+1))
    if (( attempt > MAX_RETRIES )); then
      echo "ERROR: Reached max retries for chunk ${chunk_base}." >&2
      exit 3
    fi
    sleep "$RETRY_INTERVAL"
  done

done

# Merge parquet parts
FINAL_PARQ="${RESULTS_DIR}/dna-sequences-validated_identification_result.parquet.snappy"
RESULTS_DIR="$RESULTS_DIR" python3 - <<'PY'
import os, glob, sys
import pandas as pd

results_dir = os.environ.get("RESULTS_DIR", "")
if not results_dir:
    results_dir = "output/boldigger"

parts = sorted(glob.glob(os.path.join(results_dir, "dna-sequences-validated_identification_result_part_*.parquet.snappy")))
if not parts:
    print("ERROR: No parquet parts found in results dir.", file=sys.stderr)
    sys.exit(2)

dfs = [pd.read_parquet(p) for p in parts]
merged = pd.concat(dfs, ignore_index=True).drop_duplicates()
final_parq = os.path.join(results_dir, "dna-sequences-validated_identification_result.parquet.snappy")
merged.to_parquet(final_parq, index=False)
print("Wrote:", final_parq, "rows:", len(merged))
PY

echo "Done. Results in $RESULTS_DIR"
