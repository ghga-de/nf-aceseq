process SEGMENTS_TO_DATA {
    tag "$meta.id"
    label 'process_single'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v0':'kubran/odcf_aceseqcalling:v0' }"

    input:
    tuple val(meta) , path(homdel_segments), path(pscbs_data), path(index2)

    output:
    tuple val(meta), path("*seg.txt.gz"), emit: all_seg
    path  "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    segments_to_data.py \\
        --pscbs  $pscbs_data \\
        --input  $homdel_segments \\
        --output ${prefix}_all_seg.txt.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python2 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
