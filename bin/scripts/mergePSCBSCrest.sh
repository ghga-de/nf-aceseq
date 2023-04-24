#!/bin/bash

# Copyright (c) 2017 The ACEseq workflow developers.
# Distributed under the MIT License (license terms are at https://www.github.com/eilslabs/ACEseqWorkflow/LICENSE.txt).

set -o pipefail

tmp_breakpoints=${FILENAME_BREAKPOINTS}.tmp
svPoints_tmp=${FILENAME_SV_POINTS}.tmp

if [[ "${SV}" == 'true' ]]
then
	${PYTHON_BINARY} "${TOOL_ADD_CREST_TO_PSCBS_GAPS}" \
            --crest_deldupinv "${FILENAME_CREST_DELDUPINV}" \
            --crest_tx        "${FILENAME_CREST_TRANSLOC}" \
            --known_segments  "${FILENAME_KNOWNSEGMENTS}" \
            --output          "${tmp_breakpoints}" \
            --crest_out       "${svPoints_tmp}" \
            --DDI_length      $min_DDI_length 
else
	cp ${FILENAME_KNOWNSEGMENTS} ${tmp_breakpoints}
	sed -i '1s/^chr/#chr/' ${tmp_breakpoints}
	echo "" > "${svPoints_tmp}"

fi


if [[ "$?" != 0 ]]
then
	echo "There was a non-zero exit code while merging PSCBS with CREST;" 
	exit 2
fi

 mv ${tmp_breakpoints} ${FILENAME_BREAKPOINTS}
 mv ${svPoints_tmp} ${FILENAME_SV_POINTS}




