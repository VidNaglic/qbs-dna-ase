# Pipeline description

1. Read import and demultiplexing
Raw Illumina paired-end reads are imported into QIIME 2 using a paired-end manifest file.

2. Quality inspection
Demultiplexed reads are summarized with `qiime demux summarize` to document quality profiles.

3. DADA2 denoising
DADA2 is run in paired-end mode with the study settings: trim-left 20 bp for both reads, truncation at 230 bp forward and 180 bp reverse, max expected errors of 2.0, trunc-Q 2, minimum overlap 12 bp, consensus chimera removal, and independent sample pooling.

4. Chimera removal
Chimeras are removed by DADA2 during denoising.

5. Export feature table and representative sequences
The ASV table and representative sequences are exported from QIIME 2.

6. Taxonomic assignment (BOLDigger)
Representative sequences are identified with BOLDigger3 in exhaustive-search mode. Assignment thresholds are 98%, 95%, 90%, and 85% identity for species, genus, family, and order-level matches, respectively.

7. Filtering
Low-abundance ASVs and low-depth samples are filtered for downstream analyses using the study thresholds.
