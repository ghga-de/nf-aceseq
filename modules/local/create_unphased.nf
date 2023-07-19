process CREATE_UNPHASED {
    tag "$meta.id"
    label 'process_medium'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'docker://kubran/odcf_mpileupsnvcalling:v0':'kubran/odcf_mpileupsnvcalling:v0' }"

    input:
    tuple val(meta), path(snp_positions)  , path(index)
    tuple path(dbsnp)                     , path(index)

    output:
    tuple val(meta), path('*X.vcf')  , emit: x_unphased
    tuple val(meta), path('*Y.vcf')  , emit: y_unphased 
    path  "versions.yml"             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args        = task.ext.args ?: ''
    def prefix      = task.ext.prefix ?: "${meta.id}"

    """
    zcat $dbsnp | annotate_vcf.pl \\
      -a - -b $snp_positions \\
      --bFileType vcflike \\
      --chromXtr X:23 \\
      --chromYtr Y:24 \\
      --columnName genotype \\
      --aColNameLineStart "#CHROM" | \\
      grep -v "^#" | \\
        parseVcf.pl . ${prefix}.unphased_chr vcf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        perl: \$(echo \$(perl --version 2>&1) | sed 's/.*v\\(.*\\)) built.*/\\1/')
    END_VERSIONS
    """
}