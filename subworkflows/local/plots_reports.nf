//
// PLOTS_REPORTS: RUN plots.sh
//

params.options = [:]

include { GENERATE_PLOTS    } from '../../modules/local/generate_plots.nf'     addParams( options: params.options )
include { TAB_TO_CNV        } from '../../modules/local/tab_to_cnv.nf'         addParams( options: params.options )


workflow PLOTS_REPORTS {
    take:
    sv_points        // channel: [val(meta), cnv_positions]
    all_snp_update3  // channel: [val(meta), seg.txt.gz, seg.txt.gz.tbi]
    purity_ploidy    // channel: [val(meta), ploidy_purity_2D.txt'] 
    segment_w_peaks  // channel: val(meta), _combi_level.txt]   
    sex_file         // channel: val(meta), sex_file.txt]
    all_corrected    // channel: [val(meta), all_corrected.txt.gz]
    chrlength        // channel: chrom lenght

    main:
    versions = Channel.empty()
    
    ///// plots.sh ////
    all_snp_update3.join(sv_points)
                    .join(segment_w_peaks)
                    .join(purity_ploidy)
                    .join(sex_file)
                    .join(all_corrected)
                    .set{ch_input}

    //
    // MODULE: GENERATE_PlOTS
    //
    // Run pscbs_plots.R 
    
    GENERATE_PLOTS(
        ch_input,
        chrlength
    )
    versions    = versions.mix(GENERATE_PLOTS.out.versions)

    //
    // MODULE: TAB_TO_CNV
    //
    // Run getFinalPurityPloidy.py
    TAB_TO_CNV(
        purity_ploidy.join(GENERATE_PLOTS.out.cnv_params)
    )
    json_report = TAB_TO_CNV.out.json

    emit:
    json_report
    versions
}
