set -euo pipefail
# Copyright (c) 2017 The ACEseq workflow developers.
# Distributed under the MIT License (license terms are at https://www.github.com/eilslabs/ACEseqWorkflow/LICENSE.txt).

usage() { echo "Usage: $0 [-r ref]" 1>&2; exit 1; }

while [[ $# -gt 0 ]]
do
  key=$1
  case $key in
  		-r)
			ref=$2
			shift # past argument
	    	shift # past value
			;;
	esac
done

if [[ ${ref} == 'hg38' ]]; then
  for i in {1..22}; do
    echo $i
    wget http://bochet.gcc.biostat.washington.edu/beagle/1000_Genomes_phase3_v5a/b37.bref3/chr$i.1kg.phase3.v5a.b37.bref3
  done

  wget http://bochet.gcc.biostat.washington.edu/beagle/1000_Genomes_phase3_v5a/b37.bref3/chrX.1kg.phase3.v5a.b37.bref3
  wget http://bochet.gcc.biostat.washington.edu/beagle/1000_Genomes_phase3_v5a/b37.bref3/chrY.1kg.phase3.v5a.b37.bref3

  wget http://bochet.gcc.biostat.washington.edu/beagle/genetic_maps/plink.GRCh37.map.zip

  unzip plink.GRCh37.map.zip

else

  for i in {1..22}; do
    echo $i
    wget http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/1000_genomes_project/release/20190312_biallelic_SNV_and_INDEL/ALL.chr${i}.shapeit2_integrated_snvindels_v2a_27022019.GRCh38.phased.vcf.gz
    (zcat ALL.chr${i}.shapeit2_integrated_snvindels_v2a_27022019.GRCh38.phased.vcf.gz | head -n 300 | grep "#" ; zcat ALL.chr${i}.shapeit2_integrated_snvindels_v2a_27022019.GRCh38.phased.vcf.gz | grep -v "#" | sed 's/^/chr/') | java -jar bref3.18May20.d20.jar > ALL.chr${i}.shapeit2_integrated_snvindels_v2a_27022019.GRCh38.phased.CHR.bref3
  done
  
  wget http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/1000_genomes_project/release/20190312_biallelic_SNV_and_INDEL/ALL.chrX.shapeit2_integrated_snvindels_v2a_27022019.GRCh38.phased.vcf.gz
  wget http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/1000_genomes_project/release/20190312_biallelic_SNV_and_INDEL/ALL.chrY.shapeit2_integrated_snvindels_v2a_27022019.GRCh38.phased.vcf.gz

  wget http://bochet.gcc.biostat.washington.edu/beagle/genetic_maps/plink.GRCh38.map.zip

  unzip plink.GRCh38.map.zip

fi

