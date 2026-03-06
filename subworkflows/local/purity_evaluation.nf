//
// PURITY_EVALUATION: RUN plots.sh
//

include { ESTIMATE_PEAKS         } from '../../modules/local/estimate_peaks.nf'
include { ESTIMATE_PURITY_PLOIDY } from '../../modules/local/estimate_purity_ploidy.nf'
include { GENERATE_PLOTS         } from '../../modules/local/generate_plots.nf'
include { PURITY_PLOIDY          } from '../../modules/local/purity_ploidy.nf'


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

    sex_file = sex_file.map { meta, file ->
            def clean_meta = meta.findAll { key, value -> key != 'sex' }
            return [ clean_meta, file ]
    } 

    all_corrected = all_corrected.map { meta, file ->
            def clean_meta = meta.findAll { key, value -> key != 'sex' }
            return [ clean_meta, file ]
    }   
    //// purityPloidity.sh ////
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
    // Run pscbs_plots.R 
    
    GENERATE_PLOTS(
        ch_input,
        chrlength
    )
    hrd_files = GENERATE_PLOTS.out.hrd_estimate_files
    versions  = versions.mix(GENERATE_PLOTS.out.versions)

    // Run getFinalPurityPloidy.py
    PURITY_PLOIDY(
        ch_purity_ploidy.join(GENERATE_PLOTS.out.cnv_params)
    )
    json_report = PURITY_PLOIDY.out.json

    emit:
    json_report
    hrd_files
    versions
}
