#!/bin/bash
module load  nextflow/22.10.7
nextflow run main.nf -profile test_nocontrol_hg37,singularity --input assets/samplesheet_37_nocontrol.csv