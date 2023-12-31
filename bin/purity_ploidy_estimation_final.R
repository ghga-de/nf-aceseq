#!/usr/bin/env Rscript

# Copyright (c) 2017 The ACEseq workflow developers.
# This script is licenced under (license terms are at
# https://www.github.com/eilslabs/ACEseqWorkflow/LICENSE.txt).

library(reshape)
library(reshape2)
library(ggplot2)
library(scales)
library(getopt)

script_dir = dirname(get_Rscript_filename())


spec <- matrix(c('segments',		's', 1, "character", #"IN: segment file",
		 'file_sex',		'f', 1, "character", #"IN: file with sex of patient",
		 'purity_ploidy',	'u', 1, "character", #"OUT: file with purities and ploidies",
		 'out',			'x', 1, "character", #"OUT: output directory",
		 'min_length_purity',	'l', 1, "numeric",   #"minimal length of segments to be considered for estimation",
		 'min_hetSNPs_purity',	'h', 1, "numeric",   #"minimum number of heterozygous SNPs in segments to be considered for estimation",
		 'dh_Stop',		'd', 1, "character", #"red line for DH boundary estimated by mean or max values",
		 'min_length_dh_stop',	'm', 1, "numeric",   #"minimum length of segment to be considered for border value (mean|max)",
		 'dh_zero',		'z', 1, "character", #"can dh be zero (yes|no)",
		 'purity_min',		'a', 1, "numeric",   #"minimum purity",
		 'purity_max',		'b', 1, "numeric",   #"maximium purity",
		 'ploidy_min',		'p', 1, "numeric",   #"minimum poidy",
		 'ploidy_max',		'q', 1, "numeric",   #"maximum ploidy",
		 'pid',			'i', 1, "character",  #"patient identifier",
		 'local_minium_upper_boundary_shift', 'c', 1, "numeric"  #"IN: only solutions with local minimum < min(sel_local_minima) + local_minium_upper_boundary_shift will be considered"
                ), ncol = 4, byrow = TRUE)

opt = getopt(spec);
for(item in names(opt)){
       assign( item, opt[[item]])
}

cat(paste0("segments: ", segments, "\n\n"))
cat(paste0("sex: ", file_sex, "\n\n"))
cat(paste0("purity_ploidy_out: ", purity_ploidy, "\n\n"))
cat(paste0("out: ", out, "\n\n"))
cat(paste0("min_length_purity: ", min_length_purity, "\n\n"))
cat(paste0("min_hetSNPs_purity: ", min_hetSNPs_purity, "\n\n"))
cat(paste0("dh_Stop: ", dh_Stop, "\n\n"))
cat(paste0("min_length_dh_stop: ", min_length_dh_stop, "\n\n"))
cat(paste0("dh_zero: ", dh_zero, "\n\n"))
cat(paste0("purity_min: ", purity_min, "\n\n"))
cat(paste0("purity_max: ", purity_max, "\n\n"))
cat(paste0("ploidy_min: ", ploidy_min, "\n\n"))
cat(paste0("ploidy_max: ", ploidy_max, "\n\n"))
cat(paste0("local_minium_upper_boundary_shift: ", local_minium_upper_boundary_shift, "\n\n"))
cat(paste0("pid: ",pid, "\n\n"))

#functions
getD   = function(alpha, P) 		    alpha * P + 2 * (1-alpha)  
getTCN = function(tcnMean, D, alpha) (tcnMean * D - 2*(1-alpha)) / alpha
getAF  = function(meanCovT, TCN, alpha)	    (meanCovT / 10000) / (alpha * as.numeric(TCN) + 2*(1-alpha))
getBAF = function(meanCovB, TCN, AF, alpha) (meanCovB / AF - (1-alpha)) / (alpha * as.numeric(TCN))
getDH  = function(BAF) 			    2 * (abs(BAF - 0.5))
getC1  = function(DH, TCN) 		    0.5 * ( 1 - as.numeric(DH) ) * as.numeric(TCN)


segments = read.table(segments, sep = "\t", as.is = TRUE, header = TRUE)
combi = data.frame(segments)
chromosomes = c(1:24)

### segments for automatic ploidy and purity determination                                                                        

sel = which(combi$length > min_length_purity & 
            combi$tcnNbrOfHets > min_hetSNPs_purity & 
            combi$map == "mappable" & 
            (combi$peaks == 1 | combi$peaks == 2) & 
            combi$chromosome != 24  ) # filtering according to length, mappability and defined peaks 

#remove segments on chromosome 23 for male patients
sex = read.table(file_sex, header=FALSE, stringsAsFactors=FALSE)[,1]

if ( sex == 'male' ) {
	s = which( combi$chromosome[sel] == 23 )
  if (length(s) >0 ){
  	sel <- sel[-s]
  }
}

#exit if no segments with peaks and other requirements found
if ( length(sel) == 0 ){
	cat ("WARNING: no segments thath fullfill requirements found, check mappability and required coverage in functions.R\n\n")
	q(save='no', status=2)	
}

testSet = combi[sel, , drop = FALSE] # new filtered data set for determining the ploidy and purity

one = which(testSet$peaks == 1)
two = which(testSet$peaks == 2)

