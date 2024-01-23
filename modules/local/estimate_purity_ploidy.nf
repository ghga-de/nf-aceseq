process ESTIMATE_PURITY_PLOIDY {
    tag "$meta.id"
    label 'process_single'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v5':'kubran/odcf_aceseqcalling:v5' }"
    
    input:
    tuple val(meta), path(segments), path(sexfile)

    output:
    tuple val(meta), path('*_ploidy_purity_2D.txt')    , emit: purity_ploidy   
    path  "versions.yml"                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    
    """
    purity_ploidy_estimation_final.R \\
        --file_sex    $sexfile \\
        --segments  $segments \\
        --purity_ploidy    ${prefix}_ploidy_purity_2D.txt \\
        --min_length_purity $params.min_length_purity \\
        --min_hetSNPs_purity    $params.min_hetSNPs_purity \\
        --dh_Stop   $params.dh_stop \\
        --min_length_dh_stop    $params.min_length_dh_stop \\
        --dh_zero   $params.dh_zero \\
        --purity_min    $params.purity_min \\
        --purity_max    $params.purity_max \\
        --ploidy_min    $params.ploidy_min \\
        --ploidy_max    $params.ploidy_max \\
        --pid   $prefix \\
        --local_minium_upper_boundary_shift $params.local_minium_upper_boundary_shift \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
    END_VERSIONS
    """
}