//
// SNVCALL: RUN 
//

params.options = [:]

include { DEFINE_BREAKPOINTS   } from '../../modules/local/define_breakpoints.nf'   addParams( options: params.options )
include { ADD_SVS              } from '../../modules/local/add_svs.nf'              addParams( options: params.options )
include { ADD_CREST            } from '../../modules/local/add_crest.nf'            addParams( options: params.options )
include { PSCBS_SEGMENTATION   } from '../../modules/local/pscbs_segmentation.nf'   addParams( options: params.options )
include { HOMOZYGOUS_DELETIONS } from '../../modules/local/homozygous_deletions.nf' addParams( options: params.options )
include { CLUSTER_SEGMENTS     } from '../../modules/local/cluster_segments.nf'     addParams( options: params.options )
include { ESTIMATE_PEAKS       } from '../../modules/local/estimate_peaks.nf'       addParams( options: params.options )
include { SEGMENTS_TO_DATA as SEGMENTS_TO_HOMODEL } from '../../modules/local/segments_to_data.nf'     addParams( options: params.options )
include { SEGMENTS_TO_DATA as SEGMENTS_TO_SNP     } from '../../modules/local/segments_to_data.nf'     addParams( options: params.options )


workflow GET_BREAKPOINTS_SEGMENTS {
    take:
    ch_corr_win     // channel: [val(meta), path(cnv_corrected_win tab.gz)]
    ch_corr_qual    // channel: [val(meta), path(cnv_corrected_qual tab)]
    snp_pos_haplo   // channel: [val(meta), path(snp haplotypes tab.gz), path(index)]
    haploblocks_chr // channel: [val(meta), path(haploblock_chr1), path(haploblock_chr2), ...]
    sex_file        // channel: [val(meta), path(sexfile)]
    centromers      // channel: centromers.txt
    chrlength       // channel: [[chr, region], [chr, region], ...]
    mappability     // channel: [mappability, index]

    main:
    versions = Channel.empty()

    //// datatablePSCBSgaps.sh ////
    
    //
    // MODULE:DEFINE_BREAKPOINTS 
    //
    // RUN datatable_and_PSCBSgaps.R to define breakpoints and segments
    ch_corr_win.join(snp_pos_haplo)
                .join(sex_file)
                .set{input_ch}

    DEFINE_BREAKPOINTS(
        input_ch,
        centromers
    )
    versions    = versions.mix(DEFINE_BREAKPOINTS.out.versions)

    ///////// This will only run if there are SVs to add !!!! 
    //////// For now this is not functional


    ////PSCBSgaps_SV.sh ////

    //
    // MODULE:ADD_SVS 
    //
    // RUN PSCBSgabs_plus_sv_points.py to add SVs to PSCBSgaps

    sv_ch = DEFINE_BREAKPOINTS.out.known_segments.map {it -> tuple( it[0], it[1], [])}   
    ADD_SVS(
        sv_ch
    )
    versions    = versions.mix(ADD_SVS.out.versions)

    //// mergePSCBSCrest.sh ////
    //
    // MODULE:ADD_CREST
    //
    // Run PSCBSgabs_plus_CRESTpoints.py
    crest_ch = ADD_SVS.out.pscbs.map {it -> tuple( it[0], it[1], it[2], [], [])} 
    ADD_CREST(
        crest_ch
    )
    versions    = versions.mix(ADD_CREST.out.versions)

    //// PSCBSall.sh ////
    //
    // MODULE:PSCBS_SEGMENTATION
    //
    // Run pscbs_all.R
    
    ADD_CREST.out.pscbs.join(DEFINE_BREAKPOINTS.out.pscbs_data)
                        .join(DEFINE_BREAKPOINTS.out.libloc)
                        .set{pscbs_ch}

    PSCBS_SEGMENTATION(
        pscbs_ch,
        chrlength
    )
    versions    = versions.mix(PSCBS_SEGMENTATION.out.versions)

    //// homozygDel.sh  ////
    //
    // MODULE: HOMOZYGOUS_DELETIONS
    //
    // Run annotate_vcf.pl, addMappability.py and homozygous_deletions.pl
    
    HOMOZYGOUS_DELETIONS(
        PSCBS_SEGMENTATION.out.segments,
        mappability
    )
    versions    = versions.mix(HOMOZYGOUS_DELETIONS.out.versions)

    //// segmentsDataHomoDel.sh  ////
    //
    // MODULE: SEGMENTS_TO_DATA
    //
    // Run segments_to_data.py

    SEGMENTS_TO_HOMODEL(
        HOMOZYGOUS_DELETIONS.out.homdels.join(DEFINE_BREAKPOINTS.out.pscbs_data)
    )
    versions    = versions.mix(SEGMENTS_TO_HOMODEL.out.versions)

    //// clusteredPrunedNormal.sh ////
    //
    // MODULE: CLUSTER_SEGMENTS
    //
    SEGMENTS_TO_HOMODEL.out.all_seg.join(HOMOZYGOUS_DELETIONS.out.homdels)
                                .join(sex_file)
                                .join(ch_corr_qual)
                                .join(haploblocks_chr)
                                .set{all_seg_ch}

    all_seg_ch.view()
    CLUSTER_SEGMENTS(
        all_seg_ch,
        chrlength
    )
    versions    = versions.mix(CLUSTER_SEGMENTS.out.versions)

    //// segmentsprunednormal.sh ////
    //
    // MODULE: SEGMENTS_TO_DATA
    //
    // Run segments_to_data.py

    CLUSTER_SEGMENTS.out.clustered_segments
                        .join(CLUSTER_SEGMENTS.out.all_segments2)
                        .set{segments_ch}
    SEGMENTS_TO_SNP(
        segments_ch
    )

    //// purityPloidity.sh ////
    //
    // MODULE: ESTIMATE_PEAKS
    //
    //
    SEGMENTS_TO_SNP.out.all_seg
                        .join(CLUSTER_SEGMENTS.out.clustered_segments)
                        .join(sex_file)
                        .set{segments2_ch}

    ESTIMATE_PEAKS(
        segments2_ch
    )
    versions    = versions.mix(ESTIMATE_PEAKS.out.versions)


    emit:
    versions
}
