* prepare_crosswalks_occupation prepares crosswalks and label files for several occupatoin classification
* US census OCC10, US SOC10 and ISCO08 

* CHANGE THIS FOR YOUR ROOT FOLDER
* global DIR="/home-working-ATUS/"

global SOURCE="${DIR}input/occupation/"
cd "${DIR}output/"


import excel ${SOURCE}cenocc2010.xlsx, sheet("4-digit") firstrow clear
drop if missing(OCC10)
unique SOC 

foreach var in OCC10 OCC10L SOC10 {
replace `var'=strtrim(`var')
}

destring OCC10, gen(OCC10_)

sort SOC10
compress
save mapping_SOC10_to_OCC10.dta, replace

keep OCC10 OCC10L OCC10_
duplicates drop 
unique  OCC10
sort OCC10_
save labels_OCC10.dta, replace


import excel using ${SOURCE}ISCO-SOC.xls,  firstrow sheet("ISCO-08 to 2010 SOC") cellrange(A7:E1132) clear
count if missing(ISCO08C)
rename ISCO08Code ISCO08
* ISCO08TitleEN part 
rename SOCCode SOC10 
*SOCTitle
foreach var in ISCO08 ISCO08TitleEN part SOC10 SOCTitle {
replace `var'=strtrim(`var')
}
sort SOC10
save mapping_ISCO08_to_SOC10.dta, replace

keep ISCO08*
duplicates drop 
destring ISCO08, gen(ISCO08_)
sort ISCO08
save labels_ISCO08.dta, replace


import excel ${SOURCE}soc_structure_2010.xls, sheet("Sheet1") cellrange(A12:E1434) firstrow clear
foreach var in MajorGroup MinorGroup BroadGroup DetailedOccupation E {
replace `var'=strtrim(`var')
}
drop if missing(E)
rename DetailedOccupation SOC10 
rename E SOCLabel
keep if missing(SOC10)==0
keep SOC10 SOCLabel
sort SOC10
save labels_SOC10.dta, replace





