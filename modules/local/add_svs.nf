process ADD_SVS {
    tag "$meta.id"
    label 'process_single'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v0':'kubran/odcf_aceseqcalling:v0' }"

    input:
    tuple val(meta) , path(knownsegments), path(svs)

    output:
    tuple val(meta), path("*sv_points.txt"), path("*breakpoints.txt")  , emit: pscbs
    path  "versions.yml"                                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    if (!params.allowMissingSVFile && sv) {
        """
        PSCBSgabs_plus_sv_points.py \\
            --variants  $svs \\
            --known_segments    $knownsegments \\
            --output    ${prefix}_breakpoints.txt \\
            --sv_out    ${prefix}_sv_points.txt \\
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