if (length(one) > length(two)) {
	peaks = "balanced"
	full_Ploidies = c(2, 4, 6, 8)
} else if (length(one) < length(two)) {
	peaks = "unbalanced"
	full_Ploidies = c(3, 5, 7)
} else if (length(one) == length(two)) {
	peaks = "(un)balanced"
	full_Ploidies = c(2:8)
}

#step=0.001

posPloidies = seq(from = ploidy_min, to = ploidy_max, by = 0.01) #1.6 4.5
posPurities = seq(from = purity_min, to = purity_max, by = 0.01)                   
#posPurities <- seq(from = 0.1, to = 1, by = 0.01) 

testSet_anti = testSet


############## aberrant segments

# matrices                                             
matrix_col = length(posPurities) * length(posPloidies) + 1

TCNmatrix = matrix(data = 0, nrow = nrow(testSet_anti), ncol = matrix_col, byrow = FALSE, dimnames = NULL)
DISTmatrix = matrix(data = 0, nrow = nrow(testSet_anti), ncol = matrix_col, byrow = FALSE, dimnames = NULL)
AFmatrix = matrix(data = 0, nrow = nrow(testSet_anti), ncol = matrix_col, byrow = FALSE, dimnames = NULL)
BAFmatrix = matrix(data = 0, nrow = nrow(testSet_anti), ncol = matrix_col, byrow = FALSE, dimnames = NULL)
DHmatrix = matrix(data = 0, nrow = nrow(testSet_anti), ncol = matrix_col, byrow = FALSE, dimnames = NULL)
MEANmatrix = matrix(data = 0, nrow = 1, ncol = matrix_col, byrow = FALSE, dimnames = NULL)

roundTCNmatrix = matrix(data = 0, nrow = nrow(testSet_anti), ncol = matrix_col, byrow = FALSE, dimnames = NULL)
dhDISTmatrix = matrix(data = 0, nrow = nrow(testSet_anti), ncol = matrix_col, byrow = FALSE, dimnames = NULL)
dhMEANmatrix = matrix(data = 0, nrow = 1, ncol = matrix_col, byrow = FALSE, dimnames = NULL)
dh_matrix = matrix(data = 0, nrow = 1, ncol = matrix_col, byrow = FALSE, dimnames = NULL)
tcn_matrix = matrix(data = 0, nrow = 1, ncol = matrix_col, byrow = FALSE, dimnames = NULL)

TCNmatrix[, 1] = as.numeric(testSet_anti$peaks)
DISTmatrix[, 1] = testSet_anti$length
AFmatrix[, 1] = testSet_anti$length
BAFmatrix[, 1] = testSet_anti$length
DHmatrix[, 1] = testSet_anti$length
roundTCNmatrix[, 1] = as.numeric(testSet_anti$peaks)
dhDISTmatrix[, 1] = as.numeric(testSet_anti$peaks)
segLength <- testSet_anti$length


i = 1
a = 0

