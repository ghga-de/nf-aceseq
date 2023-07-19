import groovy.json.JsonSlurper
process READ_JSON {
    tag "$meta.id"
    label 'process_single'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v4':'kubran/odcf_aceseqcalling:v4' }"

    input:
    tuple val(meta) , val(inputJsonPath)

    output:
    tuple val(meta), val(metaMap), emit: metaMap

    when:
    task.ext.when == null || task.ext.when

    exec:
    // println ">>> READ_JSON inputJsonPath: ${inputJsonPath}"
    contents = file(inputJsonPath).text
    // NOTE: why doesnt this work??? ;  // File file_obj = new File("${inputJsonPath}")
    // println ">>> READ_JSON contents: ${contents}"
    metaMap = new JsonSlurper().parseText(contents)
    println ">>> READ_JSON metaMap: ${metaMap}"
}

