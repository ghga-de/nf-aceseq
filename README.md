[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.1-23aa62.svg)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

<p align="center">
    <img title="nf-aceseq workflow" src="docs/images/nf-aceseq.png" width=70%>
</p>


## Introduction

**nf-aceseq** is a bioinformatics best-practice analysis pipeline for ACEseq Allele-specific copy number estimation adapted from [**ODCF-OTP ACEseqWorkflow**](https://github.com/DKFZ-ODCF/ACEseqWorkflow).

ACEseq (Allele-specific copy number estimation with whole genome sequencing) is a tool to estimate allele-specific copy numbers from human Whole Genome Sequencing data (>30X) using a tumor vs control paired data, and comes along with a variety of features:

- GC/replication timing Bias correction
- Quality check
- SV breakpoint inclusion
- Automated estimation of ploidy and tumor cell content
- HRD/TAI/LST score estimation
- With/without matched control processing
- Replacing bad control

For more information on theoretical part please refer to the orijinal documentation of the pipeline [here](https://aceseq.readthedocs.io/en/latest/index.html). 

This workflow is not optimal to use with Whole Exome Sequencing data! 

For now, this workflow is only optimal to work in ODCF Cluster. The config file (conf/dkfz_cluster.config) can be used as an example.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. 


## Pipeline summary

<!-- TODO nf-core: Fill in short bullet-pointed list of the default steps in the pipeline -->

The pipeline has 7 main steps: 
1. **SNV calling** using mpileup
2. **Preprocessing** is part of quality control to correct biases in GC/replication timing
3. **Phasing** using beagle5
4. **Segmentation** with support of SV breakout inclusion. 
5. **Purity-Ploidity prediction**, plot and report production
6. **HDR estimation** as well as TAI and LST
7. ([`MultiQC`](http://multiqc.info/)) is used to present QC for raw reads 

## Running pipeline with different modules:

- Running with no control samples or with bad control samples

To be able to run with fake control ACE-Seq pipeline must be already processed with some other tumor-normal pairs. Then, its coverage profile can be used for normalization for nocontrol or bad control samples. In this case, no BAFs can be used from a matching control sample, and also patients sex would not be inferred. In order to use this functionality, --fake_control and --fake_control_prefix must be defined.

For the configuraton, the path and the prefix to the control coverage profile for a male or a female patient must be matched: fake_control file directory must be organized such that: {fake_control_prefix}.chr*.cnv.anno.tab.gz for hg38 or {fake_control_prefix}.*.cnv.anno.tab.gz for hg37. For female samples chromosome list should be 1-22,X and for male samples chromosome list should be 1-22,X,Y.  

If there is no control, **automatically** nocontrol workflow will be switched on. In order to use nocontrol workflow, sex must be defined in metadata. 

Nocontrol behaviour of this workflow uses a fake control. In order to use this functionality, --fake_control and --fake_control_prefix must be defined.

As an important note: running with Fake Control (or no control mode) cannot be executed in the same time with normal run mode (without fake control replacement)

- Running only for Quality Control

--runQualityCheckOnly true
runs **only** SNV calling and preprocessing

- Running with or without Structural Variants SVs

In order to integrate SV processing,A file path contaning Structural Variants must be provided in the samplesheet.

- Sex estimation

Sex is an important part of this workflow, if there is no control file, sex cannot be estimated through pipeline and thus must be given through samplesheet. 

--estimatesex
If it is false, sex estimation will not run and user given sex is used. To do so, samplesheet must include sex column filled. 

## How to prepare files

This workflow uses Beagle5 for imputing. Beagle uses 2 types of reference files: 

- Preperation of generic maps:

Appropriate version of the genetic map can be downloaded [here](https://bochet.gcc.biostat.washington.edu/beagle/genetic_maps/)

Data processing must be done as follows:

  ```console
version="38/37/36"
for chr in `seq 1 22` X ; do cat plink.chr${chr}.GRCh${version}.map | sed 's/^/chr/' > plink.chr${chr}.GRCh${version}.CHR.map; done
  ```

- Preperation of reference files: 

An example on how the reference files for beagle are prepared can be found [here](https://bochet.gcc.biostat.washington.edu/beagle/1000_Genomes_phase3_v5a/READ_ME_beagle_ref). Be carefull to prepare the same version of reference file used for SNV calling through bcftools mpileup! 


## Quick Start

1. Install [`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation) (`>=22.10.1`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/) (you can follow [this tutorial](https://singularity-tutorial.github.io/01-installation/)) for full pipeline reproducibility _(you can use [`Conda`](https://conda.io/miniconda.html) both to install Nextflow itself and also to manage software within pipelines. Please only use it within pipelines as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_.

3. Download the pipeline and test it on a minimal dataset with a single command:

   ```console
   git clone https://github.com/ghga-de/nf-aceseq.git
    ```

   before run do this to bin directory, make it runnable!:

  ```console
  chmod +x bin/*
  ```

   ```bash
   nextflow run main.nf -profile test,YOURPROFILE --outdir <OUTDIR> --input <SAMPLESHEET>
   ```

   Note that some form of configuration will be needed so that Nextflow knows how to fetch the required software. This is usually done in the form of a config profile (`YOURPROFILE` in the example command above). You can chain multiple config profiles in a comma-separated string.

   > - The pipeline comes with config profiles called `docker` and `singularity` ` which instruct the pipeline to use the named tool for software management. For example, `-profile test,docker`.
   > - Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.
   > - If you are using `singularity`, please use the [`nf-core download`](https://nf-co.re/tools/#downloading-pipelines-for-offline-use) command to download images first, before running the pipeline. Setting the [`NXF_SINGULARITY_CACHEDIR` or `singularity.cacheDir`](https://www.nextflow.io/docs/latest/singularity.html?#singularity-docker-hub) Nextflow options enables you to store and re-use the images from a central location for future pipeline runs.


4. Start running your own analysis!

   <!-- TODO nf-core: Update the example "typical command" below used to run the pipeline -->

   ```bash
    nextflow run main.nf --input samplesheet.csv --outdir <OUTDIR> -profile <docker/singularity> --config test/institute.config
   ```
   
## Samplesheet columns

**sample**: The sample name will be tagged to the job

**sex**: The sex of the sample, It is only mandatory for nocontrol samples. Keep it blank to enable sex estimation. 

**sv**: The path to file with structural variants, if there is no SV file will be kept blank.

**tumor**: The path to the tumor file.

**tumor_index**: The path to the tumor index file.

**control**: The path to the control file, if there is no control will be kept blank.

**contro_index_**: The path to the control index file, if there is no control will be kept blank.

## Data Requirements

## Documentation

The nf-aceseq pipeline comes with documentation about the pipeline [usage](https://github.com/ghga-de/nf-aceseq/usage), [parameters](https://github.com/ghga-de/nf-aceseq/parameters) and [output](https://github.com/ghga-de/nf-aceseq/output).

## Credits

nf-aceseq was originally written by kuebra.narci@dkfz-heidelberg.de.

This pipeline is adapted from [**ODCF-OTP ACEseqWorkflow**](https://github.com/DKFZ-ODCF/ACEseqWorkflow).

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).


## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use  nf-core/aceseq for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->
