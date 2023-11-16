#!/bin/bash
module load  nextflow/22.10.7
nextflow run main.nf -profile dkfz_cluster_hg37,singularity --input assets/samplesheet_37_test.csv --estimatesex false --min_gap_length 1000 --createbafplots false --min_num_SNPs 0 --min_membership 0 --min_distance 0 --min_seg_length_prune 0 --clustering "no" --min_cluster_number 0 -resume