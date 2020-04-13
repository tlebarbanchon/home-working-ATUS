* remote_work produces stats on remote-working by occupation and industry from ATUS

* namely it reproduces table 7 of bls website with more detailed occupation
* NOTE from Table 7: Includes work at main job only and at locations other than home or workplace. Excludes travel related to work. Data refer to persons 15 years and over.

* INPUT: 
* ATUS survey data
* several label files in "${CROSSWALK}"
* several crosswalks in "${CROSSWALK}" 
* for example mapping_SOC10_to_OCC10, mapping_ISCO08_to_SOC10...
* these are produced from do-files prepare_crosswalks and prepare_employment
* crosswalks from swedish occupations are created somewhere else but saved in "${CROSSWALK}" 

* OUTPUT: 
* remote-working by occupation:
* home_working_OCC10, home_working_SOC10, home_working_SOC10-6digit-all, home_working_ISCO08, home_working_SSYK2012
* we also add employment and wage stats in home_working_SOC10-6digit-all-emp
* remote-working by industry: 
* home_working_ind, home_working_naics, home_working_isic
* 

* INSTALL unique, outreg2, labutil, sutex, dataout, binscatter packages
ssc install unique
ssc install outreg2
ssc install labutil
ssc install sutex
ssc install dataout
ssc install binscatter

* CHANGE THIS FOR YOUR ROOT FOLDER
* global DIR="/home-working-ATUS/"

global OUTPUT="${DIR}data/output/"
global CROSSWALK="${DIR}data/crosswalks/output/"


mkdir ${DIR}data/tmp
cd ${DIR}data/tmp

mkdir ${DIR}output/
global TAB="${DIR}output/"

* Finally: this is the folder where the ATUS datasets should be downloaded to
* subfolder: 'atusresp-0318'; file: 'atusresp_0318.dta'
* subfolder: 'atusrost-0318'; file: 'atusrost_0318.dta'
* subfolder: 'atusact-0318'; file: 'atusact_0318.dta'
global SOURCE="${DIR}data/input/"


* PLAN OF DO-FILE
********************************************************************************
* A. CREATE ATUS DATASET
* B. STATS ON HOME-WORKING
* B1. VARIANCE DECOMPOSITION OF HOME-WORKING
* C. CREATE COLLAPSED DATA BY ATUS OCCUPATIONS 
* D. CREATE COLLAPSED DATA BY ATUS INDUSTRIES
* E. OCCUPATIONAL DATASETS:
* F. INDUSTRY DATASETS:
* G. PRODUCE SUMMARY STATS OF OCCUPATION-LEVEL DATASETS
* H. PRODUCE SUMMARY STATS OF INDUSTRY-LEVEL DATASETS
* I. COMPARE with Dingel & Neiman 2020





********************************************************************************
********************************************************************************
* A. CREATE ATUS DATASET

********************************************************************************
* PREPARE RESPONDENT FILE

use ${SOURCE}atusresp-0318/atusresp_0318.dta, clear
tab tuyear
sort tucaseid tulineno
unique tucaseid 
unique tucaseid tulineno
keep if inrange(tuyear,2011,2018)
save atusresp_, replace

********************************************************************************
* PREPARE ROSTER FILE

use ${SOURCE}atusrost-0318/atusrost_0318.dta, clear
* describes all household members 
sort tucaseid tulineno
unique tucaseid tulineno
gen year=substr(tucaseid,1,4)
tab year
destring year, replace
* there is a break in occupation classification in 2011
keep if inrange(year,2011,2018)
tab terrp
tab terrp year 
tab terrp if tulineno==1
* select the line corresponding to the respondent
keep if tulineno==1
save atusrost_, replace

********************************************************************************
* PREPARE ACTIVITY FILE, MERGE WITH RESPONDENT, SELECT SAMPLES, CREATE HOME-WORK VARS

use ${SOURCE}atusact-0318/atusact_0318.dta, clear

gen year=substr(tucaseid,1,4)
tab year
destring year, replace
* there is a break in occupation classification in 2011
keep if inrange(year,2011,2018)

unique tucaseid tuactivity_n
sort tucaseid tuactivity_n
merge m:1 tucaseid using atusresp_
cap drop _m

merge m:1 tucaseid using atusrost_
cap drop _m

* restrict to indiv. declaring some work periods during the day
keep if trcodep==50101
* restrict to employed workers (according to labor force status)
keep if telfs==1 


bys tucaseid: egen dur_home_=total(tuactdur) if trcodep==50101 & tewhere==1 
bys tucaseid: egen dur_home=mean(dur_home_) if trcodep==50101
drop dur_home_
replace dur_home=0 if missing(dur_home)

bys tucaseid: egen dur_workplace_=total(tuactdur) if trcodep==50101 & tewhere==2 
bys tucaseid: egen dur_workplace=mean(dur_workplace_) if trcodep==50101
drop dur_workplace_
replace dur_workplace=0 if missing(dur_workplace)

