process GENERATE_PLOTS {
    tag "$meta.id"
    label 'process_medium'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v4':'kubran/odcf_aceseqcalling:v4' }"
    
    input:
    tuple val(meta), path(all_snp_update3), path(index), path(svpoints), path(segments_w_peaks), path(purity_ploidy), path(sex_file), path(all_corrected)
    path(chrlenght)


    output:
    path('*.png')   
    path('*.txt')
    tuple val(meta),   path("*_cnv_parameter_*.txt")  , emit: cnv_params
    path  "versions.yml"                              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args    = task.ext.args ?: ''
    def prefix  = task.ext.prefix ?: "${meta.id}"
    def allowsv = params.allowMissingSVFile ?"--sv_YN false":"--sv_YN true"
    
    """
    pscbs_plots.R \\
        --SNPfile $all_snp_update3 \\
        --svFile $svpoints \\
        --segments $segments_w_peaks \\
        --outfile ${prefix}_plot \\
        --chrLengthFile $chrlenght \\
        --corrected $all_corrected \\
        --outDir . \\
        --pp $purity_ploidy \\
        --file_sex $sex_file \\
        --ID $prefix \\
        --ymaxcov_threshold $params.ymaxcov_threshold \\
        --annotatePlotsWithGenes $params.annotatePlotsWithGenes \\
        $allowsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
    END_VERSIONS
    """
}