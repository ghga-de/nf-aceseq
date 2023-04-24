process BCFTOOLS_MPILEUP {
    tag "$meta.id"
    label 'process_high'

    conda (params.enable_conda ? "bioconda::bcftools=1.9" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.9--h68d8f2e_9':
        'quay.io/biocontainers/bcftools:1.9--h68d8f2e_9' }"

    input:
    tuple val(meta), path(tumor), path(tumor_bai), path(control),  path(control_bai), val(intervals)
    tuple path(fasta), path(fai)

    output:
    tuple val(meta),path("*.vcf")                , emit: vcf
    tuple val(meta), path("*.bcftools_stats.txt"), emit: stats 
    tuple val(meta), val(interval_name)          , emit: intervals 
    path  "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args     = task.ext.args ?: ''
    def args2    = task.ext.args2 ?: ''
    def prefix   = task.ext.prefix ?: "${meta.id}"
    if (meta.iscontrol == '1') {
        """
        bcftools \\
            mpileup \\
            -O u \\
            --fasta-ref $fasta \\
            $args \\
            -r ${intervals} \\
            $control \\
            | bcftools call $args2 - > ${prefix}.${intervals}.unphased.vcf

        bcftools stats ${prefix}.${intervals}.vcf > ${prefix}.${intervals}.unphased.bcftools_stats.txt

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
        END_VERSIONS
        """
    }
    else{
         """
        touch ${prefix}.${intervals}.vcf

        touch ${prefix}.${intervals}.bcftools_stats.txt

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
        END_VERSIONS
        """       
    }
}