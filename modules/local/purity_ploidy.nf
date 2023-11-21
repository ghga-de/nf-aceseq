process PURITY_PLOIDY {
    tag "$meta.id"
    label 'process_single'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v5':'kubran/odcf_aceseqcalling:v5' }"

    input:
    tuple val(meta), path(purity_ploidy), path(cnv_params)

    output:
    tuple val(meta), path("*.json")  , emit: json 
    path  "versions.yml"             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    getFinalPurityPloidy.py \\
        --pid   $prefix \\
        --path  .  \\
        --out   ${prefix}_parameter.json \\
        --solutionFile  $purity_ploidy

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python2 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
