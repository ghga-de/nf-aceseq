process MAKE_MOCK {
    tag "$meta.id"
    label 'process_single'

    conda (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_mpileupsnvcalling:v0':'kubran/odcf_mpileupsnvcalling:v0' }"

    input:
    tuple val(meta) ,val(mock), path(vcf)
    val(sex)

    output:
    tuple val(meta), path("*.haploblocks.tab")          , emit: haploblock, optional: true
    tuple val(meta),val("chr23"), path("*.phased.vcf")  , emit: phased_vcf, optional: true
    tuple val(meta), path("*.sample_g.txt")             , emit: sample_g, optional: true

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    if (sex == "male"){
        """
        echo " " >${prefix}.chr23.haploblocks.tab
        echo "#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	sample_control_${prefix}"  >${prefix}.chr23.phased.vcf
        """
    }
    else{
        """
        #create sample_g file
        echo "ID_1 ID_2 missing sex" > ${prefix}.sample_g.txt
        echo "0 0 0 D" >> ${prefix}.sample_g.txt
        echo "${prefix} ${prefix} 0 2" >> ${prefix}.sample_g.txt
        """
    }

}
