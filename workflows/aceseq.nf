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

fake_control = Channel.empty()
// If no control case is active, check for existance of fake controls
if (params.fake_control){
    fake_control   = Channel.fromPath(params.fake_control + '/'+ params.fake_control_prefix +'*.cnv.anno.tab.gz', checkIfExists: true ).collect() 
}  


// Set up reference depending on the genome choice
ref            = Channel.fromPath([params.fasta,params.fasta_fai], checkIfExists: true).collect()

chrprefix      = params.chr_prefix              ? Channel.value(params.chr_prefix) : Channel.value("")

chrlength      = params.chrom_sizes             ? Channel.fromPath(params.chrom_sizes, checkIfExists: true)
                                                : Channel.empty()   
rep_time       = params.replication_time_file   ? Channel.fromPath(params.replication_time_file, checkIfExists: true)
                                                : Channel.empty() 
gc_content     = params.gc_content_file         ? Channel.fromPath(params.gc_content_file, checkIfExists: true)
                                                : Channel.empty() 
centromers     = params.centromer_file          ? Channel.fromPath(params.centromer_file, checkIfExists: true)
                                                : Channel.empty() 
cytobands      = params.cytobands_file          ? Channel.fromPath(params.cytobands_file, checkIfExists: true) 
                                                : Channel.empty() 
// Beagle references
beagle_ref     = params.beagle_ref              ? Channel.fromPath(params.beagle_ref + "/*chr*" + params.beagle_ref_ext, checkIfExists: true )
                                                : Channel.empty()                                                                            
plink_map      = params.plink_map               ? Channel.fromPath(params.plink_map + "/*chr*" + params.plink_map_ext , checkIfExists: true )
                                                : Channel.empty()   
// Annotation files

dbsnpsnv            = params.dbsnp_snv          ? Channel.fromPath([params.dbsnp_snv, params.dbsnp_snv + '.tbi'], checkIfExists: true).collect() 
                                                : Channel.of([],[])                                        
mapability          = params.mapability_file    ? Channel.fromPath([params.mapability_file, params.mapability_file + '.tbi'], checkIfExists: true).collect() 
                                                : Channel.of([],[])
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
include { SNV_CALLING              } from '../subworkflows/local/snv_calling'
include { PREPROCESSING            } from '../subworkflows/local/preprocessing'
include { SEGMENTATION             } from '../subworkflows/local/segmentation'
include { PURITY_EVALUATION        } from '../subworkflows/local/purity_evaluation'
include { HDR_ESTIMATION           } from '../subworkflows/local/hdr_estimation'
include { PHASING_X                } from '../subworkflows/local/phasing_x'
include { PHASING_Y                } from '../subworkflows/local/phasing_y'


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

