//
// PHASING: RUN phasing.sh by intervals
//
// Running beagle requires a directory of references, prepended with chr name. That needs to be changed!

params.options = [:]

include { BCFTOOLS_MPILEUP as BCFTOOLS_MPILEUP_G   } from '../../modules/nf-core/bcftools/mpileup/main.nf' addParams( options: params.options )
include { BCFTOOLS_MPILEUP as BCFTOOLS_MPILEUP_X   } from '../../modules/nf-core/bcftools/mpileup/main.nf' addParams( options: params.options )
include { MAKE_MOCK as MAKE_MOCK_1                 } from '../../modules/local/make_mock.nf'               addParams( options: params.options )
include { MAKE_MOCK as MAKE_MOCK_2                 } from '../../modules/local/make_mock.nf'               addParams( options: params.options )
include { CREATE_FAKE_SAMPLES } from '../../modules/local/create_fake_samples.nf'     addParams( options: params.options )
include { EMBED_HAPLOTYPES    } from '../../modules/local/embed_haplotypes.nf'        addParams( options: params.options )
include { GROUP_HAPLOTYPES    } from '../../modules/local/group_haplotypes.nf'        addParams( options: params.options )
include { ADD_HAPLOTYPES      } from '../../modules/local/add_haplotypes.nf'          addParams( options: params.options )
include { CREATE_BAF_PLOTS    } from '../../modules/local/create_baf_plots.nf'        addParams( options: params.options )
include { BEAGLE5_BEAGLE      } from '../../modules/nf-core/beagle/main.nf'           addParams( options: params.options )


workflow PHASING {
    take:
    sample_ch     // channel: [val(meta), tumor, tumor_bai, control, control_bai, tumorname, controlname, sex.txt]
    all_snp_ch    // channel: [val(meta), path(..snp.tab.gz)]
    ref           // channel: [path(fasta), path(fai)]
    chrlength     // channel: [[chr, region], [chr, region], ...]
    beagle_ref    // channel: directory
    beagle_map    // channel: directory
    dbsnp         // channel: [path(dbsnp), path(index)]

    main:
    versions     = Channel.empty()
    ch_unphased  = Channel.empty()

    // Combine intervals with samples to create 'interval x sample' number of parallel run
    intervals  = chrlength.splitCsv(sep: '\t', by:1)
    
    // brach samples for sexes
    // discuss about klinefelter case (XXY)
    sample_ch.branch{
        male:  it[7].readLines().get(0) == "male"
        female: it[7].readLines().get(0) == "female|klinefelter"
        other: true}
        .set{sex}


    /////// Female workflow - Run for chr1-22 and chrX /////////
    // Prepare intervals
    // filter out both X and Y if gender is Male!
    intervals.take(23)
            .set{intervals_ch}
    sex.female
        .combine(intervals_ch)
        .set { combined_inputs_female }

    combined_inputs_female = combined_inputs_female.map {it -> tuple( it[0], it[1], it[2], it[3], it[4],it[8])}
    //
    // MODULE:BCFTOOLS_MPILEUP 
    //
    // RUN bcftools mpileup to call variants. This process is scattered by chr intervals (only for chr1-22)
    // in OTP running pipeline samtools mpileup is used!
    BCFTOOLS_MPILEUP_X (
        combined_inputs_female, 
        ref
    )
    versions    = versions.mix(BCFTOOLS_MPILEUP_X.out.versions)
    ch_unphased = ch_unphased.mix(BCFTOOLS_MPILEUP_X.out.vcf)

    // Prepare moch haploblock file for chrX
    MAKE_MOCK_1(
        BCFTOOLS_MPILEUP_X.out.vcf,
        "female"
    )
    ch_sample_g = MAKE_MOCK_1.out.sample_g

    //// Male Workflow ////
    // filter out both X and Y if gender is Male!
    intervals.take(22)
            .set{intervals_ch}
    sex.male
        .combine(intervals_ch)
        .set { combined_inputs_male }
    combined_inputs_male = combined_inputs_male.map {it -> tuple( it[0], it[1], it[2], it[3], it[4],it[8])} 
    //
    // MODULE:BCFTOOLS_MPILEUP 
    //
    // RUN samtools mpileup to call variants. This process is scattered by chr intervals (only for chr1-22)
    BCFTOOLS_MPILEUP_G (
        combined_inputs_male, 
        ref
    )
    versions    = versions.mix(BCFTOOLS_MPILEUP_G.out.versions)
    ch_unphased = ch_unphased.mix(BCFTOOLS_MPILEUP_G.out.vcf)

    // Prepare moch haploblock file for chrX
    MAKE_MOCK_2(
        BCFTOOLS_MPILEUP_G.out.vcf,
        "male"
    )
    haploblock_x = MAKE_MOCK_2.out.haploblock
    phased_vcf_x = MAKE_MOCK_2.out.phased_vcf

    //// Remaning is the same
        
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
    BEAGLE5_BEAGLE(
        CREATE_FAKE_SAMPLES.out.unphased_vcf,
        beagle_ref,
        beagle_map
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
        ch_embed
    )
    versions = versions.mix(EMBED_HAPLOTYPES.out.versions)

    //
    // MODULE:GROUP_HAPLOTYPES 
    // 
    // group_haplotypes.pg ,Run for Chr 1-22 chrX if female
    GROUP_HAPLOTYPES(
        EMBED_HAPLOTYPES.out.phased_vcf
    )
    haplogroups_ch = GROUP_HAPLOTYPES.out.haplogroups
    versions = versions.mix(GROUP_HAPLOTYPES.out.versions)

    // if sample is male phased_vcf_x will be used as mock otherwise it is already in phased_vcf
    // warn: experimental: if sample is female phased_vcf_x will be an empty channel!.
    EMBED_HAPLOTYPES.out.phased_vcf
                        .groupTuple()
                        .join(phased_vcf_x)
                        .set{phased_all}

    phased_all.map {it -> tuple( it[0], it[2], it[4])}
                .join(all_snp_ch, by: [0])
                .set{haplogroups_ch}
                
    //
    // MODULE: ADD_HAPLOTYPES
    //
    // add_haplotypes.py, merge chromosomes and add haplogroups
    ADD_HAPLOTYPES(
        haplogroups_ch
    )
    versions          = versions.mix(ADD_HAPLOTYPES.out.versions)
    ch_snp_haplotypes = ADD_HAPLOTYPES.out.snp_haplotypes

    // 
    // MODULE: CREATE_BAF_PLOTS
    //
    ch_sex    = sample_ch.map {it -> tuple( it[0],it[7])}
    baf_input = ch_snp_haplotypes.join(ch_sex)
    CREATE_BAF_PLOTS(
        baf_input,
        chrlength
    )
    versions          = versions.mix(CREATE_BAF_PLOTS.out.versions)

    emit:
    versions
    ch_sample_g
    ch_snp_haplotypes
    
}
