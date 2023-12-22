process FAKE_CONTROL {
    tag "$meta.id $intervals"
    label 'process_single'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v5':'kubran/odcf_aceseqcalling:v5' }"
    
    input:
    tuple val(meta), val(intervals),file(bad_cnv)
    path(fake_cnv)

    output:
    tuple val(meta), path('*.cnv.anno.tab.gz')    , emit: new_cnp 
    path  "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    replaceControlACEseq.R \\
        -f ${params.fake_control_prefix}.${intervals}.cnv.anno.tab.gz \\
        -b $bad_cnv \\
        -o ${prefix}.tmp.${intervals}.cnv.anno.tab.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
    END_VERSIONS
    """

}