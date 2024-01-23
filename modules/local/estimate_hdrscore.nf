process ESTIMATE_HDRSCORE {
    tag "$meta.id"
    label 'process_single'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v5':'kubran/odcf_aceseqcalling:v5' }"

    input:
    tuple val(meta) , path(json), path(txt_files), path(sexfile)
    each path(blacklist)
    each path(centromers)
    each path(cytobands)
    val(chr_prefix)

    output:
    tuple val(meta), path("*.txt")        , emit: txt
    path  "versions.yml"                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def chrprefix = chr_prefix == "chr" ?: "no"

    """
    estimateHRDScore.sh \\
        -p $prefix \\
        -i $json \\
        -m $params.legacyMode \\
        -b $blacklist \\
        -s $sexfile \\
        -c $centromers \\
        -y $cytobands \\
        -x $chrprefix

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python2 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
