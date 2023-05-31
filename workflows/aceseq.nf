/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowAceseq.initialise(params, log)

// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config, params.fasta ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

// Set up reference depending on the genome choice
ref            = Channel.fromPath([params.fasta,params.fasta_fai], checkIfExists: true).collect()
chr_prefix     = Channel.value(params.chr_prefix)
chrlength      = params.chrom_sizes           ? Channel.fromPath(params.chrom_sizes, checkIfExists: true) : Channel.empty()   
contigs        = params.contig_file           ? Channel.fromPath(params.contig_file, checkIfExists: true) : Channel.empty()
rep_time       = params.replication_time_file ? Channel.fromPath(params.replication_time_file, checkIfExists: true) : Channel.empty() 
gc_content     = params.gc_content_file       ? Channel.fromPath(params.gc_content_file, checkIfExists: true) : Channel.empty() 
centromers     = params.centromer_file        ? Channel.fromPath(params.centromer_file, checkIfExists: true) : Channel.empty() 

if (params.fasta.contains("38")){
    ref_type = "hg38"   
}
else{
    ref_type = "hg37"
}


dbsnpsnv            =  params.dbsnp_snv         ? Channel.fromPath([params.dbsnp_snv, params.dbsnp_snv + '.tbi'], checkIfExists: true).collect() 
                                                : Channel.of([],[])                                        
mapability          = params.mapability_file    ? Channel.fromPath([params.mapability_file, params.mapability_file + '.tbi'], checkIfExists: true).collect() 
                                                : Channel.of([],[])
// Beagle references
beagle_ref          = params.beagle_reference   ? Channel.fromPath(params.beagle_reference + '/ALL.*.shapeit2_integrated_snvindels_v2a_27022019.GRCh38.phased.CHR.bref3', checkIfExists: true ).collect()                                   
                                                : Channel.empty()
beagle_map          = params.beagle_genetic_map ? Channel.fromPath(params.beagle_genetic_map + '/plink.*.GRCh38.CHR.map', checkIfExists: true ).collect() 
                                                : Channel.empty()    

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK              } from '../subworkflows/local/input_check'
include { MPILEUP_SNV_CNV_CALL     } from '../subworkflows/local/mpileup_snv_cnv_call'
include { PHASING                  } from '../subworkflows/local/phasing'
include { CORRECT_GC_BIAS          } from '../subworkflows/local/correct_gc_bias'
include { GET_BREAKPOINTS_SEGMENTS } from '../subworkflows/local/get_breakpoints_segments'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

//
// MODULE: Local Modules
//

include { GREP_SAMPLENAME   } from '../modules/local/grep_samplename.nf'
include { GETCHROMSIZES     } from '../modules/local/getchromsizes.nf'
include { CREATE_UNPHASED   } from '../modules/local/create_unphased.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow ACESEQ {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)
    sample_ch   = INPUT_CHECK.out.ch_sample

    if ( !params.chrom_sizes) {
        //
        // MODULE: Prepare chromosome size file if not provided
        //
        GETCHROMSIZES(
            ref
            )
        ch_versions = ch_versions.mix(GETCHROMSIZES.out.versions)
        chrlength   = GETCHROMSIZES.out.sizes
    }

    //
    // MODULE: Extract sample name from BAM
    //
    GREP_SAMPLENAME(
        sample_ch
    )
    ch_versions = ch_versions.mix(GREP_SAMPLENAME.out.versions)

    // Prepare an input channel of sample with sample names
    name_ch   = GREP_SAMPLENAME.out.samplenames
    ch_sample = sample_ch.join(name_ch)

    //
    // SUBWORKFLOW: MPILEUP_SNV_CNV_CALL: Call SNVs
    //
    MPILEUP_SNV_CNV_CALL(
        ch_sample, 
        ref, 
        chrlength,
        dbsnpsnv,
        mapability
    )
    ch_versions    = ch_versions.mix(MPILEUP_SNV_CNV_CALL.out.versions)
    ch_all_snp     = MPILEUP_SNV_CNV_CALL.out.all_snp
    ch_sex_file    = MPILEUP_SNV_CNV_CALL.out.ch_sex

    //
    // SUBWORKFLOW: CORRECT_GC_BIAS
    //  
    CORRECT_GC_BIAS(
        MPILEUP_SNV_CNV_CALL.out.all_cnv,
        rep_time,
        chrlength,
        gc_content
    )
    ch_corr_qual = CORRECT_GC_BIAS.out.qual_corrected
    ch_corr_win  = CORRECT_GC_BIAS.out.windows_corrected
    ch_versions  = ch_versions.mix(CORRECT_GC_BIAS.out.versions)

    //
    // SUBWORKFLOW: PHASING: Call mpileup and beagle
    //
    ch_input_phase = ch_sample.join(MPILEUP_SNV_CNV_CALL.out.ch_sex)
    PHASING(
        ch_input_phase,
        ch_all_snp, 
        ref, 
        chrlength,
        beagle_ref,
        beagle_map,
        dbsnpsnv
    )
    ch_versions     = ch_versions.mix(PHASING.out.versions)
    snp_pos_haplo   = PHASING.out.ch_snp_haplotypes
    haploblocks_chr = PHASING.out.ch_haploblocks
    //
    // SUBWORKFLOW: GET_BREAKPOINTS_SEGMENTS: 
    //
    GET_BREAKPOINTS_SEGMENTS(
        ch_corr_win,
        ch_corr_qual,
        snp_pos_haplo,
        haploblocks_chr,
        ch_sex_file,
        centromers,
        chrlength,
        mapability
    )

    //// createUnphasedFiles.sh /////
    
    // WARN: this is probably needed for no-control samples!    
    //
    // MODULE: CREATE_UNPHASED
    //
    // Run annotateCNA.pl and parseVcf.pl to generate X (if male) and Y unphased VCFs
    CREATE_UNPHASED(
        ch_all_snp,
        dbsnpsnv
    )
    unphased_x  = CREATE_UNPHASED.out.x_unphased
    unphased_y  = CREATE_UNPHASED.out.y_unphased
    ch_versions = ch_versions.mix(CREATE_UNPHASED.out.versions)

    //
    // MODULE: CUSTOM_DUMPSOFTWAREVERSIONS
    //
    // Collects versions
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowAceseq.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowAceseq.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    //ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
