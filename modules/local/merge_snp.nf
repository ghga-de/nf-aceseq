process MERGE_SNP {
    tag "$meta.id"
    label 'process_single'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v5':'kubran/odcf_aceseqcalling:v5' }"

    input:
    tuple val(meta), path(snp)
    val(chr_prefix)

    output:
    tuple val(meta), path("*.snp.tab.gz"), path("*.snp.tab.gz.tbi")   , emit: snp 
    path  "versions.yml"                                              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def snp_min_coverage = meta.iscontrol == "1" ? "${params.snp_min_coverage}" : "0"

    """
    merge_and_filter_snp.py \\
        --inputpath "${prefix}.${chr_prefix}" \\
        --inputsuffix ".snp.tab.gz" \\
        --output ${prefix}.snp.tab.gz \\
        --coverage $snp_min_coverage

    tabix -s 1 -b 2 -e 2 --comment chr ${prefix}.snp.tab.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python2 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
