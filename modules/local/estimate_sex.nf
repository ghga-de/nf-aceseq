// else statement will change!
process ESTIMATE_SEX {
    tag "$meta.id"
    label 'process_medium'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_platypusindelcalling:v1':'kubran/odcf_platypusindelcalling:v1' }"
    
    input:
    tuple val(meta), val(intervals), path(cnv)
    each file(chrlenght)

    output:
    tuple val(meta), path('*_sex.txt')        , emit: sex   
    path  "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    if (meta.iscontrol == '1') {
        """
        getSex.R \\
            --file_dataY ${prefix}.chrY.cnv.tab.gz \\
            --file_dataX ${prefix}.chrX.cnv.tab.gz \\
            --file_size $chrlenght \\
            --cnv_files "${prefix}.chr*.cnv.tab.gz" \\
            --min_Y_ratio $params.min_Y_ratio \\
            --min_X_ratio $params.min_X_ratio \\
            --file_out ${prefix}_sex.txt

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
        END_VERSIONS
        """
    }
    else {
        """
        echo "male" > ${prefix}_sex.txt

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
        END_VERSIONS
        """
    }
}