//This only works with v0
process CREATE_BAF_PLOTS {
    tag "$meta.id"
    label 'process_single'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v0':'kubran/odcf_aceseqcalling:v0' }"
    
    input:
    tuple val(meta), path(snp_haplo), path(index), path(sexfile)
    each file(chrlenght)

    output:
    tuple val(meta), path('*.png')        , emit: plots   
    path  "versions.yml"                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    createBAFplots.R \\
        --file_snp  $snp_haplo \\
        --file_sex  $sexfile \\
        --chrLengthFile $chrlenght \\
        --pid $prefix \\
        --plot_Dir .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
    END_VERSIONS
    """

}