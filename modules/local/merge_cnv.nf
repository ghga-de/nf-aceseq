process MERGE_CNV {
    tag "$meta.id"
    label 'process_single'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_mpileupsnvcalling:v0':'kubran/odcf_mpileupsnvcalling:v0' }"

    input:
    tuple val(meta)        , path(cnv)

    output:
    tuple val(meta), path("*.anno.tab.gz")  , emit: cnv 
    path  "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    merge_and_filter_cnv.py \\
        --inputpath "${prefix}.chr" \\
        --inputsuffix ".cnv.anno.tab.gz" \\
        --output ${prefix}.cnv.anno.tab.gz \\
        --coverage $params.cnv_min_coverage \\
        --mappability $params.mapping_quality \\
        --NoOfWindows  $params.min_windows 

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python2 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
