process GET_GENOTYPES {
    tag "$meta.id"
    label 'process_single'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v0':'kubran/odcf_aceseqcalling:v0' }"
    
    input:
    tuple val(meta), path(all_snp), path(index)

    output:
    tuple val(meta), path('*.fakeBaf.snp.tab.gz'), path('*.fakeBaf.snp.tab.gz.tbi') , emit: fake_snp 
    path  "versions.yml"                                                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    getHetSNPs.R \\
        -s $all_snp \\
        | bgzip > ${prefix}.fakeBaf.snp.tab.gz

    tabix -h -f -s 1 -b 2 -e 2 ${prefix}.fakeBaf.snp.tab.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
    END_VERSIONS
    """

}