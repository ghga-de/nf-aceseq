[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.1-23aa62.svg)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

<p align="center">
    <img title="nf-aceseq workflow" src="docs/images/nf-aceseq.png" width=70%>
</p>


## Introduction

**nf-aceseq** is a bioinformatics best-practice analysis pipeline for ACEseq Allele-specific copy number estimation adapted from [**ODCF-OTP ACEseqWorkflow**](https://github.com/DKFZ-ODCF/ACEseqWorkflow).

ACEseq (Allele-specific copy number estimation with whole genome sequencing) is a tool to estimate allele-specific copy numbers from human WGS data, and comes along with a variety of features:

- GC/replication timing Bias correction
- Quality check
- SV breakpoint inclusion
- Automated estimation of ploidy and tumor cell content
- HRD/TAI/LST score estimation
- With/without matched control processing

For more information on theoretical part please refer to the orijinal documentation of the pipeline [here](https://aceseq.readthedocs.io/en/latest/index.html). 


For now, this workflow is only optimal to work in ODCF Cluster. The config file (conf/dkfz_cluster.config) can be used as an example.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. 

<!-- TODO nf-core: Add full-sized test dataset and amend the paragraph below if applicable -->

On release, automated continuous integration tests run the pipeline on a full-sized dataset on the AWS cloud infrastructure. This ensures that the pipeline runs on AWS, has sensible resource allocation defaults set to run on real-world datasets, and permits the persistent storage of results to benchmark between pipeline releases and other analysis sources.The results obtained from the full-sized test can be viewed on the [nf-core website](https://nf-co.re/aceseq/results).

## Pipeline summary

<!-- TODO nf-core: Fill in short bullet-pointed list of the default steps in the pipeline -->

The pipeline has 7 main steps: 
1. SNV and CNV calling using mpileup
2. Phasing
3. GC bias correction
4. Breakpoint estimation
5. Plot and report production
6. HDR estimation
7. Present QC for raw reads ([`MultiQC`](http://multiqc.info/))

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

**sex**: The sex of the sample, It is mandatory for nocontrol samples.  

**tumor**: The path to the tumor file

**tumor_index**: The path to the tumor index file

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
