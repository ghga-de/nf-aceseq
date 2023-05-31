process ADD_CREST {
    tag "$meta.id"
    label 'process_single'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v0':'kubran/odcf_aceseqcalling:v0' }"

    input:
    tuple val(meta) , path(svpoints), path(breakpoints), path(crest_deldupinv), path(crest_transloc)

    output:
    tuple val(meta), path("*sv_points2.txt"), path("*breakpoints2.txt")  , emit: pscbs
    path  "versions.yml"                                                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    if (!params.allowMissingSVFile && sv) {
        """
        PSCBSgabs_plus_CRESTpoints.py \\
            --crest_deldupinv $crest_deldupinv    \\
            --crest_tx $crest_transloc  \\
            --known_segments    $breakpoints \\
            --output    ${prefix}_breakpoints2.txt \\
            --sv_out    ${prefix}_sv_points2.txt \\
            --DDI_length    $params.min_DDI_length

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            python: \$(python2 --version 2>&1 | sed 's/Python //g')
        END_VERSIONS
        """
    }
    else{

        """
        cp $breakpoints ${prefix}_breakpoints2.txt
        cp $svpoints ${prefix}_sv_points2.txt

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            python: \$(python2 --version 2>&1 | sed 's/Python //g')
        END_VERSIONS
        """

    }

}
