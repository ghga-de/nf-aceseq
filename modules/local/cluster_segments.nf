process CLUSTER_SEGMENTS {
    tag "$meta.id"
    label 'process_medium'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v5':'kubran/odcf_aceseqcalling:v5' }"
    
    input:
    tuple val(meta), path(snp_update1), path(snp_update1_index), path(segments_w_homodel), path(sexfile), path(gc_corrected), path(haplogroups), file(haplogroups_chr23)
    each file(chrlenght)
    val(chr_prefix)

    output:
    tuple val(meta), path('*normal.txt')                                      , emit: clustered_segments   
    tuple val(meta), path('*all_seg_2.txt.gz'), path('*all_seg_2.txt.gz.tbi') , emit: snp_update2
    tuple val(meta), path('*.pdf')
    path  "versions.yml"                                                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    tabix -f -s 1 -b 2 -e 3 --comment chromosome $segments_w_homodel

    manual_pruning.R \\
        --file  $snp_update1 \\
        --segments  $segments_w_homodel \\
        --out . \\
        --segOut    ${prefix}_clustered_and_pruned_and_normal.txt \\
        --min_seg_length    $params.min_seg_length_prune \\
        --clustering_YN $params.clustering \\
        --min_num_cluster   $params.min_cluster_number \\
        --min_num_SNPs  $params.min_num_SNPs \\
        --min_membership    $params.min_membership \\
        --min_distance  $params.min_distance \\
        --blockPre	${prefix}.chr   \\
        --blockSuf  haploblocks.tab \\
        --newFile   ${prefix}_all_seg2.txt.gz \\
        --sex $sexfile \\
        --gcCovWidthFile  $gc_corrected \\
        --chrLengthFile   $chrlenght \\
        --pid   ${prefix} \\
        --libloc  "" \\
        --runInDebugMode  false

    # Not sure why there is a NULL line in the end of the segments file
    zcat ${prefix}_all_seg2.txt.gz  | grep -v NULL | bgzip -f > ${prefix}_all_seg_2.txt.gz.2

    mv ${prefix}_all_seg_2.txt.gz.2 ${prefix}_all_seg_2.txt.gz
    tabix -f -s 1 -b 2 -e 2 --comment chromosome ${prefix}_all_seg_2.txt.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
    END_VERSIONS
    """

}