bys tucaseid: egen dur_otherplace_=total(tuactdur) if trcodep==50101 & (tewhere!=1&tewhere!=2) 
bys tucaseid: egen dur_otherplace=mean(dur_otherplace_) if trcodep==50101
drop dur_otherplace_
replace dur_otherplace=0 if missing(dur_otherplace)

sort tucaseid tustarttim 
cap drop rk
by tucaseid: gen rk=_n
tab rk

gen home=dur_home>0
gen workplace=dur_workplace>0
gen otherplace=dur_other>0 
label var home "Worked from home"
label var workplace "Worked from workplace"
label var otherplace "Worked from other place than workplace and home"

tab home if rk==1
tab workplace if rk==1
tab otherplace if rk==1

tab home [aweight=tufnwgtp]if rk==1
tab workplace [aweight=tufnwgtp] if rk==1
tab otherplace [aweight=tufnwgtp] if rk==1

* restrict to one observation per workers
keep if rk==1

gen dur=dur_home+dur_workplace+dur_otherplace
label var dur "Minutes worked per day"
replace dur=dur/60
label var dur "Hours worked per day"

foreach var in home workplace otherplace {
	replace dur_`var'=dur_`var'/60
}
label var dur_workplace "Hours worked at the workplace per day"
label var dur_home "Hours worked at home per day"
label var dur_other "Hours worked at other place than workplace and home per day"

gen share_home=dur_home/(dur_home+dur_work)
label var share_home "Share of hours worked at home (over home and workplace)"

gen obs=1
* weights are person per day. 
* So we need to divide the sum of weights  by 365 days (within a year)
gen pop_weight=tufnwgtp/365
label var pop_weight "Weight to be used when counting people"

save atusact_.dta, replace








********************************************************************************
********************************************************************************
* B. STATS ON HOME-WORKING

use atusact_.dta, clear

* check overall data
tab year
table year, c(mean tufnwgtp sum pop_weight)

* check overall order of magnitude of hours worked
sum dur if year==2018 [aweight=tufnwgtp]
sum dur_home if year==2018 [aweight=tufnwgtp]
sum dur_workplace if year==2018 [aweight=tufnwgtp]
sum dur_otherplace if year==2018 [aweight=tufnwgtp]
* Be careful some BLS stats refer to any job (main and secondary job)
* especially aggregates, so we do not match them here

* replicating BLS Table 7 and aggregate chart by occupation
foreach var in trmjocc1 trmjocgr {
table `var' [aweight=tufnwgtp] if year==2018, ///
	c(mean dur mean dur_workplace mean dur_home mean dur_other)
table `var' [aweight=tufnwgtp] if year==2018, ///
	c(mean share_home)
table `var' [aweight=tufnwgtp] if year==2018, ///
	c(mean workplace mean home mean other)
}
foreach var in trmjocc1 {
table `var' if year==2018 & dur>0, ///
	c(sum pop_weight)	
table `var' if year==2018 & dur_work>0, ///
	c(sum pop_weight)	
table `var' if year==2018 & dur_home>0, ///
	c(sum pop_weight)	
	
}
* compares very well with table7_miseenforme in docs

