module load samtools
samtools view --threads 4 -b /omics/odcf/analysis/OE0526_projects/public_data_analyses/seqc2/sequencing/exon_sequencing/results_per_pid/SEQC2_LL1/alignment_hg37/tumor01_SEQC2_LL1_merged.mdup.bam -L seqc2_testdata_aceseq/seq2_testdata.bed > seqc2_testdata_aceseq/SEQC2_LL1_T_small.bam
samtools view --threads 4 -b /omics/odcf/analysis/OE0526_projects/public_data_analyses/seqc2/sequencing/exon_sequencing/results_per_pid/SEQC2_LL1/alignment_hg37/control01_SEQC2_LL1_merged.mdup.bam -L seqc2_testdata_aceseq/seq2_testdata.bed > seqc2_testdata_aceseq/SEQC2_LL1_C_small.bam
samtools index -b seqc2_testdata_aceseq/SEQC2_LL1_T_small.bam
samtools index -b seqc2_testdata_aceseq/SEQC2_LL1_C_small.bam