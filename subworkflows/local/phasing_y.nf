//
// PHASING_Y: RUN phasing.sh by intervals for MALE samples
//
// Running beagle requires a directory of references, prepended with chr name. That needs to be changed!

params.options = [:]

include { BCFTOOLS_MPILEUP    } from '../../modules/nf-core/bcftools/mpileup/main.nf' addParams( options: params.options )
include { MAKE_MOCK           } from '../../modules/local/make_mock.nf'               addParams( options: params.options )
include { CREATE_FAKE_SAMPLES } from '../../modules/local/create_fake_samples.nf'     addParams( options: params.options )
include { EMBED_HAPLOTYPES    } from '../../modules/local/embed_haplotypes.nf'        addParams( options: params.options )
include { GROUP_HAPLOTYPES    } from '../../modules/local/group_haplotypes.nf'        addParams( options: params.options )
include { ADD_HAPLOTYPES      } from '../../modules/local/add_haplotypes.nf'          addParams( options: params.options )
include { CREATE_BAF_PLOTS    } from '../../modules/local/create_baf_plots.nf'        addParams( options: params.options )
include { BEAGLE5_BEAGLE      } from '../../modules/nf-core/beagle/main.nf'           addParams( options: params.options )
include { CREATE_UNPHASED     } from '../../modules/local/create_unphased.nf'         addParams( options: params.options ) 


workflow PHASING_Y {
    take:
    sample_ch     // channel: [val(meta), tumor, tumor_bai, control, control_bai, tumorname, controlname, sex_file, all_snp_ch, all_snp_ch_index]
    ref           // channel: [path(fasta), path(fai)]
    chrlength     // channel: [[chr, region], [chr, region], ...]
    beagle_ref    // channel: directory
    beagle_map    // channel: directory
    dbsnp         // channel: [path(dbsnp), path(index)]
    chr_prefix    // channel: val: chr|""

    main:
    versions     = Channel.empty()
    ch_unphased  = Channel.empty()

    // Combine intervals with samples to create 'interval x sample' number of parallel run
    intervals  = chrlength.splitCsv(sep: '\t', by:1)

    //// phasing.sh ////

    //// Male Workflow ////
    // filter out both X and Y if gender is Male!
    intervals.take(22)
            .set{intervals_ch}
    sample_ch
        .combine(intervals_ch)
        .set { combined_inputs_male }
    combined_inputs_male = combined_inputs_male.map {it -> tuple( it[0], it[1], it[2], it[3], it[4],it[10])} 
    //
    // MODULE:BCFTOOLS_MPILEUP 
    //
    // RUN samtools mpileup to call variants. This process is scattered by chr intervals (only for chr1-22)
    BCFTOOLS_MPILEUP (
        combined_inputs_male, 
        ref
    )
    versions    = versions.mix(BCFTOOLS_MPILEUP.out.versions)
    ch_unphased = ch_unphased.mix(BCFTOOLS_MPILEUP.out.vcf)

    // Prepare moch haploblock file for chrX
    tmp = combined_inputs_male.map {it -> tuple( it[0], it[1])}
    MAKE_MOCK(
        tmp,
        chr_prefix
    )
    haploblock_x = MAKE_MOCK.out.haploblock
    phased_vcf_x = MAKE_MOCK.out.phased_vcf
        
    //
    // MODULE:CREATE_FAKE_SAMPLES 
    //
    // RUN beagle_create_fake_samples.py, Run for Chr 1-22 and ChrX if female
    CREATE_FAKE_SAMPLES(
        ch_unphased
    )
    versions = versions.mix(CREATE_FAKE_SAMPLES.out.versions)

    //
    // MODULE:BEAGLE 
    // 
    // Run beagle for Chr 1-22 chrX if female
    // OTP runs have impute working! Beagle is new. 
    if (params.chr_prefix.contains('chr')){
        
        beagle_ref
            .combine(intervals_ch)
            .filter{it[0].baseName.contains(it[1]+".")}
            .map{it -> tuple(it[0], it[1])}
            .set{beagle_ref_ch}

        beagle_map.combine(intervals_ch)
            .filter{it[0].baseName.contains(it[1]+".")}
            .map{it -> tuple(it[0], it[1])}
            .set{beagle_map_ch}
    }
    else{
        beagle_ref
            .combine(intervals_ch)
            .filter{it[0].baseName.contains("chr" + it[1]+".")}
            .map{it -> tuple(it[0], it[1])}
            .set{beagle_ref_ch}

        beagle_map.combine(intervals_ch)
            .filter{it[0].baseName.contains("chr" + it[1]+".")}
            .map{it -> tuple(it[0], it[1])}
            .set{beagle_map_ch}

    }
    beagle_ref_ch.join(beagle_map_ch, by:[1] )
                .map{it -> tuple(it[1], it[0], it[2])}
                .set{beagle_ch}
    beagle_ch.join(CREATE_FAKE_SAMPLES.out.unphased_vcf, by:[1])
             .set{beagle_in_ch} 

    BEAGLE5_BEAGLE(
        beagle_in_ch
    )
    versions = versions.mix(BEAGLE5_BEAGLE.out.versions)

    // Prepare input channel  matching meta and interval
    BEAGLE5_BEAGLE.out.vcf
                        .join(ch_unphased, by: [0, 1])
                        .set{ch_embed}
    //
    // MODULE:EMBED_HAPLOTYPES 
    // 
    // beagle_embed_haplotypes_vcf.py, Run for Chr 1-22 and chrX if female
    EMBED_HAPLOTYPES(
        ch_embed,
        chr_prefix
    )
    versions = versions.mix(EMBED_HAPLOTYPES.out.versions)

    //
    // MODULE:GROUP_HAPLOTYPES 
    // 
    // group_haplotypes.pg ,Run for Chr 1-22 chrX if female
    GROUP_HAPLOTYPES(
        EMBED_HAPLOTYPES.out.phased_vcf,
        chr_prefix
    )
    versions = versions.mix(GROUP_HAPLOTYPES.out.versions)

    GROUP_HAPLOTYPES.out.haplogroups
                        .join(haploblock_x)
                        .groupTuple()
                        .set{ch_haploblocks}
                        
    // if sample is male phased_vcf_x will be used as mock otherwise it is already in phased_vcf
    EMBED_HAPLOTYPES.out.phased_vcf
                        .groupTuple()
                        .join(phased_vcf_x)
                        .set{phased_all}
    all_snp_ch = sample_ch.map {it -> tuple( it[0], it[8], it[9])}
    phased_all.map {it -> tuple( it[0], it[2], it[4])}
                .join(all_snp_ch, by: [0])
                .set{phasedvcf_ch}
    
    //// haplotypes.sh ////

    //
    // MODULE: ADD_HAPLOTYPES
    //
    // add_haplotypes.py, merge chromosomes and add haplogroups
    ADD_HAPLOTYPES(
        phasedvcf_ch
    )
    versions          = versions.mix(ADD_HAPLOTYPES.out.versions)
    ch_snp_haplotypes = ADD_HAPLOTYPES.out.snp_haplotypes
    ///// createcontrolbafplots.sh /////

    // 
    // MODULE: CREATE_BAF_PLOTS
    //
    sexfile = sample_ch.map {it -> tuple( it[0], it[7])}
    CREATE_BAF_PLOTS(
        ch_snp_haplotypes.join(sexfile),
        chrlength
    )
    versions          = versions.mix(CREATE_BAF_PLOTS.out.versions)

    emit:
    versions
    ch_snp_haplotypes
    ch_haploblocks
    
}