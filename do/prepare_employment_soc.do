* prepare_employment_soc prepares data on employment and wages at SOC10 6-digit level 

* CHANGE THIS FOR YOUR ROOT FOLDER
* global DIR="/home-working-ATUS/"

global SOURCE="${DIR}input/occupation/"
cd "${DIR}output/"


import excel "${SOURCE}oesm18nat/national_M2018_dl.xlsx", sheet("national_dl") firstrow clear
unique OCC_CODE
rename OCC_CODE occ_code
rename TOT_EMP tot_emp
label var tot_emp "Total employment (2018)"
rename OCC_GROUP o_group

rename H_MEAN wagehourly_mean
label var wagehourly_mean "Mean hourly wage (2018)"
rename A_MEAN wageannual_mean 
label var wageannual_mean "Mean annual wage (2018)"
rename ANNUAL annual
rename HOURLY hourly 
*H_MEDIAN A_MEDIAN

count if missing(occ_code)
count if missing(tot_emp)
 
total tot_emp if o_group=="detailed"
total tot_emp if o_group=="broad"
total tot_emp if o_group=="major"
total tot_emp if o_group=="minor"
total tot_emp if o_group=="total"

tab annual hourly if o_group=="detailed", m
br if o_group=="detailed"

count if wageannual_mean=="*"
destring wageannual_mean, replace force
count if wagehourly_mean=="*"
destring wagehourly_mean, replace force

unique occ_code

keep occ_code tot_emp wage*
duplicates drop 
unique occ_code

sort occ_code
save employment_SOC10.dta, replace


