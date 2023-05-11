process GC_BIAS {
    tag "$meta.id"
    label 'process_medium'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_platypusindelcalling:v1':'kubran/odcf_platypusindelcalling:v1' }"
    
    input:
    tuple val(meta), path(cnv_pos)
    path(rep_time)
    path(chrlength)
    path(gc_content)

    output:
    tuple val(meta), path('*.slim.txt')                 , emit: gc
    tuple val(meta), path('*_all.cnv.corrected.tab.gz') , emit: corrected_windows 
    tuple val(meta), path('*.gc_corrected.tsv')         , emit: corrected_quality     
    path('*_all_seg.gc_corrected.txt')
    path('*.tsv')   
    path('*.png')                
    path  "versions.yml"                                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    correctGCBias.R \\
        --windowFile $cnv_pos \\
        --timefile $rep_time \\
        --chrLengthFile $chrlength \\
        --pid $prefix \\
        --outfile ${prefix}_all.cnv.corrected.tab.gz \\
        --corPlot ${prefix}.gc_corrected.png \\
        --corTab ${prefix}.gc_corrected.tsv  \\
        --qcTab ${prefix}.gc_corrected_quality.slim.txt \\
        --gcFile $gc_content \\
        --outDir . \\
        --lowess_f $params.lowess_f \\
        --scaleFactor $params.scale_factor \\
        --coverageYlims $params.covplot_tlims

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
    END_VERSIONS
    """
}