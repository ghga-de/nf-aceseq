# nf-aceseq: Output

## Introduction

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

<!-- TODO nf-core: Write this documentation describing your workflow's output -->

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

- [SNV Calling](#snvcalling) - samtools mpileup part generates genotype likelihoods at each genomic position with coverage. Then, custom python scrtipy returns base counts of A and B allele of control and tumor, if there is coverage in either one (A allele is reference base) and it returns coverage in 1kb bins of control and tumor, if there is coverage in either one. Then, mappabilities of those regions are annotated. Those parts run in parallel per chromosome, finally SNP and coverage data are merged. Regions without coverage or SNP information are discarded.
- [Preprocessing](#preprocessing) - Then, SNV calls are used to correct for gc bias and replication timing starting from tumor and control read counts in 10kb windows. The two bias correction steps described above are done sequentially. A simultaneous 2D LOWESS or LOESS correction would be desirable, but fails due to computational load (the clusters to be fitted have 106 points). Different parameters such as slope and curvature of the both LOWESS correction curves used are extracted. The GC curve parameters is used as quality measures to determine the suitability of the sample for further analysis whereas the replication timing curve parameters is used to infer the proliferation activity of the tumor. We could show a strong correlation between Ki-67 estimates and the slope of the fitted curve.
- [Phasing](#phasing) - Phasing for female and male samples is seperated. bcftools mpileup generates likelihoods at each genomic position with coverage using control samples. For samples without control, coverages are generated from tumor samples only and unphased genotypes are created from known SNPs. Then phasing - imputation- is performed using beagle5 tool. Then, haplotype blocks are grouped obtained with imputation a haplotype group start at first phased SNP after an unphased SNP and is ended with the next occuring unphased SNP. Counts are then adjusted for allele frequencies based on imputation results. Thus, the median tumor BAF is calculated haploblock-wise for all SNP positions that are heterozygous in the control. If it is below 0.5 A- and B-allele are swapped within the haploblock region to get consistency across the haploblocks of a segment. This procedure ensures a more accurate estimation of the allelic state of a region in the next step.
- [Segmentation](#segmentation) - Once data pre-processing is completed the genome is segmented with the PSCBS (parent specific circular binary segmentation) algorithm. Prior to the actual segmentation, segment-boundaries due to a lack of coverage are determined. Single outliers among the coverage and very low coverage regions are determined using PSCBS functions. In addition to these, breakpoints that are indicated by previously called structural variations are taken into account. During the actual segmentation step the genome is segmented based on the pre-defined breakpoints, changes in the coverage ratio and DH. DH values are only considered in case the SNP position is heterozygous in the control. Homozygous deletions are called in segments that lack mapped reads. These deletions are only considered to be true in case the low read count is unlikely to be caused by a low mappability. Thus, the mappability is assessed for all segments. Regions with mappbility below 60% are considered unmappable and not further considered for copy number estimation. Each SNP position is annotated with the new segment information and mappability. In order to avoid over-segmentation short segments (default <9 kb) are attached to the closest neighboring segment according to the coverage ratio. Subsequently, segments from diploid chromosomes are clustered according to the log2 of the coverage ratio and DH. These values are scaled prior to clustering. The DH of a segment is defined as the most commonly found DH value among all SNPs in the segment that are heterozygous in the control. To avoid over-fitting a further downstream processing is applied. Firstly, the minimal accuracy defined by the FWHM is taken into account. Cluster with more than 85% of all points within these coverage limits are chosen. Of these the cluster with most segments is defined as main cluster. The other chosen clusters are merged with the main cluster if their the difference between their center and the main cluster center is not bigger than XX times the DH-MAD of the main clusters. Neighboring segments are merged before new cluster centers are determined. In a second step segments that are embedded within main cluster segments are considered for merging. The number of control heterozygous SNP positions and the length are considered here to establish two criteria. Segments with less than 5 heterozygous SNPs are merged with the main cluster if they lie between the FWHM boundaries. If the SNP error of a selected segment exceeds the distance in DH and the length error exceeds the coverage difference it is appointed to the main cluster. Again neighboring segments with identical clusters are merged. Finally, a general cluster coverage is estimated from all relevant segments and assigned to the cluster members to further reduce noise in the data.
- [Purity Evaluation](#purityevaluation) - Once the allelic state of a segment is determined it can be used for the computation of tumor cell content and ploidy of the main tumor cell population. The average observed tumor ploidy can be determined with equation. To obtain actual copy numbers for each segment ploidy and tumor cell content of the tumor sample have to be inferred from the data. Information about the allelic state of a segment is combined with TCN, DH and allele-specific copy numbers calculations. The combination of ploidy and tumor cell content that can explain the observed data the best is to be found. Possible ploidies in the range from 1 to 6.5 in steps of 0.1 and possible tumor cell content from 30% to 100% in steps of 1% are tested. The evaluation is done based on the distance of all segments from their next plausible copy number state. Imbalanced segments are fitted to a positive integer value.
- [HDR estimation](#hdrestimation) - Once the optimal ploidy and tumor cell content combinations are found the TCN and allele-specific CN will be estimated for all segments in the genome and classified (gain, loss, copy-neutral LOH, loss LOH, gain LOH, sub). If a segments TCN is further than 0.3 away from an integer value it is assumed to originate from subpopulations in the tumor sample that lead to gains or losses in part of the tumor cell population.
- [MultiQC](#multiqc) - Aggregate report describing results and QC from the whole pipeline
- [Pipeline information](#pipeline-information) - Report metrics generated during the workflow execution

### SNV Calling

<details markdown="1">
<summary>Output files</summary>

- `metaid/`
  - `anno_cnv/`: A directory with annotated coverages per chromosome
  - `*.snp.tab.gz`: Merged SNVs
  - `*.cnv.tab.gz`: Merged coverages

</details>

### Preprocessing

<details markdown="1">
<summary>Output files</summary>

- `metaid/`
  - `gc_bias/`: A directory with annotated coverages per chromosome
    - `all_corrected.txt.gz`: Corrected SNVs
    - `*.coverage.png`: Coverage plots
    - `*gc_corrected*`: GC corrected profiles

</details>

### Phasing

<details markdown="1">
<summary>Output files</summary>

- `metaid/`
  - `haploblocks/`: A directory with haploblocks per chromosome
  - `phasing/`: A directory with phased hoploblocks per chromosome

</details>

### Segmentation

<details markdown="1">
<summary>Output files</summary>

- `metaid/`

</details>

### Purity Evaluation

<details markdown="1">
<summary>Output files</summary>

- `metaid/`

</details>

### HDR Estimation

<details markdown="1">
<summary>Output files</summary>

- `metaid/`

</details>

### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: a standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: directory containing parsed statistics from the different tools used in the pipeline.
  - `multiqc_plots/`: directory containing static images from the report in various formats.

</details>

[MultiQC](http://multiqc.info) is a visualization tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in the report data directory.

Results generated by MultiQC collate pipeline QC from supported tools e.g. FastQC. The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability. For more information about how to use MultiQC reports, see <http://multiqc.info>.

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