foreach var in trmjocc1 trmjocgr {
graph hbar (mean) dur_workplace dur_home [aweight=tufnwgtp] if year==2018, over(`var')	
graph export ${TAB}bar_dur_workplace_`var'_2018.pdf, replace
}

* descriptive stats pooled over 2011-2018
foreach var in trmjocc1 trmjocgr {
graph hbar (mean) dur_workplace dur_home [aweight=tufnwgtp], over(`var') ///
		note("ATUS 2011-2018. Daily hours in main job.")
graph export ${TAB}bar_dur_workplace_`var'_2018.pdf, replace
}

* looking good plots
graph hbar (mean) dur_workplace dur_home [aweight=tufnwgtp] if year==2018, over(trmjocc1 ///	
	,relabel(1 `""Management, business," "and financial occupations""' ///
	2 "Professional and related" ///
	3 "Service" ///
    4 "Sales and related" ///
    5 `""Office and" "administrative support""' ///   6 `""Farming, fishing,"" and forestry""' ///
    6 "Farming, fishing, and forestry" ///
    7 "Construction and extraction" ///
    8 `""Installation, maintenance," " and repair""' ///
    9 "Production occupations" ///
    10 `""Transportation " "and material moving""' )) ///
	intensity(25) ///
	title("Daily hours by occupation") ///
	legend(order(1 "at workplace" 2 "at home")) ///
	bar(1, color(navy)) ///
	bar(2, color(maroon) fintensity(inten60)) ///
	note("ATUS 2018." "Sample of resp. with some work in main job during the day.")
graph export ${TAB}bar_dur_location_trmjocc1_2018.pdf, replace

graph hbar (mean) dur_workplace dur_home [aweight=tufnwgtp], over(trmjocc1 ///	
	,relabel(1 `""Management, business," "and financial occupations""' ///
	2 "Professional and related" ///
	3 "Service" ///
    4 "Sales and related" ///
    5 `""Office and" "administrative support""' ///   6 `""Farming, fishing,"" and forestry""' ///
    6 "Farming, fishing, and forestry" ///
    7 "Construction and extraction" ///
    8 `""Installation, maintenance," " and repair""' ///
    9 "Production occupations" ///
    10 `""Transportation " "and material moving""' )) ///
	intensity(25) ///
	title("Daily hours by occupation") ///
	legend(order(1 "at workplace" 2 "at home")) ///
	bar(1, color(navy)) ///
	bar(2, color(maroon) fintensity(inten60)) ///
	note("ATUS 2011-2018." "Sample of resp. with some work in main job during the day.")
graph export ${TAB}bar_dur_location_trmjocc1.pdf, replace


* time series evolution
foreach var in year {
table `var' [aweight=tufnwgtp], ///
	c(mean dur mean dur_workplace mean dur_home mean dur_other)
table `var' [aweight=tufnwgtp], ///
	c(mean share_home)
table `var' [aweight=tufnwgtp], ///
	c(mean workplace mean home mean other)
}

graph bar (mean) dur [aweight=tufnwgtp], over(year) intensity(*0.1) ///
	 title("Hours worked in main job") ytitle(" ") ///
	 note("ATUS. Sample of resp. with some work in main job during the day.")
graph export ${TAB}bar_dur.pdf, replace

graph bar (mean) dur_work [aweight=tufnwgtp], over(year) intensity(*0.1) ///
	 title("Hours worked at the workplace in main job") ytitle(" ") ///
	 note("ATUS. Sample of resp. with some work in main job during the day.")
graph export ${TAB}bar_dur_work.pdf, replace
graph bar (mean) dur_work [aweight=tufnwgtp] if dur_work>0, over(year) intensity(*0.1) ///
	 title("Hours worked at the workplace in main job") ytitle(" ")  ///
	 note("ATUS. Sample of resp. with some work at the workplace in main job during the day.")
graph export ${TAB}bar_dur_work_p0.pdf, replace

graph bar (mean) dur_home [aweight=tufnwgtp], over(year) intensity(*0.1) ///
	 title("Hours worked at home in main job") ytitle(" ")  ///
	 note("ATUS. Sample of resp. with some work in main job during the day.")
graph export ${TAB}bar_dur_home.pdf, replace
graph bar (mean) dur_home [aweight=tufnwgtp] if dur_home>0, over(year) intensity(*0.1) ///
	 title("Hours worked at home in main job") ytitle(" ") ///
	 note("ATUS. Sample of resp. with some work at home in main job during the day.")
graph export ${TAB}bar_dur_home_p0.pdf, replace

graph bar (mean) dur_other [aweight=tufnwgtp], over(year) intensity(*0.1) ///
	 title("Hours worked in main job" "at other place than workplace or home") ytitle(" ") ///
	 note("ATUS. Sample of resp. with some work in main job during the day.")
graph export ${TAB}bar_dur_other.pdf, replace
graph bar (mean) dur_other [aweight=tufnwgtp] if dur_other>0, over(year) intensity(*0.1) ///
	 title("Hours worked in main job" "at other place than workplace or home") ytitle(" ") ///
	 note("ATUS. Sample of resp. with some work at other place in main job during the day.")
graph export ${TAB}bar_dur_other_p0.pdf, replace

graph bar (mean) share_home [aweight=tufnwgtp], over(year) intensity(*0.1) ///
	 title("Share of hours worked in main job" "at home") ytitle(" ") ///
	 note("ATUS. Sample of resp. with some work in main job during the day." "Share at home over home + workplace ")
graph export ${TAB}bar_share_home.pdf, replace

graph bar (mean) workplace [aweight=tufnwgtp], over(year) intensity(*0.1) ///
	 title("Share of workers at the workplace") ytitle(" ") ///
	 note("ATUS. Sample of resp. with some work in main job during the day.")
graph export ${TAB}bar_workplace.pdf, replace

graph bar (mean) home [aweight=tufnwgtp], over(year) intensity(*0.1) ///
	 title("Share of workers at home") ytitle(" ") ///
	 note("ATUS. Sample of resp. with some work in main job during the day.")
graph export ${TAB}bar_home.pdf, replace

graph bar (mean) other [aweight=tufnwgtp], over(year) intensity(*0.1) ///
	 title("Share of workers""at other place than workplace or home") ///
	 note("ATUS. Sample of resp. with some work in main job during the day.")
graph export ${TAB}bar_other.pdf, replace


* industries

desc trmjind1 trimind1  trdtind1 teio1icd
codebook trmjind1 trimind1  trdtind1 teio1icd

tab trmjind1

label list labeltrmjind1

graph hbar (mean) dur_workplace dur_home [aweight=tufnwgtp] if year==2018, over(trmjind1 ///	
	,relabel(1 "Agriculture" ///    5 `""Office and" "administrative support""' ///  
	)) ///
	intensity(25) ///
	title("Daily hours by industry") ///
	legend(order(1 "at workplace" 2 "at home")) ///
	bar(1, color(navy)) ///
	bar(2, color(maroon) fintensity(inten60)) ///
	note("ATUS 2018." "Sample of resp. with some work in main job during the day.")
graph export ${TAB}bar_dur_location_trmjind1_2018.pdf, replace

graph hbar (mean) dur_workplace dur_home [aweight=tufnwgtp], over(trmjind1 ///	
	,relabel(1 "Agriculture" ///    5 `""Office and" "administrative support""' ///  
	)) ///
	intensity(25) ///
	title("Daily hours by industry") ///
	legend(order(1 "at workplace" 2 "at home")) ///
	bar(1, color(navy)) ///
	bar(2, color(maroon) fintensity(inten60)) ///
	note("ATUS 2011-2018." "Sample of resp. with some work in main job during the day.")
graph export ${TAB}bar_dur_location_trmjind1.pdf, replace

* Since ATUS 2014, 2012 Census Industry Classification
* From ATUS 2010-2013, 2007 Census Industry Classification





********************************************************************************
********************************************************************************
* B1. VARIANCE DECOMPOSITION OF HOME-WORKING

use atusact_.dta, clear

gen C=1

reg share_home C i.teio1ocd [aweight=tufnwgtp]
testparm i.teio1ocd
outreg2 using ${TAB}share_home.tex, label tex replace ///
	 adjr2 keep(C) ///
	 addtext("Occupation FE","Y") ///
	 addstat("Occupation F-test",r(F),"Occ. p-value",r(p))

reg share_home i.teio1icd [aweight=tufnwgtp]
testparm i.teio1icd
outreg2 using ${TAB}share_home.tex, label tex append ///
	 adjr2 keep(C) ///
	 addtext("Occupation FE","","Industry FE","Y") ///
	 addstat( ///
	 "Industry F-test",r(F),"Ind. p-value",r(p))	 
	 
reg share_home i.teio1ocd  i.teio1icd [aweight=tufnwgtp]
testparm i.teio1ocd
scalar F1=r(F)
sca list F1
scalar p1=r(p)
testparm i.teio1icd
outreg2 using ${TAB}share_home.tex, label tex append ///
	 adjr2 keep(C) ///
	 addtext("Occupation FE","Y","Industry FE","Y") ///
	 addstat("Occupation F-test",scalar(F1),"Occ. p-value",p1, ///
	 "Industry F-test",r(F),"Ind. p-value",r(p))

	 


*******************************************************************************
*******************************************************************************
* C. CREATE COLLAPSED DATA BY OCCUPATIONS 

use atusact_.dta, clear

sum tufnwgtp, d

preserve 
collapse (sum) obs workers=pop_weight (mean) dur dur_workplace dur_home dur_other share_home ///
	workplace home other [aweight=tufnwgtp], by(teio1ocd)
label var dur_workplace "Hours worked at the workplace per day"
label var dur_home "Hours worked at home per day"
label var dur_other "Hours worked at other place than workplace and home per day"
label var dur "Total hours worked (any place)"
label var share_home "Share of hours worked at home (over home and workplace)"
label var home "Worked from home"
label var workplace "Worked from workplace"
label var otherplace "Worked from other place than workplace and home"
label var obs "Number of ATUS observation"
label var workers "Number of workers"
label var teio1ocd "Occupation code"
total obs
total workers
* as we merge 8 years
replace workers=workers/8
*total workers
save dur_home_teio1ocd, replace 
restore

foreach var in trmjocc1 trmjocgr { 
preserve 
collapse (sum) obs workers=pop_weight (mean) dur dur_workplace dur_home dur_other share_home ///
	workplace home other [aweight=tufnwgtp], by(`var')
label var dur_workplace "Hours worked at the workplace per day"
label var dur_home "Hours worked at home per day"
label var dur_other "Hours worked at other place than workplace and home per day"
label var dur "Total hours worked (any place)"
label var share_home "Share of hours worked at home (over home and workplace)"
label var home "Worked from home"
label var workplace "Worked from workplace"
label var otherplace "Worked from other place than workplace and home"
label var obs "Number of ATUS observation"
label var workers "Number of workers"
label var `var' "Occupation code"
total obs
* as we merge 8 years
replace workers=workers/8
total workers
save dur_home_`var', replace 
restore
}	







	
********************************************************************************
********************************************************************************
* D. CREATE COLLAPSED DATA BY INDUSTRIES
* from broader to finer classification	(13, 21, 51 to 269 categories)

use atusact_.dta, clear

desc trmjind1 trimind1  trdtind1 teio1icd
codebook trmjind1 trimind1  trdtind1 teio1icd

* Since ATUS 2014, 2012 Census Industry Classification
* From ATUS 2010-2013, 2007 Census Industry Classification

tab teio1icd
desc teio1icd

foreach var in teio1icd { 
preserve 
keep if inrange(year,2014,2018)
collapse (sum) obs workers=pop_weight (mean) dur dur_workplace dur_home dur_other share_home ///
	workplace home other [aweight=tufnwgtp], by(`var')
label var dur_workplace "Hours worked at the workplace per day"
label var dur_home "Hours worked at home per day"
label var dur_other "Hours worked at other place than workplace and home per day"
label var dur "Total hours worked (any place)"
label var share_home "Share of hours worked at home (over home and workplace)"
label var home "Worked from home"
label var workplace "Worked from workplace"
label var otherplace "Worked from other place than workplace and home"
label var obs "Number of ATUS observation"
label var workers "Number of workers"
label var `var' "Industry code (census classification)"
total obs
*total workers
* as we merge 8 years
replace workers=workers/5
total workers
save dur_home_`var', replace 
restore
}	

	
	

	
	
	
********************************************************************************
********************************************************************************
* E. OCCUPATIONAL DATASETS:
* ADD granular LABELS and convert in SOC and in ISCO-08

use dur_home_teio1ocd, replace

gen OCC10_=teio1ocd
sort OCC10_
merge 1:1 OCC10_ using "${CROSSWALK}labels_OCC10.dta"

* 38 catgeories are not found in ATUS 	
tab OCC10L if _m==2
/*
                             OCC10Label |      Freq.     Percent        Cum.
----------------------------------------+-----------------------------------
                 Agricultural engineers |          1        2.63        2.63
                   Biomedical engineers |          1        2.63        5.26
Cooling and freezing equipment operat.. |          1        2.63        7.89
                  Correspondence clerks |          1        2.63       10.53
                     Desktop publishers |          1        2.63       13.16
Electrical and electronics installers.. |          1        2.63       15.79
                 Exercise physiologists |          1        2.63       18.42
Extruding and forming machine setters.. |          1        2.63       21.05
       Fabric and apparel patternmakers |          1        2.63       23.68
Food and tobacco roasting, baking, an.. |          1        2.63       26.32
Food preparation and serving related .. |          1        2.63       28.95
                    Gaming cage workers |          1        2.63       31.58
                   Hunters and trappers |          1        2.63       34.21
Judges, magistrates, and other judici.. |          1        2.63       36.84
                            Legislators |          1        2.63       39.47
             Life scientists, all other |          1        2.63       42.11
Manufactured building and mobile home.. |          1        2.63       44.74
Milling and planing machine setters, .. |          1        2.63       47.37
             Mine shuttle car operators |          1        2.63       50.00
Miscellaneous mathematical science oc.. |          1        2.63       52.63
Model makers and patternmakers, metal.. |          1        2.63       55.26
          Motion picture projectionists |          1        2.63       57.89
                    Nuclear technicians |          1        2.63       60.53
                           Paperhangers |          1        2.63       63.16
            Parking enforcement workers |          1        2.63       65.79
                  Pile-driver operators |          1        2.63       68.42
   Postmasters and mail superintendents |          1        2.63       71.05
                   Radiation therapists |          1        2.63       73.68
                                Riggers |          1        2.63       76.32
                   Roof bolters, mining |          1        2.63       78.95
Sawing machine setters, operators, an.. |          1        2.63       81.58
               Semiconductor processors |          1        2.63       84.21
                         Ship engineers |          1        2.63       86.84
 Shoe and leather workers and repairers |          1        2.63       89.47
                           Sociologists |          1        2.63       92.11
Textile bleaching and dyeing machine .. |          1        2.63       94.74
            Transit and railroad police |          1        2.63       97.37
       Wind turbine service technicians |          1        2.63      100.00
----------------------------------------+-----------------------------------
                                  Total |         38      100.00
*/
labmask OCC10_, values(OCC10L)
drop OCC10L
tab OCC10_
order OCC10 OCC10_ share_home dur_workplace dur_home dur_otherplace dur ///
	workplace home otherplace
drop _m
total workers
* 173 millions
save ${OUTPUT}home_working_OCC10, replace 

use ${OUTPUT}home_working_OCC10, clear
sort OCC10_
merge 1:m OCC10_ using "${CROSSWALK}mapping_SOC10_to_OCC10.dta", ///
 keepusing(SOC10)
drop _m
sort SOC10
order SOC10 OCC10 OCC10_ share_home dur_workplace dur_home dur_otherplace dur ///
	workplace home otherplace
unique SOC10 	
* In the mapping, there are some SOC codes at the 5-digit and others at the 6-digit level
total workers
* 180 millions
save ${OUTPUT}home_working_SOC10, replace 

use  ${OUTPUT}home_working_SOC10,clear
drop if substr(SOC10,7,1)=="0"
save home_working_SOC10-6digit.dta, replace

use  ${OUTPUT}home_working_SOC10,clear
tab SOC10 if substr(SOC10,6,1)=="0"
keep if substr(SOC10,7,1)=="0"
drop if substr(SOC10,6,1)=="0"
gen SOC10_5d=substr(SOC10,1,6)
sort SOC10_5d
save home_working_SOC10-5digit.dta, replace

use  ${OUTPUT}home_working_SOC10,clear
tab SOC10 if substr(SOC10,6,1)=="0"
keep if substr(SOC10,6,1)=="0"
gen SOC10_3d=substr(SOC10,1,4)
sort SOC10_3d
save home_working_SOC10-3digit.dta, replace

use "${CROSSWALK}labels_SOC10.dta", clear
merge 1:1 SOC10 using home_working_SOC10-6digit
rename _m _m1
gen SOC10_5d=substr(SOC10,1,6)
sort SOC10_5d SOC10
merge m:1 SOC10_5d using home_working_SOC10-5digit, update gen(_m2)
tab _m1 _m2
gen SOC10_3d=substr(SOC10,1,4)
sort SOC10_3d SOC10
merge m:1 SOC10_3d using home_working_SOC10-3digit, update gen(_m3)
count if missing(share)
*out of 62 occupation for which we are missing ATUS data, 20 are in the army
*real missings are 42
drop _m1 SOC10_5d _m2 SOC10_3d _m3
drop OCC10 OCC10_ 
drop teio1ocd
total workers
* 395 millions: far too much
drop workers
save ${OUTPUT}home_working_SOC10-6digit-all.dta, replace

* add external labor market variables 
use ${OUTPUT}home_working_SOC10, clear
replace SOC10="13-1020" if SOC10=="13-1022"
drop if SOC10=="13-1021"
drop if SOC10=="13-1023"
gen occ_code=SOC10
merge 1:1 occ_code using "${CROSSWALK}employment_SOC10.dta"
/*
    Result                           # of obs.
    -----------------------------------------
    not matched                           832
        from master                         5  (_merge==1)
        from using                        827  (_merge==2)

    matched                               546  (_merge==3)
    -----------------------------------------
*/
* 45-3011, 45-3021 just missing
* 13-1021, 13-1022, 13-1023 grouped in 13-1020
sort occ_code
drop if _m==2
total workers
total tot_emp
sum wageannual
drop _m
drop occ_code
cap drop OCC10 OCC10_ teio1ocd
save ${OUTPUT}home_working_SOC10, replace


use ${OUTPUT}home_working_SOC10-6digit-all, clear
cap drop OCC10 OCC10_ teio1ocd
gen occ_code=SOC10
merge 1:1 occ_code using "${CROSSWALK}employment_SOC10.dta"
/*
    Result                           # of obs.
    -----------------------------------------
    not matched                           621
        from master                        44  (_merge==1)
        from using                        577  (_merge==2)

    matched                               796  (_merge==3)
    -----------------------------------------
*/
tab SOC10 if _m==1
*replace occ_code="13-1020" if inlist(SOC10,"13-1021","13-1022","13-1023")
*replace occ_code="15-2090" if inlist(SOC10,"15-2091","15-2099")
*21-1011, 21-1014 grouped into 21-1018
*25-3099 split into 25-3097, 25-3098
*29-2012, 29-2011 grouped into 29-2010
*39-1011 39-1012 grouped into 39-1010
*39-7011, 39-7012 grouped into 39-7010
*45-3011, 45-3021 just missing
*47-4091, 47-4099 grouped into 47-4090
*51-2022, 51-2023 grouped into 51-2028
*51-2092,51-2099 grouped into 51-2098
*53-1021, 53-1031 grouped in 53-1048
drop if _m==2
drop _m
drop occ_code

gen     occ_code="21-1018" if SOC10=="21-1011"|SOC10=="21-1014"
replace occ_code="13-1020" if inlist(SOC10,"13-1021","13-1022","13-1023")
replace occ_code="15-2090" if inlist(SOC10,"15-2091","15-2099")
replace occ_code="29-2010" if SOC10=="29-2011"|SOC10=="29-2012"
replace occ_code="39-1010" if inlist(SOC10,"39-1011","39-1012")
replace occ_code="39-7010" if inlist(SOC10,"39-7011","39-7012")
replace occ_code="47-4090" if inlist(SOC10,"47-4091","47-4099")
replace occ_code="51-2028" if inlist(SOC10,"51-2022","51-2023")
replace occ_code="51-2098" if inlist(SOC10,"51-2092","51-2099")
replace occ_code="53-1048" if inlist(SOC10,"53-1021","53-1031")
merge m:1 occ_code using "${CROSSWALK}employment_SOC10.dta", update
drop if _m==2
tab _m if missing(occ_code)==0
drop _m
count if missing(tot_emp)
tab SOC10 if missing(tot_emp)
* almost only military officers
drop occ_code
total tot_emp
save ${OUTPUT}home_working_SOC10-6digit-all_emp.dta, replace


use ${OUTPUT}home_working_SOC10-6digit-all, clear
sort SOC10
merge 1:m SOC10 using  "${CROSSWALK}mapping_ISCO08_to_SOC10.dta"
drop _m

foreach v of var * {
	local l`v' : variable label `v'
       if `"`l`v''"' == "" {
		local l`v' "`v'"
	}
}
collapse (first) ISCO08TitleEN (sum) obs ///
	(mean) share_home dur_workplace dur_home dur_otherplace dur ///
	workplace home otherplace, by(ISCO08)
foreach v of var * { 
	label var `v' "`l`v''" 
	}

*sort ISCO08
*merge 1:1 ISCO08 using "${CROSSWALK}labels_ISCO08.dta"
* despite imperfect match of crosswalk, we have exhaustive list of 

count if obs==0
* 11 ISCO codes out of 438 do not have info from ATUS...
* 3 are from the army
save ${OUTPUT}home_working_ISCO08, replace 


use ${OUTPUT}home_working_ISCO08, clear 
sort ISCO08
merge 1:m ISCO08 using "${CROSSWALK}mapping_ISCO08_to_SSYK2012.dta"
keep if _m==3
drop _m
label var SSYK2012_ "Swedish occupational classification (SSYK2012, 4-digit, numeric)"
sort SSYK2012 ISCO08_ 

foreach v of var * {
	local l`v' : variable label `v'
       if `"`l`v''"' == "" {
		local l`v' "`v'"
	}
}
collapse (first) SSYK2012_ (sum) obs ///
	(mean) share_home dur_workplace dur_home dur_otherplace dur ///
	workplace home otherplace, by(SSYK2012)
foreach v of var * { 
	label var `v' "`l`v''" 
	}
	
label values SSYK2012_ SSYK2012_ 
count if obs==0
* 9 SSYK codes out of 429 do not have info from ATUS...
* 3 are from the army
* 1 legislators
* other are lawyers
save ${OUTPUT}home_working_SSYK2012, replace 







********************************************************************************
********************************************************************************
* F. INDUSTRY DATASETS:
* ADD granular LABELS and convert in NAICS and in ISCO-08

use dur_home_teio1icd.dta, clear
gen ind=teio1icd
sort ind
merge 1:1 ind using "${CROSSWALK}ind2012_labels.dta"
keep if _m==3
drop _m
rename ind ind_
labmask ind_, values(indlabel)
drop indlabel
rename teio1icd ind
tostring ind, replace
replace ind="0"+ind if length(ind)==3
order ind ind_
save ${OUTPUT}home_working_ind.dta, replace

use "${CROSSWALK}naics_from_ind_4d.dta", clear
count
* 353
gen teio1icd=ind
sort teio1icd
merge m:1 teio1icd using dur_home_teio1icd
tab teio1icd if _m==1
tab teio1icd if _m==2
/*
 480 and 590 census codes missing from code lists or crosswalk (very few obs, prob coding errors)
*/
drop if _m==2

foreach v of var * {
	*disp "`v'"
	local l`v' : variable label `v'
       if `"`l`v''"' == "" {
		local l`v' "`v'"
	}
}
collapse (sum) obs ///
	(mean) share_home dur_workplace dur_home dur_otherplace dur ///
	workplace home otherplace [weight=afactor], by(naics)
foreach v of var * { 
	label var `v' "`l`v''" 
	}
 count 
*  311
save ${OUTPUT}home_working_naics.dta, replace

use ${OUTPUT}home_working_naics.dta, clear
cap rename naics naics_
sort naics_
merge 1:m naics_ using "${CROSSWALK}naics_labels.dta", ///
	keepusing(naicslabel) 
drop if _m==2
drop _m
labmask naics_, values(naicslabel)
drop naicslabel
unique naics
order naics
compress 
tostring naics_, gen(naics)
order naics 
save ${OUTPUT}home_working_naics.dta, replace
use ${OUTPUT}home_working_naics.dta, clear

use "${CROSSWALK}mapping_ISIC4_from_NAICS.dta", clear
gen naics=NAICS12_4d
sort naics
merge m:1 naics using ${OUTPUT}home_working_naics.dta
drop if _m==1
drop _m
sort ISIC4

foreach v of var * {
	*disp "`v'"
	local l`v' : variable label `v'
       if `"`l`v''"' == "" {
		local l`v' "`v'"
	}
}
collapse (first) ISIC4_ (sum) obs ///
	(mean) share_home dur_workplace dur_home dur_otherplace dur ///
	workplace home otherplace, by(ISIC4)
foreach v of var * { 
	label var `v' "`l`v''" 
	}
 count 
*  419
label var ISIC4 "Industry code (ISIC rev 4)"
label var ISIC4_ "Industry code (ISIC rev 4)"
save ${OUTPUT}home_working_isic.dta, replace




********************************************************************************
********************************************************************************
* G. PRODUCE SUMMARY STATS OF OCCUPATION-LEVEL DATASETS

use  ${OUTPUT}home_working_OCC10, clear 
gen workers_=int(workers)
sutex  share_home dur_workplace dur_home workplace home [weight=workers_], ///
	labels nobs file(${TAB}sumstat_OCC10) replace

hist share_home, title("Across detailed occupation (OCC10)") ///
	note("ATUS 2011-2018.") freq width(0.05)
graph export ${TAB}hist_share_home_OCC10.pdf, replace

sum obs, d
hist obs if inrange(obs,1,50), width(1) freq ///
	 title("Number of ATUS observations per occupation") ///
	 note("Truncated above median occupation with 50 observations")
graph export ${TAB}hist_observations.pdf, replace
	 
hist share_home [weight=workers_], title("Across detailed occupation (OCC10)") ///
	note("ATUS 2011-2018. Weighted.") width(0.05)
graph export ${TAB}hist_share_home_OCC10_weight.pdf, replace

drop if missing(share_home)
gsort - share_home
keep if obs>=5
keep OCC10 OCC10_ share_home workers
gen rk=_n
gen irk=_N-rk
count if share==0
keep if inrange(rk,1,5)|inrange(irk,1,5)
drop irk
*put back the labels...
dataout, save("${TAB}table_rank_OCC10") tex  replace

	
use  ${OUTPUT}home_working_SOC10-6digit-all, clear 
*replace workers=workers/8
sutex  share_home dur_workplace dur_home dur_otherplace dur workplace home otherplace obs, ///
	labels nobs file(${TAB}sumstat_SOC10) replace

use  ${OUTPUT}home_working_SOC10-6digit-all_emp, clear 

total tot_emp
	
sutex obs tot_emp if missing(share_home)==0

sutex share_home dur_workplace dur_home workplace home wageannual if missing(share_home)==0, ///
	labels nobs file(${TAB}sumstat_SOC10) replace
	
sutex share_home dur_workplace dur_home workplace home wageannual [weight=tot_emp], ///
	labels nobs file(${TAB}sumstat_SOC10) replace
	
gen homewage=share_home*wageannual	

sum wageannual homewage if missing(share_home)==0
	
	
use  ${OUTPUT}home_working_ISCO08, clear 
*replace workers=workers/8
sutex  share_home dur_workplace dur_home dur_otherplace dur workplace home otherplace obs, ///
	labels nobs file(${TAB}sumstat_ISCO08) replace


	
********************************************************************************
********************************************************************************
* H. PRODUCE SUMMARY STATS OF INDUSTRY-LEVEL DATASETS

global CAT="ind"
use ${OUTPUT}home_working_${CAT}.dta, clear

sutex  share_home dur_workplace dur_home dur_otherplace dur workplace home otherplace obs workers, ///
	labels nobs file(${TAB}sumstat_${CAT}) replace

hist share_home, ///
	title("Across detailed industries (census 2012 classification)") ///
	note("ATUS 2014-2018.") freq width(0.05)
graph export ${TAB}hist_share_home_${CAT}.pdf, replace

sum obs, d
hist obs if inrange(obs,1,50), width(1) freq ///
	 title("Number of ATUS observations per indsutry") ///
	 note("Truncated above median occupation with 50 observations")
graph export ${TAB}hist_observations.pdf, replace
	 
replace workers=int(workers)
hist share_home [weight=workers], ///
	title("Across detailed industries (census 2012 classification)") ///
	note("ATUS 2014-2018. Weighted.") width(0.05)
graph export ${TAB}hist_share_home_${CAT}_weight.pdf, replace

drop if missing(share_home)
gsort - share_home
keep if obs>=5
keep ${CAT} ${CAT}_ share_home workers
gen rk=_n
gen irk=_N-rk
count if share==0
keep if inrange(rk,1,5)|inrange(irk,1,5)
drop irk
*put back the labels...
dataout, save("${TAB}table_rank_${CAT}") tex  replace


global CAT="naics"
use ${OUTPUT}home_working_${CAT}.dta, clear

sutex  share_home dur_workplace dur_home dur_otherplace dur workplace home otherplace obs, ///
	labels nobs file(${TAB}sumstat_${CAT}) replace
	
global CAT="isic"
use ${OUTPUT}home_working_${CAT}.dta, clear

sutex  share_home dur_workplace dur_home dur_otherplace dur workplace home otherplace obs, ///
	labels nobs file(${TAB}sumstat_${CAT}) replace
	
	
	
	
	
	
********************************************************************************
********************************************************************************
* I. COMPARE with Dingel & Neiman 2020

use  ${OUTPUT}home_working_SOC10-6digit-all, clear 
drop if missing(share)
sort SOC10
merge 1:1 SOC10 using ${OUTPUT}teleworkable_DN2020_SOC10.dta
tab SOC10 if _m==1 
	
/*
    Result                           # of obs.
    -----------------------------------------
    not matched                            82
        from master                        43  (_merge==1)
        from using                         39  (_merge==2)

    matched                               735  (_merge==3)
    -----------------------------------------
*/

cor share_home telework
spearman share_home telework

reg share_home telework 


binscatter telework share_home, line(qfit) ///
	ytitle("Teleworkable (Dingel and Neiman 2020)") ///
	xtitle("Share of hours worked at home") ///
	title("Comparison of occupation classification")
graph export ${TAB}bs_share_home_teleworkDN2020.pdf, replace	


	
