process CLUSTER_SEGMENTS {
    tag "$meta.id"
    label 'process_medium'

    conda     (params.enable_conda ? "" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://kubran/odcf_aceseqcalling:v3':'kubran/odcf_aceseqcalling:v3' }"
    
    input:
    tuple val(meta), path(all_seg), path(homdels), path(sexfile), path(gc_corrected), path(haplogroups), path(haplogroups_chr23)
    each file(chrlenght)

    output:
    tuple val(meta), path('*normal.txt')     , emit: clustered_segments   
    tuple val(meta), path('*all_seg_2.txt.gz'), path('*all_seg_2.txt.gz.tbi') , emit: all_segments2
    path  "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    tabix -f -s 1 -b 2 -e 3 --comment chromosome $homdels
    tabix -f -s 1 -b 3 -e 4 $all_seg

    manual_pruning.R \\
        --file  $all_seg \\
        --segments  $homdels \\
        --out . \\
        --segOut    ${prefix}_clustered_and_pruned_and_normal.txt \\
        --min_seg_length    $params.min_seg_length_prune \\
        --clustering_YN $params.clustering \\
        --min_num_cluster   $params.min_cluster_number \\
        --min_num_SNPs  $params.min_num_SNPs \\
        --min_membership    $params.min_membership \\
        --min_distance  $params.min_distance \\
        --blockPre	${prefix}.chr	\\
        --blockSuf  haploblocks.tab   \\
        --newFile   ${prefix}_all_seg2.txt \\
        --sex $sexfile \\
        --gcCovWidthFile  $gc_corrected \\
        --chrLengthFile   $chrlenght \\
        --pid   ${prefix} \\
        --libloc  "" \\
        --runInDebugMode  false

    # Not sure why there is a NULL line in the end of the segments file
    cat ${prefix}_all_seg2.txt  | grep -v NULL | bgzip -f > ${prefix}_all_seg_2.txt.gz

    tabix -f -s 1 -b 2 -e 2 --comment chromosome ${prefix}_all_seg_2.txt.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
    END_VERSIONS
    """

}