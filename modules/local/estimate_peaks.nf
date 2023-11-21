process ESTIMATE_PEAKS {
    tag "$meta.id"
    label 'process_single'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v5':'kubran/odcf_aceseqcalling:v5' }"
    
    input:
    tuple val(meta), path(snps_update_3), path(index), path(clusteredsegments), path(sexfile)

    output:
    tuple val(meta), path('*_combi_level.txt')    , emit: segment_w_peaks   
    path  "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    
    """
    purity_ploidy.R \\
        --file  $snps_update_3 \\
        --gender    $sexfile \\
        --segments  $clusteredsegments \\
        --segOut    ${prefix}_combi_level.txt \\
        --out   .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
    END_VERSIONS
    """
}