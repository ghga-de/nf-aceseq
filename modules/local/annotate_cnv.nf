// This needs to run per cnv.tab.gz !
process ANNOTATE_CNV {
    tag "$meta.id"
    label 'process_medium'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'docker://kubran/odcf_aceseqcalling:v5':'kubran/odcf_aceseqcalling:v5' }"

    input:
    tuple val(meta), val(intervals)  , path(cnv)
    tuple path(mappability)          , path(index)

    output:
    tuple val(meta), path('*.cnv.anno.tab.gz')                  , emit: annotated_cnv
    tuple val(meta), val(intervals), path('*.cnv.anno.tab.gz')  , emit: tmp_cnv
    path  "versions.yml"                                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args        = task.ext.args ?: ''
    def prefix      = task.ext.prefix ?: "${meta.id}"

    """
    annotate_vcf.pl \\
        -a $cnv \\
        --aFileType=custom \\
	    --aChromColumn chr \\
	    --aPosColumn pos \\
	    --aEndColumn end \\
	    -b $mappability \\
	    --bFileType=bed \\
	    --reportBFeatCoord \\
	    --columnName map | \\
            addMappability.py \\
	            -o ${prefix}.${intervals}.cnv.anno.tab.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        perl: \$(echo \$(perl --version 2>&1) | sed 's/.*v\\(.*\\)) built.*/\\1/')
    END_VERSIONS
    """
}