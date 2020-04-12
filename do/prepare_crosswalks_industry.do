* prepare_crosswalks_industry prepares crosswalks and label files for several indsutry classification
* US census IND12, US NAICS2012 and ISIC rev4

* IND12-NAICS crosswalk downloaded from 
* https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/O7JLIC
* https://www.bls.gov/cps/cenind2012.htm is not precise enough

* NAICS-ISIC crosswalk downloaded from
* https://unstats.un.org/unsd/classifications/Econ#Correspondences
* https://ec.europa.eu/eurostat/ramon/relations/index.cfm?TargetUrl=LST_REL&StrLanguageCode=EN&IntCurrentPage=11
* https://www.census.gov/eos/www/naics/concordances/concordances.html

* CHANGE THIS FOR YOUR ROOT FOLDER
* global DIR="/home-working-ATUS/"

global SOURCE="${DIR}input/industry/"
cd "${DIR}output/"

import delimited "${SOURCE}naics_to_ind.csv", clear
save naics_from_ind.dta, replace
/*
this naics 4-digit codes are missing from original crosswalk with correspondance from BLS website
0170	111
0180	112
6080	482
6370	491
* we add Private households 
9290	814
* we add public administration
9370	92111, 92112, 92114, pt. 92115
9380	92113
9390	92119
9470	922, pt. 92115
9480	923
9490	924, 925
9570	926, 927
9590	928
* we save them in naics_to_ind_complt
*/

import delimited "${SOURCE}naics_to_ind_complt.csv", clear
append using naics_from_ind

label var naics "Industry code (NAICS2012)"
label var ind "Census Industry code (IND2012)"
sort naics
compress
tab naics_
/*
naics_digit |      Freq.     Percent        Cum.
------------+-----------------------------------
          2 |        249        9.79        9.79
          3 |        280       11.01       20.79
          4 |        377       14.82       35.61
          5 |        660       25.94       61.56
          6 |        978       38.44      100.00
------------+-----------------------------------
      Total |      2,544      100.00
*/
tab ind if naics_==4
save naics_from_ind.dta, replace
keep if naics_==4
unique naics
* 311
save naics_from_ind_4d.dta, replace


import excel "${SOURCE}2-digit_2012_Codes.xls", sheet("tbl_2012_title_description_coun") cellrange(A3:C2211) clear
drop A
rename B naics
count if missing(naics)
rename C naicslabel
gen naics_digit=length(naics)
tab naics_digit
/*
naics_digit |      Freq.     Percent        Cum.
------------+-----------------------------------
          2 |         17        0.77        0.77
          3 |         99        4.48        5.25
          4 |        312       14.12       19.38
          5 |        716       32.41       51.79
          6 |      1,065       48.21      100.00
------------+-----------------------------------
      Total |      2,209      100.00
*/
destring naics, gen(naics_) force
br if missing(naics_)
replace naics_d=2 if missing(naics_)
labmask naics_, values(naicslabel)
sort naics_
compress
save naics_labels.dta, replace 
use naics_labels, clear


import excel "${SOURCE}ind2012_labels.xlsx", sheet("2012") cellrange(A12:D307) clear
rename A indlabel
rename B ind
drop C D 
drop if missing(ind)
save ind2012_labels.dta, replace


import excel "${SOURCE}2012 NAICS_to_ISIC_4.xlsx", sheet("NAICS 12 to ISIC 4 technical") ///
	firstrow allstring clear
drop F
drop Notes
gen NAICS4=substr(NAICSUS,1,4)
drop NAICSUST
drop NAICSUS
rename ISICR ISIC40Label
duplicates drop 
keep ISIC*
rename ISIC40 ISIC4
br
replace ISIC4="0"+ISIC4 if length(ISIC4)==3
duplicates drop
replace ISIC4=substr(ISIC4,1,3) if substr(ISIC4,4,1)=="X"
save ISIC4_labels.dta,replace


import delimited "${SOURCE}ISIC4-NAICS2012US.txt", stringcols(1 3) clear 
drop detail
* isic4code isic4part naics2012code naics2012part
drop isic4part naics2012part
gen NAICS12_4d=substr(naics,1,4)
drop naics
rename isic4code ISIC4
duplicates drop 
unique ISIC

sort NAICS12_4d
compress 

merge m:1 ISIC4 using ISIC4_labels
keep if _m==3
drop _m

destring ISIC4, gen(ISIC4_)
labmask ISIC4_, values(ISIC40Label)
drop ISIC40Label

save mapping_ISIC4_from_NAICS.dta, replace





	
 