for (ploidy in posPloidies) { 
	a = a + 1
	cat(paste0("ploidy_", ploidy, "\n\n"))
	
	for (purity in posPurities) 	{

		i = i + 1
		D = getD(purity, ploidy)
		TCNmatrix[, i] = getTCN(testSet_anti$tcnMean,D, purity) 
		AFmatrix[, i]  = getAF(testSet_anti$meanCovT, TCNmatrix[,i], purity)
		BAFmatrix[, i] = getBAF(testSet_anti$meanCovB,TCNmatrix[,i], AFmatrix[,i], purity) 
		DHmatrix[, i]  = getDH(BAFmatrix[,i])

		pos = which(TCNmatrix[, 1] == 1)
		DHmatrix[pos, i] = 0

		pos1 = which((round(as.numeric(TCNmatrix[, i])) == round(ploidy)) & (TCNmatrix[, 1] == 2)) 
		pos2 = which(round(as.numeric(TCNmatrix[, i])) != round(ploidy))
		# TCN of 0 causes DH=inf and c1=NaN; so skip these cases
		pos_forbidden = which(as.numeric(TCNmatrix[, i]) == 0)
		pos = setdiff(union(pos1, pos2),pos_forbidden)

		### Distance matrix for TCN & median distance matrix

		for (p in seq_along(pos)) {
			artificialTCN = NULL
			#set artificial TCN in case TCN calc is negative
			if ( TCNmatrix[pos[p], i] < 0 ) {

  				if (TCNmatrix[pos[p], 1] == 1) {
					#most likely: homozygous del, stroma mapped to region
					#only exclude if value deviates mmore than 0.3 from 0
					if ( TCNmatrix[pos[p], i] < -0.3 ) {
        					tcn_matrix[,i] = 20
					}
					artificialTCN = 0
        				DISTmatrix[pos[p], i] = 2*abs( as.numeric( TCNmatrix[pos[p],i] ) - artificialTCN )

	  		  	} else if (TCNmatrix[pos[p], 1] == 2) {
					#exclude as value is too
        				tcn_matrix[,i] = 20

					#one allele copy must be present other could be deleted
		    			artificialTCN = 1	
        				DISTmatrix[pos[p], i] = 2*abs( as.numeric( TCNmatrix[pos[p],i] ) - artificialTCN )
			  	}
          
			} else {			
				if (TCNmatrix[pos[p], 1] == 1) {

				    	r = as.numeric(TCNmatrix[pos[p],i])/2 - floor(as.numeric(TCNmatrix[pos[p], i]) / 2)
				    	#multiply with 2 because TCN number has been halfed and thus distance has been halfed
		          		#multiply with 2 again to make up for allele specific copy number used for unbalanced segments
    					if (r <= 0.5) {
    						DISTmatrix[pos[p], i] = r * 2 * 2
    					} else {
    						DISTmatrix[pos[p], i] = (1 - r) * 2 * 2
    					}
				} else if (TCNmatrix[pos[p], 1] == 2) {

					# in case TCN is zero but segment is called imbalanced it cannot be due to contamination from the heterozygous control
				    	# should be punished accordingly to negative TCN in case of an imbalance
			      		if ( TCNmatrix[pos[p],i]==0 ){
						tcn_matrix[,i] = 20
						artificialTCN = 1
						DISTmatrix[pos[p], i] = 2*abs( as.numeric( TCNmatrix[pos[p],i] ) - artificialTCN )
					} else if ( ! is.na(DHmatrix[pos[p],i]) ){
						#estimate allele specific copy numbers
  					 	c1 = getC1(DHmatrix[pos[p],i], TCNmatrix[pos[p],i]) 
  					 	c2 = as.numeric( TCNmatrix[pos[p], i] ) - c1
						
						#copy number can be negative in case of large (>1) DH values
						if ( c1 < 0 ){
							if (c1 < -0.3) {
								tcn_matrix[,i] = 20
							}
							artificialTCN = 1
							r1 = abs(c1- artificialTCN)
						} else {
							r1 = abs(c1 - round(c1)) 
						}

						if ( c2 < 0 ){
							#should technicaly not be possible
							if (c2 < -0.3 | c1 < 0) {
								tcn_matrix[,i] = 20
							}

							artificialTCN = 1
							r2 = abs(c2- artificialTCN)
						} else {
							r2 = abs(c2 - round(c2)) 
						}
						r  = abs( as.numeric(TCNmatrix[ pos[p], i ]) - round( as.numeric(TCNmatrix[pos[p], i]) ) )
					 	DISTmatrix[ pos[p], i ] = ( r1 + r2 + r )

					} else {			
						#no heterozygous SNPs in this region
						r1 = abs( as.numeric(TCNmatrix[ pos[p], i ]) - round( as.numeric(TCNmatrix[pos[p], i]) ) )
						r2 = 0
						r  = abs( as.numeric(TCNmatrix[ pos[p], i ]) - round( as.numeric(TCNmatrix[pos[p], i]) ) )
					 	DISTmatrix[ pos[p], i ] = ( r1 + r2 + r )
					}
				}
			}
		}

		MEANmatrix[, i] = sum( DISTmatrix[pos, i] * log(segLength[pos])) / sum(log(segLength[pos]))  
		### Distance matrix for DH and median distance matrix

		roundTCNmatrix[, i] = round(as.numeric(TCNmatrix[, i]))
		pos = which(TCNmatrix[,1] == 2)
		for (p in seq_along(pos)) {
			if (TCNmatrix[pos[p], 1] == 1) {
			
				dhDISTmatrix[pos[p], i] = 0

			#get DH for unbalanced segments for all possible Allele distributions
			} else if (TCNmatrix[pos[p], 1] == 2) { 
				#explore possibilities only if TNC>0 else dhPossible=1
				j=1                     
				dhPossible = c() # vector containing possible DH values
				if (as.numeric(TCNmatrix[pos[p], i]) >= 0) { 
					x = as.numeric(roundTCNmatrix[pos[p], i])
					for (no in seq_len(x)) { 	#bludau: (no in 1:x) 
						BAFtmp = no / x
						
						if (is.na(BAFtmp)) {
							next
						} else if ( BAFtmp != (1/2) ) {
							dhTmp = 2*abs( BAFtmp - 0.5 )
							dhPossible[j] = dhTmp # all fractions smaller 1/2 are possible DH values for unbalanced segments => only smaller because less frequnt allele is used for BAF
							j = j+1
						} else {
							next
						}
					}
				}		
				dhPossible[j] = 1 # a DH value of 1 is possible for all unbalanced segments

				k = 1
				dists = c()
				for (dhP in dhPossible) {
					if (dh_zero == "yes") {
						dis = min(c(abs(DHmatrix[pos[p], i] - dhP), DHmatrix[pos[p], i])) # zero is allowed to account for subpopulations
						#DHmatrix[pos[p],i] is listed to allow a ture DH=0 (imbalanced signal caused by subpopulation in this case)
					} else if (dh_zero == "no") {
						dis = abs(DHmatrix[pos[p], i] - dhP)
					}
					
					dists[k] = dis
					k = k + 1
				}
				
				dhDISTmatrix[pos[p], i] = min(dists)
			}
		}

		dhMEANmatrix[, i] = sum( dhDISTmatrix[pos, i] * segLength[pos]) / sum(segLength[pos])
		# find mean/max dh for combination
		if (dh_Stop == "max") {
			#max to get border line of purity due to dh>1
			big = which(TCNmatrix[, 1] == 2 & DHmatrix[, 1] >= min_length_dh_stop)
	    		if (length(big) >0){
				dh_matrix[, i] = max(as.numeric(DHmatrix[big, i]), na.rm=TRUE)
			}
        } else if (dh_Stop == "quantile") {
            big = which(TCNmatrix[, 1] == 2 & DHmatrix[, 1] >= min_length_dh_stop)
            if (length(big) >0){
              dh_matrix[, i] = quantile(as.numeric(DHmatrix[big, i]), na.rm=TRUE, 0.975)
            }
		} else if (dh_Stop == "mean") {
			dh_matrix[, i] = mean(as.numeric(DHmatrix[pos, i]), na.rm=TRUE)
		}
	}
}

