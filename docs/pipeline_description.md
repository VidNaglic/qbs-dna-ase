# Pipeline description

1. Read import and demultiplexing
Raw Illumina paired-end reads are imported into QIIME 2 using the Casava directory format.

2. Primer removal (optional)
Primers are trimmed with cutadapt when required.

3. DADA2 denoising
DADA2 is run either in single-end or paired-end mode to infer ASVs and remove errors.

4. Chimera removal
Chimeras are removed by DADA2 during denoising.

5. Export feature table and representative sequences
The ASV table and representative sequences are exported from QIIME 2.

6. Taxonomic assignment (BOLDigger)
Representative sequences are identified against the BOLD database to obtain taxonomic assignments.

7. Filtering
Low-abundance ASVs and low-depth samples are filtered for downstream analyses using the study thresholds.
