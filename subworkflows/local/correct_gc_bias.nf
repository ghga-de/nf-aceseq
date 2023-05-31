//
// CORRECT_GC_BIAS: RUN 
//

params.options = [:]

include { GC_BIAS         } from '../../modules/local/gc_bias.nf'           addParams( options: params.options )
include { CONVERT_TO_JSON } from '../../modules/local/convert_to_json.nf'   addParams( options: params.options )


workflow CORRECT_GC_BIAS {
    take:
    cnv_pos       // channel: [val(meta), cnv_positions]
    rep_time      // channel: [path(fasta), path(fai)]
    chrlength     // channel: chrom lenght
    gc_content    // channel: gc content file

    main:
    versions = Channel.empty()
    
    ///// correct_gc_bias.sh ////

    //
    // MODULE: GC_BIAS
    //
    // Run correctGCBias.R 
    GC_BIAS(
        cnv_pos,
        rep_time,
        chrlength,
        gc_content,
    )
    qual_corrected    = GC_BIAS.out.corrected_quality
    windows_corrected = GC_BIAS.out.corrected_windows
    versions          = versions.mix(GC_BIAS.out.versions)

    //
    // MODULE: CONVERT_TO_JSON
    //
    // Run convertTabToJson.py

    CONVERT_TO_JSON(
        GC_BIAS.out.gc
    )
    versions = versions.mix(CONVERT_TO_JSON.out.versions)

    emit:
    versions
    qual_corrected
    windows_corrected
}
