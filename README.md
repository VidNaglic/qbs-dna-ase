# DNA metabarcoding pipeline and data for QBS-DNA study

## Description
This repository contains the core bioinformatics pipeline and taxonomic assignment step (BOLDigger) used in the QBS-DNA study (arable, orchard, strawberry systems). It provides the inputs and outputs needed to reproduce the ASV tables from sequencing data.

Contents:
- bioinformatics scripts used for sequence processing and taxonomic assignment
- two ASV tables (raw and filtered) used in the study
- ASV taxonomic assignments and representative sequences
- sample metadata

## Study reference
Naglic et al. Soil Microarthropod Biodiversity in Agricultural Landscapes: Revisiting the QBS Index Through Genetic Insights.

## Data availability
Raw sequencing data are available in the NCBI Sequence Read Archive (SRA) under BioProject accession number PRJNA1399753.

## Repository structure
- bioinformatics_pipeline/   QIIME2 + DADA2 pipeline and BOLDigger assignment
- data/                      ASV tables, taxonomy, representative sequences, metadata
- docs/                      brief workflow and analysis descriptions

## Key data files
- data/asv_table_raw.tsv                raw ASV table (samples x ASVs)
- data/asv_table_filtered.tsv           filtered ASV table used for analyses
- data/taxonomy_table.tsv               taxonomic assignments for filtered ASVs
- data/boldigger_assignments.xlsx       raw BOLDigger output (optional reference)
- data/representative_sequences.fasta   representative ASV sequences
- data/sample_metadata_raw.tsv          metadata for raw ASV table
- data/sample_metadata_filtered.tsv     metadata for filtered ASV table

## Workflow summary
1. Raw reads processed with QIIME2 + DADA2 to generate ASVs.
2. Representative sequences assigned taxonomy with BOLDigger.
3. ASV tables filtered by abundance and sample thresholds.

## How to run
Bioinformatics pipeline (QIIME2):
- bioinformatics_pipeline/qiime2_dada2_pipeline.sh

Taxonomic assignment (BOLDigger):
- bioinformatics_pipeline/boldigger_pipeline.sh
- bioinformatics_pipeline/boldigger_to_taxonomy.py

## Requirements (not included)
- QIIME 2, biom, and (optional) seqkit for the pipeline
- BOLDigger3 for taxonomic assignment

## DOI / repository link
Replace with your permanent repository and DOI after publishing:
- GitHub: https://github.com/USER/REPO
- DOI (Zenodo): 10.XXXX/zenodo.XXXXXX
