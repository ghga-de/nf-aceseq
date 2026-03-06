//
// SEGMENTATION:
//
include { DEFINE_BREAKPOINTS     } from '../../modules/local/define_breakpoints.nf'
include { ADD_SVS                } from '../../modules/local/add_svs.nf'
include { ADD_CREST              } from '../../modules/local/add_crest.nf'
include { PSCBS_SEGMENTATION     } from '../../modules/local/pscbs_segmentation.nf'
include { HOMOZYGOUS_DELETIONS   } from '../../modules/local/homozygous_deletions.nf'
include { CLUSTER_SEGMENTS       } from '../../modules/local/cluster_segments.nf'
include { SEGMENTS_TO_DATA as SEGMENTS_TO_HOMODEL } from '../../modules/local/segments_to_data.nf'
include { SEGMENTS_TO_DATA as SEGMENTS_TO_SNP     } from '../../modules/local/segments_to_data.nf'


workflow SEGMENTATION {
    take:
    ch_sv           // channel: [val(meta), path(sv)]
    gc_corr_win     // channel: [val(meta), path(cnv_corrected_win tab.gz)]
    gc_corr_qual    // channel: [val(meta), path(cnv_corrected_qual tab)]
    snp_pos_haplo_wg// channel: [val(meta), path(snp haplotypes tab.gz), path(index)]
    haploblocks_chr // channel: [val(meta), path(haploblock_chr1), path(haploblock_chr2), ...]
    sex_file        // channel: [val(meta), path(sexfile)]
    centromers      // channel: centromers.txt
    chrlength       // channel: [[chr, region], [chr, region], ...]
    mappability     // channel: [mappability, index]
    chr_prefix

    main:
    versions = Channel.empty()

    // clean meta.sex as it may mismatch after fix!
    gc_corr_win = gc_corr_win.map { meta, files ->
            def clean_meta = meta.findAll { key, value -> key != 'sex' }
            return [ clean_meta, files ]
    }
    snp_pos_haplo_wg = snp_pos_haplo_wg.map { meta, file, index ->
            def clean_meta = meta.findAll { key, value -> key != 'sex' }
            return [ clean_meta, file, index ]
    }
    sex_file = sex_file.map { meta, file ->
            def clean_meta = meta.findAll { key, value -> key != 'sex' }
            return [ clean_meta, file ]
    }
    ch_sv = ch_sv.map { meta, file ->
            def clean_meta = meta.findAll { key, value -> key != 'sex' }
            return [ clean_meta, file ]
    }   
    gc_corr_qual = gc_corr_qual.map { meta, file ->
            def clean_meta = meta.findAll { key, value -> key != 'sex' }
            return [ clean_meta, file ]
    }  

    //// datatablePSCBSgaps.sh ////
    //
    // MODULE:DEFINE_BREAKPOINTS 
    //
    // RUN datatable_and_PSCBSgaps.R to define breakpoints and segments
    gc_corr_win.join(snp_pos_haplo_wg)
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
    // ADD_SNV and ADD_CREST suppose to add SV data if available and id allowMissingSV flag is not off. 
    // Otherwise it preduces empty svs file with copied breakpoints.
    //
    // MODULE:ADD_SVS 
    //
    // RUN PSCBSgabs_plus_sv_points.py to add SVs to PSCBSgaps
    ADD_SVS(
        ch_sv.join(DEFINE_BREAKPOINTS.out.known_segments)
    )
    versions    = versions.mix(ADD_SVS.out.versions)

    //// mergePSCBSCrest.sh ////
    //
    // MODULE:ADD_CREST
    //
    // Run PSCBSgabs_plus_CRESTpoints.py
    // I couldnt find an example on how to run this, so it doesnt work really.
    ch_sv_points = ADD_SVS.out.sv_points
    ch_sv.join(ch_sv_points)
        .join(ADD_SVS.out.breakpoints)
                .map {it -> tuple( it[0], it[1], it[2], it[3], [], [])} 
                .set{crest_ch}
    ADD_CREST(
        crest_ch
    )
    versions    = versions.mix(ADD_CREST.out.versions)

    //// PSCBSall.sh ////
    //
    // MODULE:PSCBS_SEGMENTATION
    //
    // Run pscbs_all.R

    PSCBS_SEGMENTATION(
        ADD_CREST.out.breakpoints.join(DEFINE_BREAKPOINTS.out.pscbs_data),
        chrlength
    )
    versions    = versions.mix(PSCBS_SEGMENTATION.out.versions)

    //// homozygDel.sh  ////
    //
    // MODULE: HOMOZYGOUS_DELETIONS
    //
    // Run annotate_vcf.pl, addMappability.py and homozygous_deletions.pl
    
    HOMOZYGOUS_DELETIONS(
        PSCBS_SEGMENTATION.out.segments.join(ch_sv_points),
        mappability
    )
    versions    = versions.mix(HOMOZYGOUS_DELETIONS.out.versions)

    //// segmentsDataHomoDel.sh  ////
    //
    // MODULE: SEGMENTS_TO_DATA
    //
    // Run segments_to_data.py

    SEGMENTS_TO_HOMODEL(
        HOMOZYGOUS_DELETIONS.out.segments_w_homodel.join(DEFINE_BREAKPOINTS.out.pscbs_data),
        1
    )
    versions    = versions.mix(SEGMENTS_TO_HOMODEL.out.versions)
    all_snp_update1 = SEGMENTS_TO_HOMODEL.out.all_seg

    //// clusteredPrunedNormal.sh ////
    //
    // MODULE: CLUSTER_SEGMENTS
    //
    all_snp_update1.join(HOMOZYGOUS_DELETIONS.out.segments_w_homodel)
                    .join(sex_file)
                    .join(gc_corr_qual)
                    .join(haploblocks_chr)
                    .set{all_seg_ch}
    
    CLUSTER_SEGMENTS(
        all_seg_ch,
        chrlength,
        chr_prefix
    )
    versions              = versions.mix(CLUSTER_SEGMENTS.out.versions)
    ch_clustered_segments = CLUSTER_SEGMENTS.out.clustered_segments

    //// segmentsprunednormal.sh ////
    //
    // MODULE: SEGMENTS_TO_DATA
    //
    // Run segments_to_data.py

    ch_clustered_segments
                    .join(CLUSTER_SEGMENTS.out.snp_update2)
                    .set{segments_ch}

    SEGMENTS_TO_SNP(
        segments_ch,
        3
    )
    ch_all_snp_update3 = SEGMENTS_TO_SNP.out.all_seg

    emit:
    ch_clustered_segments
    ch_sv_points
    ch_all_snp_update3
    versions
}
