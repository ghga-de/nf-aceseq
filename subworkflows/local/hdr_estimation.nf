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
    blacklist     // channel: [blacklist.txt]
    sexfile       // channel: [val(meta), path(sexfile.txt)]
    centromers    // channel: [centromers.txt] 


    main:
    versions = Channel.empty()

    //
    // MODULE:PARSE_JSON
    //
    // RUN parseJson.py
    PARSE_JSON(
        json_report.join(sexfile),
        blacklist,
        centromers
    )
    versions  = versions.mix(PARSE_JSON.out.versions) 

    //
    // MODULE:READ_JSON
    //
    READ_JSON(
        json_report
    )

    ch_sol = READ_JSON.out.metaMap

    ch_sol.view()



    emit:
    versions
}
