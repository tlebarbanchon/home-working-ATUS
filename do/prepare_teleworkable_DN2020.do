* prepare_teleworkable_DN2020 prepares dingel and neiman teleworkable data

* CHANGE THIS FOR YOUR ROOT FOLDER
* global DIR="/home-working-ATUS/"

cd ${DIR}data/tmp

global SOURCE="${DIR}data/input/"
global OUTPUT="${DIR}data/output/"

* we aggregate 
use ${SOURCE}teleworkable_DN2020.dta, clear

count
* 968
* we aggregate at the SOC10 6digit level

gen SOC10=substr(onetsoccode,1,7)
unique SOC10
* 774

collapse (mean) teleworkable, by(SOC10)
tab teleworkable
label var teleworkable "Can be performed at home (DN2020 classification)"
sort SOC10
save ${OUTPUT}teleworkable_DN2020_SOC10.dta, replace
