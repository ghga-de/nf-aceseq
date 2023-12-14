//
// PURITY_EVALUATION: RUN plots.sh
//

params.options = [:]

include { ESTIMATE_PEAKS         } from '../../modules/local/estimate_peaks.nf'         addParams( options: params.options )
include { ESTIMATE_PURITY_PLOIDY } from '../../modules/local/estimate_purity_ploidy.nf' addParams( options: params.options )
include { GENERATE_PLOTS         } from '../../modules/local/generate_plots.nf'     addParams( options: params.options )
include { PURITY_PLOIDY          } from '../../modules/local/purity_ploidy.nf'         addParams( options: params.options )


workflow PURITY_EVALUATION {
    take:
    clustered_segments // channel: [val(meta), seg.txt.gz, seg.txt.gz.tbi]
    sv_points          // channel: [val(meta), cnv_positions]
    all_snp_update3    // channel: [val(meta), seg.txt.gz, seg.txt.gz.tbi]
    sex_file           // channel: val(meta), sex_file.txt]
    all_corrected      // channel: [val(meta), all_corrected.txt.gz]
    chrlength          // channel: chrom lenght

    main:
    versions = Channel.empty()

        //// purityPloidity.sh ////
    //
    // MODULE: ESTIMATE_PEAKS
    //
    //
    //Run purity_ploidy.R
    all_snp_update3
                .join(clustered_segments)
                .join(sex_file)
                .set{segments2_ch}

    ESTIMATE_PEAKS(
        segments2_ch
    )
    versions           = versions.mix(ESTIMATE_PEAKS.out.versions)
    ch_segment_w_peaks = ESTIMATE_PEAKS.out.segment_w_peaks

    //purityPloidity_EstimateFinal.sh
    //
    // MODULE: ESTIMATE_PURITY_PLOIDY
    //
    //Run purity_ploidy_estimation_final.R

    ESTIMATE_PURITY_PLOIDY(
        ch_segment_w_peaks.join(sex_file)
    )
    versions    = versions.mix(ESTIMATE_PURITY_PLOIDY.out.versions)

    ch_purity_ploidy = ESTIMATE_PURITY_PLOIDY.out.purity_ploidy
    
    ///// plots.sh ////
    all_snp_update3.join(sv_points)
                    .join(ch_segment_w_peaks)
                    .join(ch_purity_ploidy)
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
    hdr_files = GENERATE_PLOTS.out.hdr_estimate_files
    versions  = versions.mix(GENERATE_PLOTS.out.versions)

    //
    // MODULE: PURITY_PLOIDY
    //
    // Run getFinalPurityPloidy.py
    PURITY_PLOIDY(
        ch_purity_ploidy.join(GENERATE_PLOTS.out.cnv_params)
    )
    json_report = PURITY_PLOIDY.out.json

    emit:
    json_report
    hdr_files
    versions
}