dist_TCN = matrix(data = MEANmatrix[1, 2:matrix_col], nrow = length(posPloidies), ncol = length(posPurities), byrow = TRUE, dimnames = NULL) ## variablen einfügen für row und col

dist_DH = matrix(data = dhMEANmatrix[1, 2:matrix_col], nrow = length(posPloidies), ncol = length(posPurities), byrow = TRUE, dimnames = NULL)

DH = matrix(data = dh_matrix[1, 2:matrix_col], nrow = length(posPloidies), ncol = length(posPurities), byrow = TRUE, dimnames = NULL)             
TCN = matrix(data = tcn_matrix[1, 2:matrix_col], nrow = length(posPloidies), ncol = length(posPurities), byrow = TRUE, dimnames = NULL)             

colnames(dist_TCN) = posPurities
rownames(dist_TCN) = posPloidies

colnames(dist_DH) = posPurities
rownames(dist_DH) = posPloidies

colnames(DH) = posPurities
rownames(DH) = posPloidies


cat(paste0("dist_DH ",dim(dist_DH), "\n\n"))
testPlot = melt(data.frame(dist_DH))
ploi = rep(posPloidies, length(posPurities))
testPlot$ploidy = ploi
colnames(testPlot) = c('purity', 'dh.distance', 'ploidy')
#### DH   
limitDH = rep(NA, length(posPloidies))
limitTCN = rep(NA, length(posPloidies))

#find purity at each ploidy for which border dh>1
###HOW CAN DH BE LARGER THAN 1? => low purity influences equation for BAF
# max(which(DH)) because it is the first value to be >1 no lower purities than that should be allowed
for (i in seq_along(posPloidies)) {
	if (any(DH[i,] > (1+1e-8) )) {
		limitDH[i] <- max(which(DH[i,] > (1+1e-8)))#+1
			
		if (limitDH[i] > length(DH[i,])) {
			limitDH[i] <- length(DH[i,])
		} 
	} else {
		limitDH[i] <- NA
	}
  if (any(TCN[i,]==20)){
    limitTCN[i] <- max(which(TCN[i,] == 20))#+1
    if (limitTCN[i] > length(TCN[i,])) {
      limitTCN[i] <- length(TCN[i,])
    }
    if( is.na(limitDH[i]) | limitTCN[i] > limitDH[i]){
      limitDH[i] <- limitTCN[i]
    }
  }
  
}
#defining red lines in plot
df.vlines <- data.frame(ploi=ploi, vline=limitDH)

# png(qq("@{out}/dh_ABERRANT_more.png"), width = 1200, height = 1200)
# ggplot(testPlot, aes(purity, ploidy)) + geom_tile(aes(fill = dh.distance), colour = "white") + 
# 	scale_fill_gradient(low = "white", high = "black", limits = c(0, 0.3), na.value = "black") + 
# 	theme(axis.text.x = element_text(angle = 90, vjust = 0.5, size = 10)) + 
# 	geom_errorbar(data = df.vlines, aes(x = vline, ymax = ploi, ymin = ploi), colour="#AA0000")
# dev.off() 
# 
# testPlot = melt(data.frame(dist_TCN))
# ploi = rep(posPloidies, length(posPurities))
# testPlot$ploidy = ploi
# colnames(testPlot) = c('purity', 'tcn.distance', 'ploidy')

# ####    
# png(qq("@{out}/tcn_ABERRANT_more.png"), width = 1200, height = 1200)
# ggplot(testPlot, aes(purity, ploidy)) + geom_tile(aes(fill = tcn.distance), colour = "white") +
# 	scale_fill_gradient(low = "white", high = "black", limits = c(0, 0.3), na.value = "black") + 
# 	theme(axis.text.x = element_text(angle = 90, vjust = 0.5, size = 10)) + 
# 	geom_errorbar(data = df.vlines, aes(x = vline, ymax = ploi, ymin = ploi), colour="#AA0000")
# dev.off() 

############ non-aberrant segments

# matrices                                             
Nmatrix_col = length(posPurities) * length(posPloidies) + 1

NTCNmatrix = matrix(data = 0, nrow = nrow(testSet_anti), ncol = matrix_col, byrow = FALSE, dimnames = NULL)
NDISTmatrix = matrix(data = 0, nrow = nrow(testSet_anti), ncol = matrix_col, byrow = FALSE, dimnames = NULL)
NAFmatrix = matrix(data = 0, nrow = nrow(testSet_anti), ncol = matrix_col, byrow = FALSE, dimnames = NULL)
NBAFmatrix = matrix(data = 0, nrow = nrow(testSet_anti), ncol = matrix_col, byrow = FALSE, dimnames = NULL)
NDHmatrix = matrix(data = 0, nrow = nrow(testSet_anti), ncol = matrix_col, byrow = FALSE, dimnames = NULL)
NMEANmatrix = matrix(data = 0, nrow = 1, ncol = matrix_col, byrow = FALSE,dimnames = NULL)

