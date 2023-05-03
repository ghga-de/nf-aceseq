//
// SNVCALL: RUN 
//

params.options = [:]

include { SAMTOOLS_MPILEUP } from '../../modules/nf-core/samtools/mpileup/main.nf' addParams( options: params.options )
include { WIN_GENERATOR    } from '../../modules/local/win_generator.nf'           addParams( options: params.options )
include { MERGE_SNP        } from '../../modules/local/merge_snp.nf'               addParams( options: params.options )
include { ESTIMATE_SEX     } from '../../modules/local/estimate_sex.nf'            addParams( options: params.options )
include { ANNOTATE_CNV     } from '../../modules/local/annotate_cnv.nf'            addParams( options: params.options )
include { MERGE_CNV        } from '../../modules/local/merge_cnv.nf'               addParams( options: params.options )


workflow GET_BREAKPOINTS_SEGMENTS {
    take:
    sample_ch     // channel: [val(meta), tumor,tumor_bai, control, control_bai, tumorname, controlname]
    ref           // channel: [path(fasta), path(fai)]
    chrlength     // channel: [[chr, region], [chr, region], ...]
    dbsnp         // channel: [dbsnp, index]
    mappability   // channel: [mappability, index]

    main:
    versions = Channel.empty()

    // Combine intervals with samples to create 'interval x sample' number of parallel run
    intervals  = chrlength.splitCsv(sep: '\t', by:1)
    intervals.take(24)
            .set{intervals_ch}
    sample_ch
            .combine(intervals_ch)
            .set { combined_inputs }
    
    //
    // MODULE:SAMTOOLS_MPILEUP 
    //
    // RUN samtools mpileup to call variants. This process is scattered by chr intervals
    combined_inputs = combined_inputs.map {it -> tuple( it[0], it[1], it[2], it[3], it[4],it[7])} 
    SAMTOOLS_MPILEUP (
        combined_inputs, 
        ref
    )
    versions = versions.mix(SAMTOOLS_MPILEUP.out.versions)
  
    //
    // MODULE:WIN_GENERATOR
    //
    // RUN snp_cnv.py
    WIN_GENERATOR(
        SAMTOOLS_MPILEUP.out.mpileup, 
        dbsnp
    )
    versions  = versions.mix(WIN_GENERATOR.out.versions) 

    // Group interval SNP tab files according to meta
    WIN_GENERATOR
                .out
                .snp
                .groupTuple()
                .set{combined_snp}
    //
    // MERGE_SNP: Merge and filter SNP positions
    //
    // Runs merge_and_filter_snp.py
    MERGE_SNP(
        combined_snp
    )
    versions  = versions.mix(MERGE_SNP.out.versions)
    all_snp = MERGE_SNP.out.snp

    //
    // MODULE: ANNOTATE_CNV
    //
    // Run annotate_vcf.pl and addMappability.py per cnv file
    // Group interval SNP tab files according to meta
    ANNOTATE_CNV(
        WIN_GENERATOR.out.cnv,
        mappability
    )
    versions  = versions.mix(ANNOTATE_CNV.out.versions)

    // combine cnvs according to meta
    ANNOTATE_CNV
                .out
                .annotated_cnv
                .groupTuple()
                .set{ch_anno_cnv}
    //
    // MODULE: MERGE_CNV
    //
    // Runs merge_and_filter_cnv.py
    MERGE_CNV (
        ch_anno_cnv
    )
    versions  = versions.mix(MERGE_CNV.out.versions)
    all_cnv   = MERGE_CNV.out.cnv
    // combine cnvs according to meta
    WIN_GENERATOR
                .out
                .cnv
                .groupTuple()
                .set{combined_cnv}
    //
    // MODULE: ESTIMATE_SEX
    //
    // Run getSex.R per cnv file
    ESTIMATE_SEX(
        combined_cnv,
        chrlength
    )
    versions  = versions.mix(ESTIMATE_SEX.out.versions)
    ch_sex = ESTIMATE_SEX.out.sex

    emit:
    versions
    all_snp
    all_cnv
    ch_sex
}
