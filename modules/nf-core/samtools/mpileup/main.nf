process SAMTOOLS_MPILEUP {
    tag "$meta.id chr$intervals"
    label 'process_medium'

    conda "bioconda::samtools=1.9"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/samtools:v1.9':'kubran/samtools:v1.9' }"
    input:
    tuple val(meta), path(tumor),  path(tumor_bai), path(control), path(control_bai), val(intervals)
    tuple path(fasta), path(fai)

    output:
    tuple val(meta), val(intervals), path("*.mpileup"), emit: mpileup
    path  "versions.yml"                              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def bamlist = meta.iscontrol == '1' ? "${control} ${tumor}" : "${tumor}"

    """
    samtools mpileup \\
        --fasta-ref $fasta \\
        --output ${prefix}.${intervals}.mpileup \\
        $args \\
        -r $intervals \\
        $bamlist

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}