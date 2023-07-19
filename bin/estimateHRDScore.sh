set -euo pipefail
# Copyright (c) 2017 The ACEseq workflow developers.
# Distributed under the MIT License (license terms are at https://www.github.com/eilslabs/ACEseqWorkflow/LICENSE.txt).

usage() { echo "Usage: $0 [-p pid] [-i jsonfile] [-m legacyMode] [-b blacklistFileName] [-s sexfile] [-c centromers]" 1>&2; exit 1; }

while [[ $# -gt 0 ]]
do
  key=$1
  case $key in
  		-p)
			pid=$2
			shift # past argument
	    	shift # past value
			;;
		-i)
			jsonfile=$2
			shift # past argument
	    	shift # past value
			;;
		-m)
			legacyMode=$2
			shift # past argument
	    	shift # past value
			;;
		-b)
			blacklistFileName=$2
			shift # past argument
	    	shift # past value
			;;
		-s)
			sexfile=$2
			shift # past argument
	    	shift # past value
			;;
		-c)
			centromers=$2
			shift # past argument
	    	shift # past value
			;;
	esac
done


parseJson.py -f ${jsonfile} >${jsonfile}.txt
cat ${jsonfile}.txt | while read line
do
	solutions=$line
	for item in ${solutions[@]}; do
		eval $item
	done
	echo "Evaluation of solutions is compleate"
	combProFile=${pid}_comb_pro_extra${ploidyFactor}_${tcc}.txt

	##remove artifact regions
	combProFileNew=${pid}_comb_pro_extra${ploidyFactor}_${tcc}.smoothed.txt
	combProFileNoArtifacts=${pid}_comb_pro_extra${ploidyFactor}_${tcc}.smoothed.noartifacts.txt

	COMBPROFILE_FIFO=combProFile_FIFO
	if [[ -p ${COMBPROFILE_FIFO} ]]; then rm ${COMBPROFILE_FIFO}; fi
	mkfifo ${COMBPROFILE_FIFO}

    if [[ ${legacyMode} == 'true' ]]; then
        # replace 'crest' column name by the new name 'SV.Type'
        cat ${COMBPROFILE_FIFO} | awk 'BEGIN{ FS="\t"; OFS="\t" } FNR==1{ for (col=1; col<=NF; ++col) if ($col == "crest") $col = "SV.Type"; } {print}' >$combProFile.txt &
        pid_legacyMode=$!
    else
        cat ${COMBPROFILE_FIFO} >$combProFile.txt &
        pid_legacyMode=$!
	fi

	bedtools intersect -header -v -f 0.7 \
				     -a $combProFile -b $blacklistFileName \
				     >${COMBPROFILE_FIFO}


	if [[ "$?" != 0 ]]
	then
		echo "There was a non-zero exit code intersecting with bedfile" 
		exit 2
	fi
    wait ${pid_legacyMode}; [[ ! $? -eq 0 ]] && echo "Error in legacyMode transcoding process" && exit 10
    rm ${COMBPROFILE_FIFO}

	#smooth Data
	removeBreakpoints.py -f $combProFile.txt -o $combProFile.txt.txt
    [[ "$?" != 0 ]] && echo "There was a non-zero exit code while removing breakpoints (first time)" && exit 2
	mv $combProFile.txt.txt $combProFile.txt
	mergeArtifacts.py -f $combProFile.txt -o $combProFile.txt.txt
	[[ "$?" != 0 ]] && echo "There was a non-zero exit code while merging artifacts" && exit 2
	mv $combProFile.txt.txt $combProFile.txt
	removeBreakpoints.py -f $combProFile.txt -o $combProFile.txt.txt
	[[ "$?" != 0 ]] && echo "There was a non-zero exit code while removing breakpoints (second time)" && exit 2
	mv $combProFile.txt.txt $combProFile.txt


	(head -1 $combProFile.txt ; tail -n +2 $combProFile.txt | sort -k 1,1 -V -k 2,2n ) >$combProFileNoArtifacts

	if [[ "$?" != 0 ]]
	then
		echo "There was a non-zero exit code while sorting segment file" 
		exit 2
	fi

	#this file could be written out and sorted according to chromosomes
	smoothData.py -f $combProFile.txt  -o $combProFile.txt.txt && mv $combProFile.txt.txt $combProFile.txt  && \
	removeBreakpoints.py -f $combProFile.txt -o $combProFile.txt.txt && mv $combProFile.txt.txt $combProFile.txt
	if [[ "$?" != 0 ]]
	then
		echo "There was a non-zero exit code while smoothing segments" 
		exit 2
	fi


    patientsex=`cat ${sexfile:-iDoNotExist.txt}`

	if [[ "$?" != 0 ]]
	then
		echo "There was a non-zero exit code getting patient sex" 
		exit 2
	fi

	HRDFile=${pid}_HRDscore_${ploidyFactor}_${tcc}.txt
	HRD_DETAILS_FILE=${pid}_HRDscore_contributingSegments_${ploidyFactor}_${tcc}.txt
	LST_DETAILS_FILE=${pid}_LSTscore_contributingSegments_${ploidyFactor}_${tcc}.CentromerReduced.txt
	MERGED_REDUCED_FILE=${pid}_comb_pro_extra${ploidyFactor}_${tcc}.smoothed.CentromerReduced.txt

	HRD_estimation.R \
		 $combProFileNoArtifacts \
		 ${combProFile}.txt \
		 $patientsex \
		 $ploidy \
		 $tcc \
		 $pid \
		 ${HRDFile}.txt \
		 ${HRD_DETAILS_FILE}.txt \
		 ${LST_DETAILS_FILE}.txt \
		 ${MERGED_REDUCED_FILE}.txt \
		 ${centromers} \
		 ${cytobandsFile} \
		 .


	if [[ "$?" != 0 ]]
	then
		echo "There was a non-zero exit code while estimating HRD score" 
		exit 2
	fi

	(head -1 $combProFile.txt ; tail -n +2 $combProFile.txt | sort -k 1,1 -V -k 2,2n ) \
		>$combProFileNew

	if [[ "$?" != 0 ]]
	then
		echo "There was a non-zero exit code while sorting segment file" 
		exit 2
	fi

	mv ${HRDFile}.txt ${HRDFile}
	mv ${HRD_DETAILS_FILE}.txt ${HRD_DETAILS_FILE}
	mv ${LST_DETAILS_FILE}.txt ${LST_DETAILS_FILE}
	mv ${MERGED_REDUCED_FILE}.txt ${MERGED_REDUCED_FILE}
	rm ${combProFile}.txt
done
if [[ "$?" != 0 ]]
then
	echo "There was a non-zero exit code while processing solutions" 
	exit 2
fi
rm ${jsonfile}.txt 