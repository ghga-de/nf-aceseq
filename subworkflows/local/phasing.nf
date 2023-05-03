//
// PHASING: RUN phasing.sh by intervals
//

params.options = [:]

include { BCFTOOLS_MPILEUP    } from '../../modules/nf-core/bcftools/mpileup/main.nf' addParams( options: params.options )
include { CREATE_FAKE_SAMPLES } from '../../modules/local/create_fake_samples.nf'     addParams( options: params.options )
include { EMBED_HAPLOTYPES    } from '../../modules/local/embed_haplotypes.nf'        addParams( options: params.options )
include { BEAGLE5_BEAGLE as  BEAGLE5_BEAGLE_GERM  } from '../../modules/nf-core/beagle/main.nf'  addParams( options: params.options )
include { BEAGLE5_BEAGLE as  BEAGLE5_BEAGLE_X     } from '../../modules/nf-core/beagle/main.nf'  addParams( options: params.options )


workflow PHASING {
    take:
    sample_ch     // channel: [val(meta), tumor,tumor_bai, control, control_bai, tumorname, controlname, sample_g]
    ref           // channel: [path(fasta), path(fai)]
    chrlength     // channel: [[chr, region], [chr, region], ...]
    beagle_ref    // channel: directory
    beagle_map    // channel: directory

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
    // MODULE:BCFTOOLS_MPILEUP 
    //
    // RUN samtools mpileup to call variants. This process is scattered by chr intervals
    combined_inputs = combined_inputs.map {it -> tuple( it[0], it[1], it[2], it[3], it[4],it[8])} 
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
        .set {ch_vcf}
    ch_vcf_stats
        .map { meta, vcf, intervals, stats -> [meta, intervals]} 
        .set {ch_intervals}

    ch_unphased = ch_intervals.join(ch_vcf, by: [0])
    //
    // MODULE:CREATE_FAKE_SAMPLES 
    //
    // RUN beagle_create_fake_samples.py
    CREATE_FAKE_SAMPLES(
        ch_unphased
    )
    versions = versions.mix(CREATE_FAKE_SAMPLES.out.versions)

    sample_g = sample_ch.map {it -> tuple( it[0], it[8])}
    sample_g.view()
    // filter out both X and Y if gender is Male!
    if (sample_g.count() == 2){
        CREATE_FAKE_SAMPLES.out.unphased_vcf.filter{it -> !(it[1] in ['chrY', 'Y'])}
                                        .set{ch_unphased_vcf_germ}
    }
    else {
        CREATE_FAKE_SAMPLES.out.unphased_vcf.filter{it -> !(it[1] in ['chrY', 'Y', 'chrX', 'X'])}
                                        .set{ch_unphased_vcf_germ}
    }
    //
    // MODULE:BEAGLE 
    // 
    // Run beagle for Chr 1-22 
    BEAGLE5_BEAGLE_GERM(
        ch_unphased_vcf_germ,
        beagle_ref,
        beagle_map
    )
    versions = versions.mix(BEAGLE5_BEAGLE_GERM.out.versions)
    
    // Prepare input channel  matching meta and interval
    BEAGLE5_BEAGLE_GERM.out.vcf
                            .join(ch_unphased_vcf_germ, by: [0, 1])
                            .set{ch_embed}
    ch_embed.view()

    // MODULE:EMBED_HAPLOTYPES 
    // 
    // Run for Chr 1-22
    EMBED_HAPLOTYPES(
        ch_embed
    )
    versions = versions.mix(EMBED_HAPLOTYPES.out.versions)

    
    emit:
    versions
    
}
