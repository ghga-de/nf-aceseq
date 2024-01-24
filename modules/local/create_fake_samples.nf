process CREATE_FAKE_SAMPLES {
    tag "$meta.id $intervals"
    label 'process_low'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v5':'kubran/odcf_aceseqcalling:v5' }"

    input:
    tuple val(meta) , val(intervals), path(vcf)

    output:
    tuple val(meta), val(intervals), path("*.vcf")  , emit: unphased_vcf 
    path  "versions.yml"                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    beagle_create_fake_samples.py \\
        --in_file $vcf \\
        --out_file ${prefix}.unphased_${intervals}_2samples.vcf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python2 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
