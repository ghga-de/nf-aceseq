process GROUP_HAPLOTYPES {
    tag "$meta.id $intervals"
    label 'process_low'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v5':'kubran/odcf_aceseqcalling:v5' }"

    input:
    tuple val(meta) , val(intervals), path(phased)
    val(chr_prefix)

    output:
    tuple val(meta), path("*haploblocks.tab")  , emit: haplogroups
    path  "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def chr_suff      = chr_prefix == "chr" ? "" : "chr"
    def interval_name = intervals == "${chr_prefix}X" ? "${chr_suff}${chr_prefix}23" : "${chr_suff}" + "${intervals}"

    """
    group_genotypes.py \\
        --infile $phased \\
        --out ${prefix}.${interval_name}.haploblocks.tab \\
        --minHT $params.minHT

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python2 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