NroundTCNmatrix = matrix(data = 0, nrow = nrow(testSet_anti), ncol = matrix_col, byrow = FALSE, dimnames = NULL)
NdhDISTmatrix = matrix(data = 0, nrow = nrow(testSet_anti), ncol = matrix_col, byrow = FALSE, dimnames = NULL)
NdhMEANmatrix = matrix(data = 0, nrow = 1, ncol = matrix_col, byrow = FALSE, dimnames = NULL)
Ndh_matrix = matrix(data = 0, nrow = 1, ncol = matrix_col, byrow = FALSE, dimnames = NULL)
Ntcn_matrix = matrix(data = 0, nrow = 1, ncol = matrix_col, byrow = FALSE, dimnames = NULL)

NTCNmatrix[, 1] = as.numeric(testSet_anti$peaks)
NDISTmatrix[, 1] = testSet_anti$length
NAFmatrix[, 1] = testSet_anti$length
NBAFmatrix[, 1] = testSet_anti$length
NDHmatrix[, 1] = testSet_anti$length
NroundTCNmatrix[, 1] = as.numeric(testSet_anti$peaks)
NdhDISTmatrix[, 1] = as.numeric(testSet_anti$peaks)

i = 1
a = 0

for (ploidy in posPloidies) { 
	a = a + 1
	cat(paste0("ploidy_",ploidy, "\n\n"))
	
	for (purity in posPurities) {

		i = i + 1
		D = getD(purity, ploidy)
		NTCNmatrix[, i]  = getTCN(testSet_anti$tcnMean, D, purity)  
		NAFmatrix[ , i]  = getAF( testSet_anti$meanCovT, NTCNmatrix[,i], purity)
		NBAFmatrix[, i]  = getBAF(testSet_anti$meanCovB, NTCNmatrix[,i], NAFmatrix[, i], purity) 
		NDHmatrix[ , i]  = getDH(NBAFmatrix[, i])

		pos = which(NTCNmatrix[, 1] == 1)
		NDHmatrix[pos, i] = 0

		pos = which(round(as.numeric(NTCNmatrix[, i])) == round(ploidy) & NTCNmatrix[, 1] == 1)
		# TCN of 0 causes DH=inf and c1=NaN; so skip these cases
		pos_forbidden = which(as.numeric(NTCNmatrix[, i]) == 0)
		pos = setdiff(pos,pos_forbidden)

		### Distance matrix for TCN & median distance matrix

		for (p in seq_along(pos)) {
      			artificialTCN = NULL
			#set artificial TCN in case TCN calc is negative
			if ( NTCNmatrix[pos[p], i] < 0 ) {
				if (NTCNmatrix[pos[p], 1] == 1) {

					#most likely: homozygous del, e.g. stroma mapped to region
					#only exclude if value deviates mmore than 0.3 from 0
					if ( NTCNmatrix[pos[p], i] < -0.3 ) {
        					Ntcn_matrix[,i] = 20
					}
					artificialTCN = 0	
          				NDISTmatrix[pos[p], i] = 2*abs( as.numeric(NTCNmatrix[pos[p],i]) - artificialTCN )

				} else if (NTCNmatrix[pos[p], 1] == 2) {
					#one allele copy must be present other could be deleted
					Ntcn_matrix[,i] <- 20
					artificialTCN = 1
          				NDISTmatrix[pos[p], i] = 2*abs( as.numeric(NTCNmatrix[pos[p],i]) - artificialTCN )
				}
			}else{			
					if (NTCNmatrix[pos[p], 1] == 1) {
					  r = (as.numeric(NTCNmatrix[pos[p], i]) / 2) - floor(as.numeric(NTCNmatrix[pos[p], i]) / 2)
					
					if (r <= 0.5) {
						NDISTmatrix[pos[p], i] = r * 2 * 2
					} else {
						NDISTmatrix[pos[p], i] = (1 - r) * 2 *2
					}

				} else if (NTCNmatrix[pos[p], 1] == 2) {
					# in case TCN is zero but segment is called imbalanced it cannot be due to contamination from the heterozygous control
					# should be punished accordingly to negative TCN in case of an imbalance
					if( NTCNmatrix[pos[p],i] == 0 ){
							Ntcn_matrix[,i] = 20
						 	artificialTCN = 1
							NDISTmatrix[pos[p], i] = 2*abs( as.numeric( NTCNmatrix[pos[p],i] ) - artificialTCN )
					}else if( ! is.na(NDHmatrix[pos[p],i]) ){
						#estimate allele specific copy numbers
							
						c1 = getC1( NDHmatrix[pos[p], i], NTCNmatrix[pos[p], i] ) 
						c2 = as.numeric(NTCNmatrix[pos[p],i]) - as.numeric(c1)

						if ( c1 < 0 ){
							if ( c1 < -0.3 ) {
								Ntcn_matrix[,i] = 20
							}
							artificialTCN = 1 
							r1 = abs(c1 - artificialTCN)
						}else{
							r1 = abs(c1 - round(c1)) 
						}
						if ( c2 < 0 ){
							#should technichally not be possible
							if ( c2 < -0.3  | c1 < 0) {
								Ntcn_matrix[,i] = 20
							}
							artificialTCN = 1
							r2 = abs(c2 - artificialTCN)
						}else{
							r2 = abs(c2 - round(c2)) 
						}
				  		r = abs( as.numeric(NTCNmatrix[pos[p], i]) - round( as.numeric(NTCNmatrix[pos[p], i]) ) )
						NDISTmatrix[pos[p], i] = ( r1+r2 + r )
					}else{
						#no heterozygous SNPs in this region
						r1 = abs( as.numeric(NTCNmatrix[ pos[p], i ]) - round( as.numeric(NTCNmatrix[pos[p], i]) ) )
						r2 = 0
						r = abs( as.numeric(NTCNmatrix[pos[p], i]) - round( as.numeric(NTCNmatrix[pos[p], i]) ) )
						NDISTmatrix[pos[p], i] = ( r1+r2 + r )
					}
	
				}
			}
		}
		
		NMEANmatrix[, i] = sum( NDISTmatrix[pos, i] * log(segLength[pos]))/sum( log(segLength[pos]) )

		### Distance matrix for DH and median distance matrix
		#not necessary as dh is 0 for all balanced segments
		NroundTCNmatrix[, i] = round(as.numeric(NTCNmatrix[, i]))                 
	
	}
}

