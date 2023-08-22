//
// HDR_ESTIMATION: RUN  estimateHDRscore.sh
//

params.options = [:]
include { READ_JSON        } from '../../modules/local/read_json.nf'               addParams( options: params.options )
include { PARSE_JSON       } from '../../modules/local/parse_json.nf'              addParams( options: params.options )

import groovy.json.JsonSlurper

workflow HDR_ESTIMATION {
    take:
    json_report   // channel: [val(meta), path(.json)]
    hdr_files     // channel: [val(meta), [path(.txt), path(.txt)..]]
    blacklist     // channel: [blacklist.txt]
    sexfile       // channel: [val(meta), path(sexfile.txt)]
    centromers    // channel: [centromers.txt] 
    cytobands     // channel: [cytobands.txt]


    main:
    versions = Channel.empty()

    //
    // MODULE:PARSE_JSON
    //
    // RUN parseJson.py
   input_ch =  json_report.join(hdr_files)
    PARSE_JSON(
        input_ch.join(sexfile),
        blacklist,
        centromers,
        cytobands
    )
    versions  = versions.mix(PARSE_JSON.out.versions) 

    emit:
    versions
}
