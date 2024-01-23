// This process only works if there is SV file as an input
process ADD_CREST {
    tag "$meta.id"
    label 'process_low_cpu_high_memory'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v5':'kubran/odcf_aceseqcalling:v5' }"

    input:
    tuple val(meta) , path(svpoints), path(knownsegments), path(crest_deldupinv), path(crest_transloc)

    output:
    tuple val(meta), path("*sv_points2.txt")     , emit: sv_points
    tuple val(meta),  path("*breakpoints2.txt")  , emit: breakpoints
    path  "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    if (!meta.missingsv) {
        """
        PSCBSgabs_plus_CRESTpoints.py \\
            --crest_deldupinv $crest_deldupinv    \\
            --crest_tx $crest_transloc  \\
            --known_segments    $knownsegments \\
            --output    ${prefix}_sv_breakpoints2.txt \\
            --sv_out    ${prefix}_sv_sv_points2.txt \\
            --DDI_length    $params.min_DDI_length

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            python: \$(python2 --version 2>&1 | sed 's/Python //g')
        END_VERSIONS
        """
    }
    else{

        """

        cp $knownsegments ${prefix}_breakpoints2.txt
        sed -i '1s/^chr/#chr/' ${prefix}_breakpoints2.txt
        echo "" > ${prefix}_sv_points2.txt

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            python: \$(python2 --version 2>&1 | sed 's/Python //g')
        END_VERSIONS
        """

    }

}