Ndist_TCN = matrix(data = NMEANmatrix[1, (2:Nmatrix_col)], nrow = length(posPloidies), ncol = length(posPurities), byrow = TRUE, dimnames = NULL) ## variablen einfügen für row und col
colnames(Ndist_TCN) = posPurities
rownames(Ndist_TCN) = posPloidies

NTCN = matrix(data = Ntcn_matrix[1, 2:matrix_col], nrow = length(posPloidies), ncol = length(posPurities), byrow = TRUE, dimnames = NULL)

limitDHOrig = limitDH

  # max(which(NTCN)) because it is the first value to be >1 no lower purities than that should be allowed
# that means the distance has been significantly different from 0
limitNTCN = rep(NA, length(posPloidies))
for (i in seq_along(posPloidies)) {
  if (any(NTCN>(1+1e-8))){
    limitNTCN[i] <- max(which(NTCN[i,] > (1+1e-8)))#+1
    if (limitNTCN[i] > length(NTCN[i,])) {
      limitNTCN[i] <- length(NTCN[i,])
    }
    if( is.na(limitDH[i]) | limitNTCN[i] > limitDH[i]){
      limitDH[i] <- limitNTCN[i]
    }
  }
  
}

#plot distances for TCN of non-aberrant segments (0 for all DH)

testPlot = melt(data.frame(Ndist_TCN))
ploi = rep(posPloidies, length(posPurities))
testPlot$ploidy = ploi
colnames(testPlot) = c('purity', 'tcn.distance', 'ploidy')
####limits can be taken over from aberrant segments
df.vlines = data.frame(ploi = ploi, vline = limitDH)

png(paste0(out, "/", pid, "_tcn_NON_ABERRANT_n_more.png"), width = 1200, height = 1200, type='cairo')
print( ggplot(testPlot, aes(purity, ploidy)) + geom_tile(aes(fill = tcn.distance), colour =   "white") + 
	scale_fill_gradient(low = "white", high = "black", limits=c(0, 0.2), na.value = "black") + 
	theme(axis.text.x = element_text(angle = 90, vjust = 0.5, size = 10)) + 
	geom_errorbar(data = df.vlines, aes(x = vline, ymax = ploi, ymin = ploi), colour = "#AA0000")
)
dev.off()
	
	
#combine TCN distances aberrant and non-aberrant
  
COMBI_DIST_TCN = Ndist_TCN + dist_TCN
COMBI_DIST_TCN[is.na(Ndist_TCN)] <- dist_TCN[ is.na(Ndist_TCN)]
COMBI_DIST_TCN[is.na(dist_TCN)]  <- Ndist_TCN[ is.na(dist_TCN)]

plotPurities = c()

for (l in seq_along(limitDH)) {
  if( is.na(limitDH[l]) ){
    plotPurities[l] = NA
  }else
	  plotPurities[l] = posPurities[limitDH[l]]
}

df.lines = data.frame(ploidy = ploi, purity = plotPurities)
df.lines = df.lines[order(df.lines$ploidy), ]

testPlot = melt(data.frame(COMBI_DIST_TCN))
testPlotploi = rep(posPloidies, length(posPurities))
testPlot$ploidy = testPlotploi
names(testPlot) = c("purity", "distance", "ploidy")
testPlot$purity = substring(testPlot$purity, 2, 5)
testPlot$purity = as.numeric(testPlot$purity)
png(paste0("",out, "/",pid, "_tcn_distances_combined.png"), width = 1200, height = 1200, type='cairo')
erupt = ggplot(testPlot, aes(purity, ploidy, fill = distance)) +
	geom_tile() + 
	scale_x_continuous(expand = c(0 ,0)) + 
	scale_y_continuous(expand = c(0, 0))
print( erupt + scale_fill_gradient2(limits = c(0, max(testPlot$distance, na.rm=TRUE)),midpoint = mean(testPlot$distance[which(!is.na(testPlot$distance))])/2, low = "darkred", high = "darkblue", na.value = "darkblue") + 
	theme(axis.text.x = element_text(angle = 90, vjust = 0.5, size = 10)) +
	geom_point(x = df.lines$purity, y = df.lines$ploidy, size = 1.2, color = "darkred")
)
dev.off()


