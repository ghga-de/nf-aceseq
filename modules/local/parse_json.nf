process PARSE_JSON {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v4':'kubran/odcf_aceseqcalling:v4' }"

    input:
    tuple val(meta) , path(json), path(sexfile)
    path(blacklist)
    path(centromers)

    output:
    tuple val(meta), path("*.txt"), emit: txt
    path  "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    estimateHRDScore.sh \\
        -p $prefix \\
        -i $json \\
        -m $params.legacyMode \\
        -b $blacklist \\
        -s $sexfile \\
        -c $centromers 

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python2 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
