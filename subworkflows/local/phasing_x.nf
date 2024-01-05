//
// PHASING_X: RUN phasing.sh by intervals for FEMALE samples
//
// Running beagle requires a directory of references, prepended with chr name. That needs to be changed!

params.options = [:]

include { BCFTOOLS_MPILEUP    } from '../../modules/nf-core/bcftools/mpileup/main.nf' addParams( options: params.options )
include { CREATE_FAKE_SAMPLES } from '../../modules/local/create_fake_samples.nf'     addParams( options: params.options )
include { EMBED_HAPLOTYPES    } from '../../modules/local/embed_haplotypes.nf'        addParams( options: params.options )
include { GROUP_HAPLOTYPES    } from '../../modules/local/group_haplotypes.nf'        addParams( options: params.options )
include { ADD_HAPLOTYPES      } from '../../modules/local/add_haplotypes.nf'          addParams( options: params.options )
include { CREATE_BAF_PLOTS    } from '../../modules/local/create_baf_plots.nf'        addParams( options: params.options )
include { BEAGLE5_BEAGLE      } from '../../modules/nf-core/beagle/main.nf'           addParams( options: params.options )
include { GET_GENOTYPES       } from '../../modules/local/get_genotypes.nf'           addParams( options: params.options )
include { CREATE_UNPHASED     } from '../../modules/local/create_unphased.nf'         addParams( options: params.options )


workflow PHASING_X {
    take:
    sample_ch     // channel: [val(meta), tumor, tumor_bai, control, control_bai, sex_file, all_snp_ch, all_snp_ch_index]
    ref           // channel: [path(fasta), path(fai)]
    chrlength     // channel: [[chr, region], [chr, region], ...]
    beagle_ref    // channel: directory
    beagle_map    // channel: directory
    dbsnp         // channel: [path(dbsnp), path(index)]
    chr_prefix    // channel: val: chr|""

    main:
    versions     = Channel.empty()
    ch_unphased  = Channel.empty()
    ch_all_snp   = Channel.empty()
    // Combine intervals with samples to create 'interval x sample' number of parallel run
    intervals  = chrlength.splitCsv(sep: '\t', by:1)
    
    //// phasing_X.sh ////

    /////// Female workflow - Run for chr1-22 and chrX /////////
    // Prepare intervals
    // filter out both X and Y if gender is Male!
    intervals.take(23)
            .set{intervals_ch}
    sample_ch
        .combine(intervals_ch)
        .set { combined_inputs }

    combined_inputs = combined_inputs.map {it -> tuple( it[0], it[1], it[2], it[3], it[4],it[8])}

    combined_inputs.branch{
        control: it[0].iscontrol == "1"
        nocontrol: it[0].iscontrol == "0"}
        .set{input_ch}

    sample_ch.map{it -> tuple( it[0],it[6],it[7])}
                    .set{all_snp}

    all_snp.branch{
        control: it[0].iscontrol == "1"
        nocontrol: it[0].iscontrol == "0"}
        .set{all_snp_ch}

    ch_all_snp = ch_all_snp.mix(all_snp_ch.control)
    //// estimateGenotypes.sh  //////

    //
    // MODULE: GET_GENOTYPES
    //
        
    GET_GENOTYPES(
        all_snp_ch.nocontrol
    )
    versions = versions.mix(GET_GENOTYPES.out.versions)
    fake_snp_ch = GET_GENOTYPES.out.fake_snp
    ch_all_snp  = ch_all_snp.mix(fake_snp_ch)
    //// createUnphasedFiles.sh /////

    CREATE_UNPHASED(
        fake_snp_ch,
        dbsnp,
        chr_prefix
    )
    unphased  = CREATE_UNPHASED.out.unphased
    versions = versions.mix(CREATE_UNPHASED.out.versions)
        
    unphased_ch = unphased.transpose()       
    unphased_ch.combine(intervals_ch)
        .filter{it[1].name.contains("unphased_"+it[2]+".")}
        .map{it -> tuple(it[2],it[0], it[1])}
        .set{unphased}
        
    ch_unphased = ch_unphased.mix(unphased)

    //
    // MODULE:BCFTOOLS_MPILEUP 
    //
    // RUN bcftools mpileup to call variants. This process is scattered by chr intervals (only for chr1-22)
    // in OTP running pipeline samtools mpileup is used!
    BCFTOOLS_MPILEUP (
        input_ch.control, 
        ref
    )
    versions    = versions.mix(BCFTOOLS_MPILEUP.out.versions)
    ch_unphased = ch_unphased.mix(BCFTOOLS_MPILEUP.out.vcf)
    
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
    // Run beagle for Chr 1-22 and chrX if female
    // OTP runs have impute working! Beagle is new. 
    BEAGLE5_BEAGLE(
        CREATE_FAKE_SAMPLES.out.unphased_vcf,
        beagle_ref,
        beagle_map,
        chr_prefix
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
                        .groupTuple()
                        .set{ch_haploblocks}
    EMBED_HAPLOTYPES.out.phased_vcf
                        .groupTuple()
                        .set{phased_all}

    phased_all.map {it -> tuple( it[0], it[2], it[4])}
                .join(ch_all_snp, by: [0])
                .set{phasedvcf_ch}

    phasedvcf_ch = phasedvcf_ch.map {it -> tuple( it[0], it[1], [], it[3], it[4])}
    
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
    
    if (params.createbafplots){
        ///// createcontrolbafplots.sh /////

        // 
        // MODULE: CREATE_BAF_PLOTS
        //

        ch_snp_haplotypes.branch{
            control: it[0].iscontrol == "1"
            nocontrol: it[0].iscontrol == "0"}
            .set{snp_hap}

        sexfile = sample_ch.map {it -> tuple( it[0], it[5])}
        CREATE_BAF_PLOTS(
            snp_hap.control.join(sexfile),
            chrlength
        )
        versions          = versions.mix(CREATE_BAF_PLOTS.out.versions)
    }

    ch_haploblocks = ch_haploblocks.map {it -> tuple( it[0], it[1], [])}

    emit:
    versions
    ch_snp_haplotypes
    ch_haploblocks
    
}