###################### DH limit
data_limit = COMBI_DIST_TCN

#set distances for all purities/plodiy combinations that exceeded DH limits to 3
for (i in seq_len(nrow(COMBI_DIST_TCN))) {
	purity_limit = limitDH[i]
	
	if (is.na(purity_limit) == FALSE) {
		data_limit[i, seq_len(purity_limit)] = 6 
	}  
}


data = matrix(data = 0, nrow = nrow(dist_TCN) + 2, ncol = ncol(dist_TCN) + 2, byrow = FALSE, dimnames = NULL)
data[1, ] = 6
data[nrow(data), ] = 6
data[, 1] = 6
data[, ncol(data)] = 6
data[seq(2, nrow(data) - 1, 1), seq(2, ncol(data) - 1, 1)] = data_limit
data[which(is.na(data))] = 6


  if (all(data==6)) {
    cat("\n\nERROR: Did not find a single solution due to 'high purity issue'\n\n")
    quit(save = "no", status = 13)
  }

count = 0
ploidy_idx = c()
purity_idx = c()
all_local_minima = c()

# find local minimum in purity x ploidy matrix (comparing each cell with neighbouring cells in matrix)
for ( i in seq( 2, nrow(data) - 1, 1) ) {
	for ( j in seq( 2, ncol(data) - 1, 1 ) ) {
		if (data[i, j] <= min(data[i-1, j-1], data[i-1, j], data[i-1, j+1], data[i, j-1], data[i, j+1], data[i+1, j-1], data[i+1, j], data[i+1, j+1]) & data[i,j] != 6 )  {
			count = count + 1
			all_local_minima[count] = data[i, j]
			ploidy_idx[count] = i
			purity_idx[count] = j
		}
	}
}

#get corresponding purity and ploidy values
mini_pur = posPurities[purity_idx - 1]
mini_ploi = posPloidies[ploidy_idx - 1]

#select all local minima that are smaller than global min + 1 SD (or local_minium_upper_boundary_shift in case global minimum >=local_minium_upper_boundary_shift)
sel = which(all_local_minima < min(all_local_minima) + max(sd(all_local_minima), local_minium_upper_boundary_shift))
sel_local_minima = all_local_minima[sel]
sel_mini_pur = mini_pur[sel]
sel_mini_ploi = mini_ploi[sel]

if (min(sel_local_minima) >= local_minium_upper_boundary_shift ) {
	sel = which(sel_local_minima < min(sel_local_minima) + local_minium_upper_boundary_shift)
} else {
	sel = seq_along(sel_local_minima)
}

pur = sel_mini_pur[sel]
ploi = sel_mini_ploi[sel]
local_minima = sel_local_minima[sel]

select = c()
# select local minimum from each ploidy frame +-0.25
for (p in seq_along(ploi)) {
  # adapted by G Warsow:
  # if we have a high purity solution and a low purity solution at the same +-0.25 ploidy frame,
  # only the solution with lower distance value has been taken. The goal of this adaptation was
  # to also keep the low purity solution if the high purity solution has lower distance.
  # That is, this is a quick and dirty approch for dealing with 'artifact 1' cases.
  purity.current = pur[p]
  ploidy.current = ploi[p]
  red_line_purity_position = unique(df.lines[which(df.lines$ploidy==ploidy.current),"purity"])
  if (is.na(red_line_purity_position)) {
    red_line_purity_position = purity_min
  }
  # distance_to_red_line.current = purity.current - red_line_purity_position
  s <-  which(local_minima == min(local_minima[which(ploi <= ploi[p] + 0.25 & ploi >= ploi[p] - 0.25)]))
  purity.s = pur[s]
  ploidy.s = ploi[s]
  # distance_to_red_line.s = purity.s - red_line_purity_position
  # to be dicussed: how to define when to enter next block (define if clause)
  if ( purity.s == purity_max ) {
    # suggested solution has a 'purity 1 artifact'. Allow also (suboptimal) solutions with lesser purity (suboptimal w.r.t. distance value)
# if (purity.s - purity.current > 0.2) {
    # the solution with minimum distance (s) has a purity value >20 percentage points higher than the current solution (p)
    # let's divide the ploidy frame into 2 parts. one for lower, one for higher purity solutions

    # to be dicussed: how to define separation_position
    separation_position = (purity_max - red_line_purity_position) / 2 + red_line_purity_position
    if (purity.current <= separation_position) {
      s <-  which(local_minima == min(local_minima[which(
        ploi <= ploi[p] + 0.25 & ploi >= ploi[p] - 0.25 &
          pur  <= separation_position
      )]))
    } else {
      s <-  which(local_minima == min(local_minima[which(
        ploi <= ploi[p] + 0.25 & ploi >= ploi[p] - 0.25 &
          pur  > separation_position
      )]))
    }
  }
  select = c(select, s)
}

sel = unique(select)

final_pur = pur[sel]
final_ploi = ploi[sel]
final_local_minima = local_minima[sel]

while( any (diff(final_ploi) < 0.25 & diff(final_pur) < 0.1 & diff(final_local_minima) != 0)){ 
  sel <- which(diff(final_ploi) < 0.25 & diff(final_pur) < 0.1 )[1]
  sel <- c(sel, sel+1)
  s <- which( min(final_local_minima[sel]) != final_local_minima[sel] )
  final_pur  <- final_pur[-sel[s]]
  final_ploi <- final_ploi[-sel[s]]
  final_local_minima = final_local_minima[-sel[s]]
}

