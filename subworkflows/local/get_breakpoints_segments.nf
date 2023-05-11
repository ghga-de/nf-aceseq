//
// SNVCALL: RUN 
//

params.options = [:]

include { DEFINE_BREAKPOINTS } from '../../modules/local/define_breakpoints.nf'           addParams( options: params.options )


workflow GET_BREAKPOINTS_SEGMENTS {
    take:
    ch_corr_win     // channel: [val(meta), path(cnv_corrected_win tab.gz)]
    snp_pos_haplo   // channel: [val(meta), path(snp haplotypes tab.gz), path(index)]
    sex_file        // channel: [val(meta), path(sexfile)]
    centromers      // channel: centromers.txt

    main:
    versions = Channel.empty()

    
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


    emit:
    versions
}
