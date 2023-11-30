// This process only works if there is SV file as an input

process ADD_SVS {
    tag "$meta.id"
    label 'process_low_cpu_high_memory'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v5':'kubran/odcf_aceseqcalling:v5' }"

    input:
    tuple val(meta) , path(knownsegments)

    output:
    tuple val(meta), path("*sv_points.txt")    , emit: sv_points
    tuple val(meta), path("*breakpoints.txt")  , emit: breakpoints
    path  "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    if (!meta.missingsv) {
        """
        PSCBSgabs_plus_sv_points.py \\
            --variants  $meta.sv \\
            --known_segments    $knownsegments \\
            --output    ${prefix}_sv_breakpoints.txt \\
            --sv_out    ${prefix}_sv_sv_points.txt \\
            --DDI_length    $params.min_DDI_length \\
            --selectCol $params.selSVColumn

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            python: \$(python2 --version 2>&1 | sed 's/Python //g')
        END_VERSIONS
        """
    }
    else{

        """
        cp $knownsegments ${prefix}_breakpoints.txt
        sed -i '1s/^chr/#chr/' ${prefix}_breakpoints.txt
        echo "" > ${prefix}_sv_points.txt

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            python: \$(python2 --version 2>&1 | sed 's/Python //g')
        END_VERSIONS
        """

    }

}