include { GETCHROMSIZES     } from '../modules/local/getchromsizes.nf'
include { PREPARE_BEAGLE_REF as PREPARE_BEAGLE_REF_1  } from '../modules/local/prepare_beagle_ref.nf'
include { PREPARE_BEAGLE_REF as PREPARE_BEAGLE_REF_2  } from '../modules/local/prepare_beagle_ref.nf'

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
    ch_sample = INPUT_CHECK.out.ch_sample

    if ( !params.chrom_sizes) {
        //
        // MODULE: Prepare chromosome size file if not provided
        //
        GETCHROMSIZES(ref)
        chrlength   = GETCHROMSIZES.out.sizes
    }

    //println "The samples: "
    ch_sample.view()

    SNV_CALLING(
        ch_sample, 
        ref, 
        chrlength,
        dbsnpsnv,
        mapability,
        chrprefix,
        fake_control
    )
    ch_versions    = ch_versions.mix(SNV_CALLING.out.versions)

    //
    // SUBWORKFLOW: PREPROCESSING
    //  

    PREPROCESSING(
        SNV_CALLING.out.all_cnv,
        rep_time,
        chrlength,
        gc_content
    )
    ch_versions  = ch_versions.mix(PREPROCESSING.out.versions)

    if (!params.runQualityCheckOnly){

        snp_haplotypes_ch = Channel.empty()
        haploblocks_ch    = Channel.empty()
        
        //
        // SUBWORKFLOW: PHASING: Call mpileup and beagle
        //
            
        // brach samples for sexes
        // discuss about klinefelter case (XXY)
        // if female or klinefelter
        sex_sample_ch = ch_sample.join(SNV_CALLING.out.ch_sex)
        ch_sample     = sex_sample_ch.join(SNV_CALLING.out.all_snp) 
        ch_sample.branch{
            male:  it[5].readLines().get(0) == "male"
            female: it[5].readLines().get(0) == "female" || it[5].readLines().get(0) == "klinefelter"
            other: true}
            .set{sex}

        if(params.beagle_ref){
            beagle_ref.map{it -> tuple ([id:"beagle"], it) }.groupTuple().set{beagle_ref_ch}
        }
        
         if(params.plink_map){
            plink_map.map{it -> tuple ([id:"plink"], it) }.groupTuple().set{plink_map_ch}
        }    

        PREPARE_BEAGLE_REF_1(
            beagle_ref_ch,
            "beagle_dir"
            )

        PREPARE_BEAGLE_REF_2(
            plink_map_ch,
            "plink_dir"
            )
        // Run phasing for female samples
        
        PHASING_X(
            sex.female,
            ref, 
            chrlength,
            PREPARE_BEAGLE_REF_1.out.dir,
            PREPARE_BEAGLE_REF_2.out.dir,
            dbsnpsnv,
            chrprefix
        )
        ch_versions       = ch_versions.mix(PHASING_X.out.versions)
        snp_haplotypes_ch = snp_haplotypes_ch.mix(PHASING_X.out.ch_snp_haplotypes)
        haploblocks_ch    = haploblocks_ch.mix(PHASING_X.out.ch_haploblocks)

        // Run phasing for male samples
        PHASING_Y(
            sex.male,
            ref, 
            chrlength,
            PREPARE_BEAGLE_REF_1.out.dir,
            PREPARE_BEAGLE_REF_2.out.dir,
            dbsnpsnv,
            chrprefix
        )
        ch_versions     = ch_versions.mix(PHASING_Y.out.versions)
        snp_haplotypes_ch = snp_haplotypes_ch.mix(PHASING_Y.out.ch_snp_haplotypes)
        haploblocks_ch    = haploblocks_ch.mix(PHASING_Y.out.ch_haploblocks)
        
        //
        // SUBWORKFLOW: SEGMENTATION: 
        //
        PREPROCESSING.out.windows_corrected
                        .join(PREPROCESSING.out.qual_corrected)
                        .join(snp_haplotypes_ch)
                        .join(haploblocks_ch)
                        .join(SNV_CALLING.out.ch_sex)
                        .set{segments_ch}  
        
        SEGMENTATION(
            PREPROCESSING.out.windows_corrected,
            PREPROCESSING.out.qual_corrected,
            snp_haplotypes_ch,
            haploblocks_ch,
            SNV_CALLING.out.ch_sex,
            centromers,
            chrlength,
            mapability,
            chrprefix
        )
        ch_versions     = ch_versions.mix(SEGMENTATION.out.versions)

        //
        // SUBWORKFLOW: PURITY_EVALUATION: 
        //
        PURITY_EVALUATION(
            SEGMENTATION.out.ch_clustered_segments,
            SEGMENTATION.out.ch_sv_points,
            SEGMENTATION.out.ch_all_snp_update3,
            SNV_CALLING.out.ch_sex,
            PREPROCESSING.out.all_corrected,
            chrlength
        )
        ch_versions     = ch_versions.mix(PURITY_EVALUATION.out.versions)

        //
        // SUBWORKFLOW: HDR_ESTIMATION: 
        //

        HDR_ESTIMATION(
            PURITY_EVALUATION.out.json_report,
            PURITY_EVALUATION.out.hdr_files,
            blacklist,
            SNV_CALLING.out.ch_sex,
            centromers,
            cytobands,
            chrprefix
        )
    }
    else{
        println "Only quality check is performed since runQualityCheckOnly is set to ${params.runQualityCheckOnly}"
    }

    //
    // MODULE: CUSTOM_DUMPSOFTWAREVERSIONS
    //
    // Collects versions
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    if (!params.skip_multiqc){
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

        MULTIQC (
            ch_multiqc_files.collect(),
            ch_multiqc_config.toList(),
            ch_multiqc_custom_config.toList(),
            ch_multiqc_logo.toList()
        )
        multiqc_report = MULTIQC.out.report.toList()

    }
    else{
        println "Skipping MultiQC"
    }

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