pp_matrix = matrix(data = 0, nrow = length(final_pur), ncol = 4, byrow = FALSE, dimnames = NULL )

for (i in seq_along(final_pur)) {
	pp_matrix[i, 1] = round(final_ploi[i])
	pp_matrix[i, 2] = final_ploi[i]
	pp_matrix[i, 3] = final_pur[i]
	pp_matrix[i, 4] = final_local_minima[i]
}                            

pp_table = as.table(pp_matrix)
colnames(pp_table) = c("ploidy", "ploidy_factor", "tcc", "distance")
write.table(pp_table, file = purity_ploidy, sep = "\t", row.names = FALSE, quote = FALSE)

#create data frame with ploidies and purities found at final minima (for star in plot)
opt_ploi = rep(NA, nrow(df.lines))
opt_pur = rep(NA, nrow(df.lines))

for (i in seq_along(final_pur)) {
	opt_ploi[i] = final_ploi[i]
	opt_pur[i] = final_pur[i]
}

df.opt = data.frame(purity = opt_pur, ploidy = opt_ploi)

plotPurities = c()

for (l in seq_along(limitDH)) {
	plotPurities[l] = posPurities[limitDH[l]]
}

plotPurities_DH = c()
for (l in seq_along(limitDHOrig)) {
  plotPurities_DH[l] = posPurities[limitDHOrig[l]]
}

plotPurities_NTCN = c()
for (l in seq_along(limitNTCN)) {
  plotPurities_NTCN[l] = posPurities[limitNTCN[l]]
}

testPlot = melt(data.frame(COMBI_DIST_TCN))
ploi = rep(posPloidies, length(posPurities))
testPlot$ploidy = ploi
df.lines = data.frame(ploidy = ploi, purity = plotPurities, purity_DH=plotPurities_DH, purity_NTCN=plotPurities_NTCN)
names(testPlot) = c("purity", "distance", "ploidy")
testPlot$purity = substring(testPlot$purity, 2, 5)
testPlot$purity = as.numeric(testPlot$purity)


# contour lines will be plotted for each contour_level (e.g. at 101% or 105% of the minimum distance value)
# contour_levels = c(0.01,0.05,0.1,0.15,0.2)
contour_levels = c(0.01,0.1,0.25,0.4)
secondLastLevel = tail(contour_levels,2)[-2]
countour_local_minima = sort(final_local_minima)
# for contour plots: remove local minima that are not at least 10% larger (or whatever 
# the second-last value of contour_levels is) than the global minimum
# that is: no own cloud for minima with near-optimum distance value.


while (any(abs(diff(countour_local_minima)) <= min(countour_local_minima)*secondLastLevel)) {
  index.representativeOfNearbySolutions = which(diff(countour_local_minima) <= min(countour_local_minima)*secondLastLevel)[1]
  index.solutionsCoveredByRepresentative = which(
    countour_local_minima >= countour_local_minima[index.representativeOfNearbySolutions] &
    countour_local_minima <= countour_local_minima[index.representativeOfNearbySolutions]*(1+secondLastLevel)
  )
  index.solutionsCoveredByRepresentative = setdiff(index.solutionsCoveredByRepresentative, index.representativeOfNearbySolutions)
  sel = setdiff(seq_along(countour_local_minima), index.solutionsCoveredByRepresentative)
  countour_local_minima = countour_local_minima[sel]
}
contour_breaks = as.numeric(sapply(countour_local_minima, function(x) {
  return(x*(1+contour_levels))
}))


png(paste0("",out, "/",pid, "_tcn_distances_combined_star.png"), width = 800, height = 800, type='cairo')
erupt = ggplot(testPlot, aes(purity, ploidy, z = distance)) +
	geom_tile(aes(fill = distance))+ 
  stat_contour( aes(colour = ..level..), breaks=contour_breaks) +
	scale_x_continuous(expand = c(0, 0)) + 
	scale_y_continuous(expand = c(0, 0)) 
print( erupt + scale_fill_gradient2(limits = c(0, mean(testPlot$distance[which(!is.na(testPlot$distance))])), midpoint = mean(testPlot$distance[which(!is.na(testPlot$distance))]) / 2, low = "darkred", high = "darkblue", na.value = "darkblue") + 
	theme(axis.text.x = element_text(vjust = 0.5, size = 14, color = "black"), axis.text.y = element_text(vjust = 0.5, size = 14, color = "black"), axis.title.x = element_text(color = "black", size = 16, vjust = 2, face = "bold"), axis.title.y = element_text(color = "black", size = 16, face = "bold")) +
	# geom_point(x = df.lines$purity, y = df.lines$ploidy, size = 1.2, color = "darkred") +
	  geom_point(x = df.lines$purity_NTCN, y = df.lines$ploidy, size = 1.2, color = "green") +
	  geom_point(x = df.lines$purity_DH, y = df.lines$ploidy, size = 1.2, color = "yellow") +
	geom_point(x = df.opt$purity, y = df.opt$ploidy, size = 6, color = "black", shape = 8) + xlab("tumor cell content") +
	theme(legend.text = element_text(colour = "black", size = 16), legend.title = element_text(colour = "black", size = 16, face = "bold"))
)
dev.off()

