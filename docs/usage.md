# nf-aceseq: Usage

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

## Data requireents and Parameters

Main swiches:

- --runQualityCheckOnly: If true, runs **only** SNV calling and preprocessing. No CNV processing performs afterwards. Default: false
- --estimatesex        : If true, sex estimation will be performed. If sex is not defined in samplesheet,estimatesex automaticaly be performed. For no control samples, sex cannot be estimated.  Default: true
- --createbafplots     : If true, BAF plots will be created. Default: true
- --skip_multiqc       : If true, skips MultiQC.

Reference Files:

- --genome: To use igenome or refgenie. Either hg19 or hg38 to use refgenie or GRCh37 or GRCh38 for igenomes can be defined as reference type.
- --fasta: path/to/ref.fa
- --fasta_fai: path/to/ref.fa.fai
- --chr_prefix: 'chr' or ''
- --chrlenght: path/to/chrlength.tsv, tab seperated chromosome positions
- --contig_file: path/to/contig_file.tsv, tab seperated contigpositions
- --beagle_reference: path/to/Beagle/1000genomes/ , directory must include beagle reference files per chromosome. HG38 reference system assumes chr prefix on files. 
- --beagle_genetic_map: path/to/databases/genetic_maps/ , directory must include beagle genetic map files per chromosome. HG38 reference system assumes chr prefix on files. 
- --beagle_ref_ext: beagle reference extention:  vcf | bref | bref3
- --beagle_map_ext: beagle map file extention:   map | plink

Annotation Files:

- --dbsnp_snv: dbSNP SNV calls (vcf.gz)
- --mapability_file: Mappability regions (.bedGraph.gz)
- --replication_time_file: ENCODE/RepliSeq replication times (.Rda)
- --gc_content_file: GC content (.txt, .bed)
- --gene_annotation_file: Druggable genes (.tsv, .bed)
- --centromer_file: Centromer regions (.bed, .txt)
- --blacklist_file: Artifact regions (.bed, .txt)  
- --cytobands_file: Cytoband regions (.bed, .txt)

Parameters:

- Mpileup Options

--mpileup_qual: quality used for parameter ‘Q’ in samtools mpileup. Minimum base quality. Default: 0 
    
- Phasing options
  
--minHT: Minumum HT.minimum number of consecutive SNPs to be considered for haploblocks. Default: 5

- SNV Merge filter

--snp_min_coverage: Minimum SNP coverage. minimum coverage in control for SNP. Default: 5

- Annotate CNV files

--min_X_ratio: minimum ratio for number of reads on chrY per base over number of reads per base over whole genome to be considered as female. Default 0.8
--min_Y_ratio: minimum ratio for number of reads on chrY per base over number of reads per base over whole genome to be considered as male. Default 0.12

- CNV Merge filter

--cnv_min_coverage: minimum coverage for 1kb windows to be considered for merging in 10kb windows. Default 5000
--mapping_quality: minimum mapping quality for 1kb windows to be considered for merging in 10kb windows (maximum mappability). Default 1000
--min_windows: minimum number of 1kb windows fullfilling cnv_min_coverage and mapping_quality to obtain merged 10kb windows. Default 5

- Correct GC options

--lowess_f: f parameter for R lowess function. Default 0.1
--scale_factor: scale_factor for R lowess function. Default 0.9
--covplot_ylims: ylims for Rplots in GC-bias plots. Default 4
--gc_bias_json_key: key in GC-bias json. Default "gc-bias"

- Breakpoints and gaps options

--min_DDI_length: minimum length for DEL/DUP/INV to be considered for breakpoint integration. Default 1000
--selSVColumn: column from bedpe file to be recored in ${pid}_sv_points.txt file. Default "eventScore"

- PSCBS options

--min_seg_width: segmentByPairedPSCBS() minwidth parameter in PSCBS R package. Default 2000
--undo_SD: segmentByPairedPSCBS() undo.SD parameter in PSCBS R package. Default  24
--pscbs_prune_height: pruneByHClust() parameter h in PSCBS R package. Default 0
--min_gap_length: Default 9000

- mark Segments with HomozygDel options

--min_segment_map: minimum average mappability over segment to be kept after segmentation. Default 0.6

- cluster and prune segments

--min_seg_length_prune: maximum of segment to be considered for merging to neighbouring segment prior to clustering. Default 9000
--min_num_SNPs: maximum number of SNPs in segment to be considered for merging to neighbouring segment prior to clustering. Default 15
--clustering: should segments be clustered (yes|no), coerage and BAF will be estimated and assigned clusterwide. Default "yes"
--min_cluster_number: minimum number of clusters to be tried with BIC. Default 1
--min_membership: obsolete. Default 0.8
--min_distance: Default 0.05

- estimate Purity Ploidy
    
--minLim: Default 0.47
--maxLim: Default 0.53
--min_length_purity: minimum length of segments to be considered for tumor cell content and ploidy estimation. Default 1000000
--min_hetSNPs_purity: minimum number of control heterozygous SNPs in segments to be considered for tumor cell content and ploidy estimation. Default 5000    
--dh_stop: Default "max"
--min_length_dh_stop: Default 1000000
--dh_zero: Default "no"
--purity_min: minimum tumor cell content allowed. Default 0.15
--purity_max: Default 1.0
--ploidy_min: Default 1.0
--ploidy_max: Default 6.5
--local_minium_upper_boundary_shift: Default 0.1

- generate plots

--ymaxcov_threshold: Default 8.0

## Samplesheet input

You will need to create a samplesheet with information about the samples you would like to analyse before running the pipeline. Use this parameter to specify its location.

```bash
--input '[path to samplesheet file]'
```

### Full samplesheet

Below is an example for the same sample sequenced across 7 lanes:
Note: If there is no control, sex must be defined. Pipeline will auto-detect if there is no control. 

```console
sample,sex,sv,tumor,tumor_bai,control,control_bai
sample1,,,sample1_tumor.bam,sample1_tumor.bai,sample1_control.bam,sample1_control.bai
sample2,male,,sample2_tumor.bam,sample2_tumor.bai,sample2_control.bam,sample2_control.bai
sample3,,svfile.tsv,sample3_tumor.bam,sample3_tumor.bai,sample3_control.bam,sample3_control.bai
sample4,male,,sample4_tumor.bam,sample4_tumor.bai,,
sample5,female,svfile.tsv,sample5_tumor.bam,sample5_tumor.bai,,

```


| Column    | Description                                                                                                                                                                            |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sample`  | Custom sample name. This entry will be used to name the output files and output directories. |
| `sex` | Sex of the sample, male | female | klinefelter (optional) |
| `sv` | Full path to SV file (optional)|
| `tumor` | Full path to tumor sample BAM file |
| `tumor_bai` | Full path to tumor sample BAI file |
| `control` | Full path to control sample BAM file (optional)|
| `control_bai` | Full path to control sample BAI file (optional) |

An [example samplesheet](../assets/samplesheet.csv) has been provided with the pipeline.

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run main.nf--input samplesheet.csv --outdir <OUTDIR> --genome GRCh37 -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```


## Core Nextflow arguments

> **NB:** These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen).

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.


> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility. Conda usage is not possible for this pipeline. 

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer enviroment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).


## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
