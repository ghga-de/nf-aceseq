#!/bin/bash
module load  nextflow/22.10.7
nextflow run main.nf -profile dkfz_cluster_hg38,singularity -resume