//This only works with v0
process DEFINE_BREAKPOINTS {
    tag "$meta.id"
    label 'process_medium'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v0':'kubran/odcf_aceseqcalling:v0' }"
    
    input:
    tuple val(meta), path(gc_corrected_win), path(snp_haplo_pos), path(index), path(sexfile)
    each file(centromers)

    output:
    tuple val(meta), path('*knownSegments.txt')                  , emit: known_segments
    tuple val(meta), path('*data.txt.gz'), path('*.txt.gz.tbi')  , emit: pscbs_data    
    path('*.pdf')    
    path  "versions.yml"  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    datatable_and_PSCBSgaps.R \\
        --file_cnv  $gc_corrected_win \\
        --file_snp  $snp_haplo_pos \\
        --file_beta ${prefix}.densityBeta.pdf \\
        --file_sex $sexfile \\
        --file_knownSegments ${prefix}.knownSegments.txt \\
        --file_centromeres  $centromers \\
        --file_data ${prefix}_pscbs_data.txt.gz \\
        --libloc    ""           

        tabix -f -s 2 -b 1 --comment a ${prefix}_pscbs_data.txt.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
    END_VERSIONS
    """

}