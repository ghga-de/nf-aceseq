process BEAGLE5_BEAGLE {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::beagle=5.2_21Apr21.304"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/beagle:5.2_21Apr21.304--hdfd78af_0':
        'quay.io/biocontainers/beagle:5.2_21Apr21.304--hdfd78af_0' }"

    input:
    tuple val(meta),val(intervals),path(vcf)
    path(refpanel)
    path(genmap)

    output:
    tuple val(meta),val(intervals), path("*.vcf.gz")  , emit: vcf
    tuple val(meta), path("*.log")                    , emit: log
    path "versions.yml"                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}.phased_${intervals}_2samples"

    def avail_mem = 3072
    if (!task.memory) {
        log.info '[beagle] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this.'
    } else {
        avail_mem = (task.memory.mega*0.8).intValue()
    }
    
    """
    beagle -Xmx${avail_mem}M \\
        gt=${vcf} \\
        out=${prefix} \\
        $args \\
        ref=ALL.${intervals}.shapeit2_integrated_snvindels_v2a_27022019.GRCh38.phased.CHR.bref3 \\
        map=plink.${intervals}.GRCh38.CHR.map \\
        impute=false 

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        beagle: \$(beagle 2>&1 |head -n1 | sed -rn 's/beagle\\.(.*)\\.jar \\(version (.*)\\)/\\2rev\\1/p')
    END_VERSIONS
    """
}