process ESTIMATE_PEAKS {
    tag "$meta.id"
    label 'process_medium'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v4':'kubran/odcf_aceseqcalling:v4' }"
    
    input:
    tuple val(meta), path(allsnps), path(clusteredsegments), path(sexfile)

    output:
    tuple val(meta), path('*_combi_level.txt')    , emit: segment_peaks   
    path  "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    
    """
    tabix -f -s 1 -b 3 -e 4 $allsnps 

    purity_ploidy.R \\
        --file  $allsnps \\
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