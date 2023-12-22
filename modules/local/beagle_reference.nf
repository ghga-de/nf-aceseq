process BEAGLE_REFERENCE {
    tag "$fasta"
    label 'process_medium'

    conda "bioconda::beagle=5.2_21Apr21.304"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/beagle:5.2_21Apr21.304--hdfd78af_0':
        'quay.io/biocontainers/beagle:5.2_21Apr21.304--hdfd78af_0' }"

    input:
    tuple path(fasta), path(fai)

    output:
    path (beagle_ref)        , emit: beagle_ref
    path (beagle_map)        , emit: beagle_map

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def ref = fasta.contains("38") ? "hg38" : "hg37" 

    """
    prepare_beagle_ref.sh \\
        -r $ref

    mkdir beagle_ref
    cp *.bref3 beagle_ref/

    mkdir beagle_map
    cp *.map beagle_map/
    """
}