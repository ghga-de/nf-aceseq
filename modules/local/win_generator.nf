process WIN_GENERATOR {
    tag "$meta.id $intervals" 
    label 'process_low'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v5':'kubran/odcf_aceseqcalling:v5' }"

    input:
    tuple val(meta),  val(intervals), path(mpileup)
    tuple path(dbsnp), path(index) 

    output:
    tuple val(meta), path("*.snp.tab.gz")                  , emit: snp 
    tuple val(meta), val(intervals), path("*.cnv.tab.gz")  , emit: cnv 
    path  "versions.yml"                                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def control_param = meta.iscontrol == "1" ? "" : "--withoutcontrol"

    """
    snp_cnv.py \\
        --quality $params.mpileup_qual \\
        --dbsnp $dbsnp \\
        --infile $mpileup \\
        --outsnps ${prefix}.${intervals}.snp.tab.gz \\
        --outcov ${prefix}.${intervals}.cnv.tab.gz \\
        $control_param

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python2 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
