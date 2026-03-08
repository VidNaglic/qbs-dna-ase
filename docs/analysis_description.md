# Analysis description

The statistical analyses are performed on the filtered ASV table and sample metadata.
The main steps include:

1. Alpha diversity metrics
- Richness (observed ASVs)
- Shannon diversity
- Evenness (Shannon / log richness)
- Dominance (1 - Simpson)

2. Group comparisons
For each metric, group differences are tested across System and Treatment:
- If residuals are normal and variances homogeneous: ANOVA + Tukey HSD
- Otherwise: Kruskal–Wallis + Dunn test with Holm correction

3. Beta diversity
- Bray–Curtis dissimilarity on ASV counts
- PERMANOVA for System, Treatment, and their interaction
- Betadisper tests for dispersion by System and Treatment
