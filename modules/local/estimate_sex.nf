process ESTIMATE_SEX {
    tag "$meta.id"
    label 'process_medium'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v5':'kubran/odcf_aceseqcalling:v5' }"
    
    input:
    tuple val(meta), val(intervals), path(cnv)
    each file(chrlenght)
    val(chr_prefix)

    output:
    tuple val(meta), path('*_sex.txt')        , emit: sex   
    path  "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    if (params.estimatesex) {
        if (meta.iscontrol == '1'){
            """
            getSex.R \\
            --file_dataY ${prefix}.${chr_prefix}Y.cnv.tab.gz \\
            --file_dataX ${prefix}.${chr_prefix}X.cnv.tab.gz \\
            --file_size $chrlenght \\
            --cnv_files "${prefix}.${chr_prefix}*.cnv.tab.gz" \\
            --min_Y_ratio $params.min_Y_ratio \\
            --min_X_ratio $params.min_X_ratio \\
            --file_out ${prefix}_sex.txt

            cat <<-END_VERSIONS > versions.yml
            "${task.process}":
                r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
            END_VERSIONS
            """
        }
        else{
            if (meta.sex){
                """
                echo $meta.sex > ${prefix}_sex.txt

                cat <<-END_VERSIONS > versions.yml
                "${task.process}":
                    r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
                END_VERSIONS
                """
            }
            else
            {
                echo "Gender/Sex must be spesified for nocontrol runs!"
                exit 2
            }
        }
    }
    else {
        if (meta.sex){
            """
            echo $meta.sex > ${prefix}_sex.txt

            cat <<-END_VERSIONS > versions.yml
            "${task.process}":
                r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
            END_VERSIONS
            """
        }
        else{
                echo "Gender/Sex must be spesified in metadata not to estimatesex from sample data!"
                exit 2
        }
    }
}