set -euo pipefail
# Copyright (c) 2017 The ACEseq workflow developers.
# Distributed under the MIT License (license terms are at https://www.github.com/eilslabs/ACEseqWorkflow/LICENSE.txt).

usage() { echo "Usage: $0 [-p pid] [-i jsonfile] [-m legacyMode] [-b blacklistFileName] [-s sexfile] [-c centromers] [-y cytobandsFile] [-x chrprefix]" 1>&2; exit 1; }

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
		-y)
			cytobandsFile=$2
			shift # past argument
	    	shift # past value
			;;
		-x)
			chrprefix=$2
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
        cat ${COMBPROFILE_FIFO} | awk 'BEGIN{ FS="\t"; OFS="\t" } FNR==1{ for (col=1; col<=NF; ++col) if ($col == "crest") $col = "SV.Type"; } {print}' >$combProFile.tmp &
        pid_legacyMode=$!
    else
        cat ${COMBPROFILE_FIFO} >$combProFile.tmp &
        pid_legacyMode=$!
	fi

	bedtools intersect -header -v -f 0.7 \
				     -a $combProFile -b $blacklistFileName \
				     >${COMBPROFILE_FIFO}

	echo "bedtools intersect done"

	if [[ "$?" != 0 ]]
	then
		echo "There was a non-zero exit code intersecting with bedfile" 
		exit 2
	fi
    wait ${pid_legacyMode}; [[ ! $? -eq 0 ]] && echo "Error in legacyMode transcoding process" && exit 10
    rm ${COMBPROFILE_FIFO}

	#smooth Data
	removeBreakpoints.py -f $combProFile.tmp -o $combProFile.tmp.tmp
    [[ "$?" != 0 ]] && echo "There was a non-zero exit code while removing breakpoints (first time)" && exit 2
	mv $combProFile.tmp.tmp $combProFile.tmp
	mergeArtifacts.py -f $combProFile.tmp -o $combProFile.tmp.tmp
	[[ "$?" != 0 ]] && echo "There was a non-zero exit code while merging artifacts" && exit 2
	mv $combProFile.tmp.tmp $combProFile.tmp
	removeBreakpoints.py -f $combProFile.tmp -o $combProFile.tmp.tmp
	[[ "$?" != 0 ]] && echo "There was a non-zero exit code while removing breakpoints (second time)" && exit 2
	mv $combProFile.tmp.tmp $combProFile.tmp

	echo "smooth data done"

	(head -1 $combProFile.tmp ; tail -n +2 $combProFile.tmp | sort -k 1,1 -V -k 2,2n ) >$combProFileNoArtifacts

	if [[ "$?" != 0 ]]
	then
		echo "There was a non-zero exit code while sorting segment file" 
		exit 2
	fi

	#this file could be written out and sorted according to chromosomes
	smoothData.py -f $combProFile.tmp -p $chrprefix  -o $combProFile.tmp.tmp && mv $combProFile.tmp.tmp $combProFile.tmp && \
	removeBreakpoints.py -f $combProFile.tmp -o $combProFile.tmp.tmp && mv $combProFile.tmp.tmp $combProFile.tmp
	if [[ "$?" != 0 ]]
	then
		echo "There was a non-zero exit code while smoothing segments" 
		exit 2
	fi

	echo "remove breaks done"

	if [[ "$?" != 0 ]]
	then
		echo "There was a non-zero exit code getting patient sex" 
		exit 2
	fi

	echo "before hdr estimation"
	HRD_estimation.R \
		$combProFileNoArtifacts \
		${combProFile}.tmp \
		$gender \
		$ploidy \
		$tcc \
		$pid \
		${pid}_HRDscore_${ploidyFactor}_${tcc}.txt \
		${pid}_HRDscore_contributingSegments_${ploidyFactor}_${tcc}.txt \
		${pid}_LSTscore_contributingSegments_${ploidyFactor}_${tcc}.CentromerReduced.txt \
		${pid}_comb_pro_extra${ploidyFactor}_${tcc}.smoothed.CentromerReduced.txt \
		${centromers} \
		${cytobandsFile} \
		.
	echo "after hdr estimation"

	if [[ "$?" != 0 ]]
	then
		echo "There was a non-zero exit code while estimating HRD score" 
		exit 2
	fi

	(head -1 $combProFile.tmp ; tail -n +2 $combProFile.tmp | sort -k 1,1 -V -k 2,2n ) \
		>$combProFileNew

	if [[ "$?" != 0 ]]
	then
		echo "There was a non-zero exit code while sorting segment file" 
		exit 2
	fi

done
if [[ "$?" != 0 ]]
then
	echo "There was a non-zero exit code while processing solutions" 
	exit 2
fi
rm ${jsonfile}.txt 