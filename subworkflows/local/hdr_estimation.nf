//
// HDR_ESTIMATION: RUN  estimateHDRscore.sh
//

params.options = [:]
include { ESTIMATE_HDRSCORE       } from '../../modules/local/estimate_hdrscore.nf'

workflow HDR_ESTIMATION {
    take:
    json_report   // channel: [val(meta), path(.json)]
    hdr_files     // channel: [val(meta), [path(.txt), path(.txt)..]]
    blacklist     // channel: [blacklist.txt]
    sexfile       // channel: [val(meta), path(sexfile.txt)]
    centromers    // channel: [centromers.txt] 
    cytobands     // channel: [cytobands.txt]
    chrprefix     // channel: [chromosome prefix value]


    main:
    versions = Channel.empty()

    sexfile = sexfile.map { meta, file ->
            def clean_meta = meta.findAll { key, value -> key != 'sex' }
            return [ clean_meta, file ]
    } 
    //
    // MODULE:ESTIMATE_HDRSCORE
    //
    // RUN parseJson.py
    input_ch =  json_report.join(hdr_files)
    ESTIMATE_HDRSCORE(
        input_ch.join(sexfile),
        blacklist,
        centromers,
        cytobands,
        chrprefix
    )
    versions  = versions.mix(ESTIMATE_HDRSCORE.out.versions) 

    emit:
    versions
}
