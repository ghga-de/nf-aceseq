#!/bin/bash
module load  nextflow/22.10.7
nextflow run main.nf -profile test_hg37,singularity -resume