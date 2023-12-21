process BCFTOOLS_MPILEUP {
    tag "$meta.id chr$intervals"
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::bcftools=1.9" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.9--h68d8f2e_9':
        'quay.io/biocontainers/bcftools:1.9--h68d8f2e_9' }"

    input:
    tuple val(meta), path(tumor), path(tumor_bai), path(control),  path(control_bai), val(intervals)
    tuple path(fasta), path(fai)

    output:
    tuple val(meta),val(intervals), path("*.unphased.vcf")  , emit: vcf
    path  "versions.yml"                                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args     = task.ext.args ?: ''
    def args2    = task.ext.args2 ?: ''
    def prefix   = task.ext.prefix ?: "${meta.id}"

    """
    bcftools \\
        mpileup \\
        -O u \\
        --fasta-ref $fasta \\
        $args \\
        -r ${intervals} \\
        $control \\
        | bcftools call $args2 - > ${prefix}.${intervals}.unphased.vcf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """ 

}
