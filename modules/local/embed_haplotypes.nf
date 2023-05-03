process EMBED_HAPLOTYPES {
    tag "$meta.id"
    label 'process_single'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_mpileupsnvcalling:v0':'kubran/odcf_mpileupsnvcalling:v0' }"

    input:
    tuple val(meta) , path(phased), path(unpahsed), val(intervals)

    output:
    tuple val(meta),val(intervals), path("*.vcf.gz")  , emit: phased_tmp 
    path  "versions.yml"                              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    beagle_embed_haplotypes_vcf.py \\
        --hap_file $phased \\
        --vcf_file $unpahsed \\
        --out_file ${prefix}.${intervals}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python2 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
