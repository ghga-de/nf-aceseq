//
// HDR_ESTIMATION: RUN  estimateHDRscore.sh
//

params.options = [:]
include { ESTIMATE_HRDSCORE       } from '../../modules/local/estimate_hrdscore.nf'              addParams( options: params.options )

workflow HRD_ESTIMATION {
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

    //
    // MODULE:ESTIMATE_HRDSCORE
    //
    // RUN parseJson.py
    input_ch =  json_report.join(hdr_files)
    ESTIMATE_HRDSCORE(
        input_ch.join(sexfile),
        blacklist,
        centromers,
        cytobands,
        chrprefix
    )
    versions  = versions.mix(ESTIMATE_HRDSCORE.out.versions) 

    emit:
    versions
}
