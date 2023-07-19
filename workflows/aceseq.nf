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
// Blacklist        
blacklist           = params.blacklist_file     ? Channel.fromPath(params.blacklist_file , checkIfExists: true )
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
include { BREAKPOINTS_SEGMENTS     } from '../subworkflows/local/breakpoints_segments'
include { PLOTS_REPORTS            } from '../subworkflows/local/plots_reports'
include { HDR_ESTIMATION           } from '../subworkflows/local/hdr_estimation'


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
        INPUT_CHECK.out.ch_sample
    )
    ch_versions = ch_versions.mix(GREP_SAMPLENAME.out.versions)

    // Prepare an input channel of sample with sample names
    name_ch   = GREP_SAMPLENAME.out.samplenames
    INPUT_CHECK.out.ch_sample.join(name_ch)
                            .set{sample_ch}

    //
    // SUBWORKFLOW: MPILEUP_SNV_CNV_CALL: Call SNVs
    //
    MPILEUP_SNV_CNV_CALL(
        sample_ch, 
        ref, 
        chrlength,
        dbsnpsnv,
        mapability
    )
    ch_versions    = ch_versions.mix(MPILEUP_SNV_CNV_CALL.out.versions)

    //
    // SUBWORKFLOW: CORRECT_GC_BIAS
    //  
    CORRECT_GC_BIAS(
        MPILEUP_SNV_CNV_CALL.out.all_cnv,
        rep_time,
        chrlength,
        gc_content
    )
    ch_versions  = ch_versions.mix(CORRECT_GC_BIAS.out.versions)

    //
    // SUBWORKFLOW: PHASING: Call mpileup and beagle
    //

    PHASING(
        sample_ch,
        MPILEUP_SNV_CNV_CALL.out.all_snp, 
        ref, 
        chrlength,
        beagle_ref,
        beagle_map,
        dbsnpsnv,
        MPILEUP_SNV_CNV_CALL.out.ch_sex
    )
    ch_versions     = ch_versions.mix(PHASING.out.versions)

    //
    // SUBWORKFLOW: BREAKPOINTS_SEGMENTS: 
    //
    BREAKPOINTS_SEGMENTS(
        CORRECT_GC_BIAS.out.windows_corrected,
        CORRECT_GC_BIAS.out.qual_corrected,
        PHASING.out.ch_snp_haplotypes,
        PHASING.out.ch_haploblocks,
        MPILEUP_SNV_CNV_CALL.out.ch_sex,
        centromers,
        chrlength,
        mapability
    )
    ch_versions     = ch_versions.mix(BREAKPOINTS_SEGMENTS.out.versions)

    //
    // SUBWORKFLOW: PLOTS_REPORTS: 
    //
    PLOTS_REPORTS(
        BREAKPOINTS_SEGMENTS.out.ch_sv_points,
        BREAKPOINTS_SEGMENTS.out.ch_all_snp_update3,
        BREAKPOINTS_SEGMENTS.out.ch_purity_ploidy,
        BREAKPOINTS_SEGMENTS.out.ch_segment_w_peaks,
        MPILEUP_SNV_CNV_CALL.out.ch_sex,
        CORRECT_GC_BIAS.out.all_corrected,
        chrlength
    )
    ch_versions     = ch_versions.mix(PLOTS_REPORTS.out.versions)

    //
    // SUBWORKFLOW: HDR_ESTIMATION: 
    //

    HDR_ESTIMATION(
        PLOTS_REPORTS.out.json_report,
        blacklist,
        MPILEUP_SNV_CNV_CALL.out.ch_sex,
        centromers
    )

    //// createUnphasedFiles.sh /////
    
    // WARN: this is probably needed for no-control samples!    
    //
    // MODULE: CREATE_UNPHASED
    //
    // Run annotateCNA.pl and parseVcf.pl to generate X (if male) and Y unphased VCFs
    CREATE_UNPHASED(
        MPILEUP_SNV_CNV_CALL.out.all_snp,
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
