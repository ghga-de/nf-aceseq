#!/bin/bash

# Copyright (c) 2017 The ACEseq workflow developers.
# Distributed under the MIT License (license terms are at https://www.github.com/eilslabs/ACEseqWorkflow/LICENSE.txt).

[[ -z ${PARM_CHR_INDEX-} ]] && echo "PARM_CHR_INDEX variable is missing" && exit -5

tmpFileSnpPos=${FILENAME_SNP_POS}_tmp
tmpFileCovWin=${FILENAME_COV_WIN}_tmp

source ${TOOL_ANALYZE_BAM_HEADER}
getRefGenomeAndChrPrefixFromHeader ${FILE_TUMOR_BAM} # Sets CHR_PREFIX and REFERENCE_GENOME

CHR_NR=${CHR_PREFIX}${CHR_NAME:?CHR_NAME is not set}
isNoControlWorkflow=${isNoControlWorkflow^}

if [[ $isNoControlWorkflow == "True" ]]; then
    BAM_FILES=${FILE_TUMOR_BAM}
    WITHOUT_CONTROL_PARAMETER="--withoutcontrol"
else
    BAM_FILES="${FILE_CONTROL_BAM} ${FILE_TUMOR_BAM}"
    WITHOUT_CONTROL_PARAMETER=""
fi

 $SAMTOOLS_BINARY mpileup ${CNV_MPILEUP_OPTS} \
-f "${REFERENCE_GENOME}" \
-r ${CHR_NR} \
${BAM_FILES} \
| ${PYTHON_BINARY} ${TOOL_SNP_POS_CNV_WIN_GENERATOR} \
--quality $mpileup_qual \
--dbsnp "${dbSNP_FILE}" \
--infile - \
--outsnps ${tmpFileSnpPos} \
--outcov ${tmpFileCovWin} \
${WITHOUT_CONTROL_PARAMETER}

if [[ "$?" != 0 ]]
then
	echo "There was a non-zero exit code in the snv/cnv mpileup; exiting..."
	exit 2
fi

mv $tmpFileSnpPos ${FILENAME_SNP_POS}
mv $tmpFileCovWin ${FILENAME_COV_WIN}
