process PREPARE_BEAGLE_REF {
    tag "$meta.id"
    label 'process_single'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v5':'kubran/odcf_aceseqcalling:v5' }"

    input:
    tuple val(meta), path(dir)
    val(name)

    output:
    path(name)   , emit: dir

    when:
    task.ext.when == null || task.ext.when

    script:

    """
    mkdir $name
    cp *chr* $name/
    """

}
