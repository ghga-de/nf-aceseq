process GETCHROMSIZES {
    tag "$fasta"
    label 'process_single'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v5':'kubran/odcf_aceseqcalling:v5' }"

    input:
    tuple path(fasta), path(fai)

    output:
    path ("*.sizes")        , emit: sizes

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    cut -f 1,2 $fai  > size
    head -n24 size > ${fasta}.sizes
    """
}