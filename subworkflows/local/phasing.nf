//
// PHASING: RUN phasing.sh by intervals
//

params.options = [:]

include { BCFTOOLS_MPILEUP } from '../../modules/nf-core/bcftools/mpileup/main.nf' addParams( options: params.options )


workflow PHASING {
    take:
    sample_ch     // channel: [val(meta), tumor,tumor_bai, control, control_bai, tumorname, controlname]
    ref           // channel: [path(fasta), path(fai)]
    intervals     // channel: [[chr, region], [chr, region], ...]

    main:
    versions = Channel.empty()

    // Combine intervals with samples to create 'interval x sample' number of parallel run
    intervals.take(24)
            .set{intervals_ch}
    sample_ch
            .combine(intervals_ch)
            .set { combined_inputs }
    
    //
    // MODULE:BCFTOOLS_MPILEUP 
    //
    // RUN samtools mpileup to call variants. This process is scattered by chr intervals
    combined_inputs = combined_inputs.map {it -> tuple( it[0], it[1], it[2], it[3], it[4],it[7])} 
    BCFTOOLS_MPILEUP (
        combined_inputs, 
        ref
    )
    versions = versions.mix(BCFTOOLS_MPILEUP.out.versions)

    // filter VCFs if there is no variant
    BCFTOOLS_MPILEUP.out.vcf
                    .join(BCFTOOLS_MPILEUP.out.intervals)
                    .join(BCFTOOLS_MPILEUP.out.stats)
                    .filter{meta, vcf, intervals, stats -> WorkflowCommons.getNumVariantsFromBCFToolsStats(stats) > 0 }
                    .set{ch_vcf_stats}
    ch_vcf_stats
        .map { meta, vcf, intervals, stats -> [meta, vcf]} 
        .set {ch_vcf_1}
    ch_vcf_stats
        .map { meta, vcf, intervals, stats -> [meta, intervals]} 
        .set {ch_intervals_1}
    // Collect VCF files and intervals
    ch_vcf = Channel.empty()
    ch_intervals = Channel.empty()
    ch_vcf = ch_vcf.mix(ch_vcf_1)
    ch_intervals = ch_intervals.mix(ch_intervals_1)

    

    emit:
    versions
    
}
