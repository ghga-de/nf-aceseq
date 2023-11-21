process HOMOZYGOUS_DELETIONS {
    tag "$meta.id"
    label 'process_medium'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'docker://kubran/odcf_aceseqcalling:v5':'kubran/odcf_aceseqcalling:v5' }"

    input:
    tuple val(meta) , path(segments), path(sv_points)
    tuple path(mappability)         , path(index)

    output:
    tuple val(meta), path('*homozygous_deletion.txt.gz') , emit: segments_w_homodel
    path  "versions.yml"                                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args        = task.ext.args ?: ''
    def prefix      = task.ext.prefix ?: "${meta.id}"

    """
    #add "#" to header of fit.txt
    sed -i '1s/^chr/#chr/' $segments

    annotate_vcf.pl \\
        -a $segments \\
        --aFileType=custom \\
        --aChromColumn chromosome \\
        --aPosColumn "start" \\
        --aEndColumn end \\
        -b $mappability \\
        --bFileType=bed \\
        --reportBFeatCoord \\
        --columnName map \\
        --chromXtr 23:X \\
        --chromYtr 24:Y | \\
            addMappability.py \\
                -s start \\
                -e end \\
                -m map | \\
                    homozygous_deletion.pl \\
                        --a $sv_points \\
                        --b $params.min_segment_map | \\
                            bgzip > ${prefix}_homozygous_deletion.txt.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        perl: \$(echo \$(perl --version 2>&1) | sed 's/.*v\\(.*\\)) built.*/\\1/')
    END_VERSIONS
    """
}