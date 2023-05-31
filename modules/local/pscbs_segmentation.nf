process PSCBS_SEGMENTATION {
    tag "$meta.id"
    label 'process_medium'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v0':'kubran/odcf_aceseqcalling:v0' }"
    
    input:
    tuple val(meta), path(svpoints), path(breakpoints), path(pscbs_data), path(index), path(libloc)
    each file(chrlenght)

    output:
    tuple val(meta), path(svpoints), path('*fit.txt')   , emit: segments   
    path  "versions.yml"                                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def nocontrol = meta.iscontrol == "1" ? "" : "--nocontrol TRUE"

    """
    pscbs_all.R \\
        --file_data $pscbs_data \\
        --file_breakpoints  $breakpoints \\
        --chrLengthFile $chrlenght \\
        --file_fit  ${prefix}_fit.txt \\
        --minwidth  $params.min_seg_width \\
        --undo.SD   $params.undo_SD \\
        -h  $params.pscbs_prune_height \\
        --sv    $svpoints \\
        --libloc    $libloc \\
        $nocontrol

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
    END_VERSIONS
    """

}