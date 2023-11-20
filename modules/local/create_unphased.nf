process CREATE_UNPHASED {
    tag "$meta.id"
    label 'process_single'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'docker://kubran/odcf_mpileupsnvcalling:v0':'kubran/odcf_mpileupsnvcalling:v0' }"

    input:
    tuple val(meta), path(fake_snp), path(index)
    tuple path(dbsnp), path(index)
    val(chr_prefix)

    output:
    tuple val(meta), path('*.vcf')  , emit: unphased
    path  "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args        = task.ext.args ?: ''
    def prefix      = task.ext.prefix ?: "${meta.id}"

    """ 
    zcat $dbsnp | annotate_vcf.pl \\
      -a - -b $fake_snp \\
      --bFileType vcflike \\
      --chromXtr X:23 \\
      --chromYtr Y:24 \\
      --columnName genotype \\
      --aColNameLineStart "#CHROM" | \\
      grep -v "^#" | \\
        parseVcf.pl . \\
            ${prefix}.unphased_${chr_prefix} \\
            vcf \\
            ${chr_prefix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        perl: \$(echo \$(perl --version 2>&1) | sed 's/.*v\\(.*\\)) built.*/\\1/')
    END_VERSIONS
    """
}