process GROUP_HAPLOTYPES {
    tag "$meta.id"
    label 'process_single'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_mpileupsnvcalling:v0':'kubran/odcf_mpileupsnvcalling:v0' }"

    input:
    tuple val(meta) , val(intervals), path(phased)

    output:
    tuple val(meta), path("*haploblocks.tab")  , emit: haplogroups
    path  "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def interval_name = intervals == "chrX" ? "chr23" : intervals

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
