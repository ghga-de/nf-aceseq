process ADD_HAPLOTYPES {
    tag "$meta.id"
    label 'process_single'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_mpileupsnvcalling:v0':'kubran/odcf_mpileupsnvcalling:v0' }"

    input:
    tuple val(meta) , path(haplo_germ), path(haplo_x), path(snp_positions), path(index)

    output:
    tuple val(meta), path("*.tab.gz"), path("*.tab.gz.tbi")  , emit: snp_haplotypes
    path  "versions.yml"                                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    add_haplotypes.py \\
        --inputpath "${prefix}." \\
        --inputsuffix ".phased.vcf" \\
        --snps $snp_positions \\
        --out ${prefix}_all.snp.haplo.tab.gz
        
    tabix -f -s 1 -b 2 -e 2 ${prefix}_all.snp.haplo.tab.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python2 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
