log using "/cluster/VAST/mp94p-lab/Landini/Figures/DatabaseMatching.log", replace
cd "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/BaseFiles"
*cd "Y:/Landini/GoogleLocations/BaseFiles"
***First, from the base google data, create subsets for each store type***
***VapeUSAdef1 is all stores from Google with vape as primary store type for example***
use VapeUSAdef1, clear
append using TobaccoUSAdef1, force
append using CigarUSAdef1, force
*append using HookahUSAdef1, force
**Drop if no address data, 1793 dropped**
drop if missing(full_address)

*drop temporarily and permanently closed, 13318 dropped*
keep if status == 1

*find and remove duplicate google_ids*
*Drop those not identifiable by google id, 145 dropped**
drop if missing(google_id)
bys google_id: gen tag = _N
tab tag
drop tag 

*find and remove address duplicates, using keeping the entry at the address with the most reviews, 1002 duplicates removed*
bys street city postal_code: gen tag = _N 
tab tag 
sort tag street city postal_code name 
bys street city postal_code: egen maxr = max(reviews)
bys street city postal_code: keep if reviews == maxr 
drop tag 

**In case there are duplicates with exactly identical number of reviews, we need to distinguish between them**
**First, drop those without an address entry, 552 dropped**
drop if missing(street)
bys street city postal_code: gen tag = _N 
tab tag 
sort tag street city postal_code name 
***At this point, 14 additional address duplicates were are dropped to leave one store at each address in Google. In some cases cannot distingush between store types**
drop if tag > 1
**Generate a google ID to match on later**
gen locid = _n

preserve
keep if vapetag == 1 
save "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Cleaned/USAallVapeFinal.dta", replace
restore 
preserve
keep if tobaccotag == 1 
save "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Cleaned/USAallSmokeFinal.dta", replace
restore 
preserve
keep if cigartag == 1 
save "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Cleaned/USAallCigarFinal.dta", replace
restore 

sum vapetag tobaccotag cigartag 

use "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Cleaned/USAallVapeFinal.dta"
append using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Cleaned/USAallSmokeFinal.dta"
append using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Cleaned/USAallCigarFinal.dta"

save "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Cleaned/GoogleUSA0524.dta", replace
/*
preserve
keep if hookahtag == 1 
save "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Cleaned/USAallHookah.dta", replace
restore
*/
***In a previous draft, we matched only to open Google locations with positive review counts. Here we will match to all open businesses in Google. 
cd "/cluster/VAST/mp94p-lab/Landini/Advan/Extract/Final/USAtobacco"
use USAtobaccoAll0524, clear

drop if raw_visit_count == .

geonear advid latitude longitude using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Cleaned/USAallVapeFinal", neighbors(locid latitude longitude) within(1) long
merge m:1 advid using USAtobaccoAll0524
drop _merge
merge m:1 locid using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Cleaned/USAallVapeFinal" 
drop _merge

rename full_address g_address
rename name g_name
gen adv_lower = lower(location_name)
gen loc_lower = lower(g_name)
gen loc_adr_l = lower(g_address)
gen adv_adr_l = lower(street_address)
ssc install freqindex
ssc install matchit
matchit adv_adr_l loc_adr_l, generate(loc_score)
matchit adv_lower loc_lower, generate(name_score)
matchit street_address street, gen(loc_score3)

gen advname = regexr(location_name, "[^a-zA-Z0-9]", "")
replace advname = subinstr(advname, " ", "", .)
gen advname6 = substr(advname, 1, 6)

gen gname = regexr(g_name, "[^a-zA-Z0-9]", "")
replace gname = subinstr(gname, " ", "", .)
gen gname6 = substr(gname, 1, 6)
replace advname6 = lower(advname6)
replace gname6 = lower(gname6)

gen advaddr = regexr(street_address, "[^a-zA-Z0-9]", "")
replace advaddr = subinstr(advaddr, " ", "", .)
gen advaddr6 = substr(advaddr, 1, 6)
replace advaddr6 = lower(advaddr6)

gen gaddr = regexr(street, "[^a-zA-Z0-9]", "")
replace gaddr = subinstr(gaddr, " " , "", .)
gen gaddr6 = substr(gaddr, 1, 6)
replace gaddr6 = lower(gaddr6)

matchit advaddr6 gaddr6, gen(loc_score6)

matchit advname6 gname6, gen(name_score6)
order location_name street_address city g_name g_address
gen match = 0
replace match = 1 if name_score == 1 & km_to_locid < .1
replace match = 1 if name_score > .5 & loc_score3 > .5 & km_to_locid < .1
replace match = 1 if match == 0 & name_score6 >= .8 & km_to_locid < .1
replace match = 1 if match == 0 & name_score6 >= .8 & loc_score3 > .9
replace match = 1 if loc_score3 == 1
replace match = 1 if loc_score6 == 1 & km_to_locid < .1
replace match = 1 if name_score6 == 1 & loc_score6 == 1
replace match = 0 if name_score < .5 & km_to_locid > .5
sort match
order match
replace match = 0 if name_score6 < .6 & loc_score6 < .6
split street_address
rename street_address1 advnum
drop street_address2-street_address10
split street
rename street1 gnum
drop street2-street16
replace match = 1 if match == 0 & km_to_locid < .05 & advnum == gnum
tab match
order match location_name street_address g_name g_address name_score loc_score km_to_locid name_score6 loc_score6 latitude longitude raw_visit_count status

keep if match == 1

save "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Matched/AllVapeMatch0524Final.dta", replace

***Next, Tobacco Specialty Shops***
use USAtobaccoAll0524, clear

drop if raw_visit_count == .

geonear advid latitude longitude using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Cleaned/USAallSmokeFinal", neighbors(locid latitude longitude) within(1) long
merge m:1 advid using USAtobaccoAll0524.dta
drop _merge
merge m:1 locid using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Cleaned/USAallSmokeFinal"
drop _merge

rename full_address g_address
rename name g_name
gen adv_lower = lower(location_name)
gen loc_lower = lower(g_name)
gen loc_adr_l = lower(g_address)
gen adv_adr_l = lower(street_address)
matchit adv_adr_l loc_adr_l, generate(loc_score)
matchit adv_lower loc_lower, generate(name_score)
matchit street_address street, gen(loc_score3)

gen advname = regexr(location_name, "[^a-zA-Z0-9]", "")
replace advname = subinstr(advname, " ", "", .)
gen advname6 = substr(advname, 1, 6)

gen gname = regexr(g_name, "[^a-zA-Z0-9]", "")
replace gname = subinstr(gname, " ", "", .)
gen gname6 = substr(gname, 1, 6)
replace advname6 = lower(advname6)
replace gname6 = lower(gname6)

gen advaddr = regexr(street_address, "[^a-zA-Z0-9]", "")
replace advaddr = subinstr(advaddr, " ", "", .)
gen advaddr6 = substr(advaddr, 1, 6)
replace advaddr6 = lower(advaddr6)

gen gaddr = regexr(street, "[^a-zA-Z0-9]", "")
replace gaddr = subinstr(gaddr, " " , "", .)
gen gaddr6 = substr(gaddr, 1, 6)
replace gaddr6 = lower(gaddr6)

matchit advaddr6 gaddr6, gen(loc_score6)

matchit advname6 gname6, gen(name_score6)

gen match = 0
replace match = 1 if name_score > .5 & loc_score3 > .5 & km_to_locid < .1
replace match = 1 if match == 0 & name_score6 >= .8 & km_to_locid < .1
replace match = 1 if match == 0 & name_score6 >= .8 & loc_score3 > .9
replace match = 1 if loc_score3 == 1
replace match = 1 if loc_score6 == 1 & km_to_locid < .1
replace match = 1 if name_score6 == 1 & loc_score6 == 1
replace match = 0 if name_score < .5 & km_to_locid > .5
sort match
order match
replace match = 0 if name_score6 < .6 & loc_score6 < .6
split street_address
rename street_address1 advnum
drop street_address2-street_address10
split street
rename street1 gnum
drop street2-street26
replace match = 1 if match == 0 & km_to_locid < .05 & advnum == gnum
tab match
order match location_name street_address g_name g_address name_score loc_score km_to_locid name_score6 loc_score6 latitude longitude raw_visit_count status

keep if match == 1

save "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Matched/AllSmokeMatch0524Final.dta", replace

***Next, Cigar Shops***
use USAtobaccoAll0524, clear

drop if raw_visit_count == .

geonear advid latitude longitude using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Cleaned/USAallCigarFinal.dta", neighbors(locid latitude longitude) within(1) long
merge m:1 advid using USAtobaccoAll0524
drop _merge
merge m:1 locid using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Cleaned/USAallCigarFinal.dta"
drop _merge

rename full_address g_address
rename name g_name
gen adv_lower = lower(location_name)
gen loc_lower = lower(g_name)
gen loc_adr_l = lower(g_address)
gen adv_adr_l = lower(street_address)
matchit adv_adr_l loc_adr_l, generate(loc_score)
matchit adv_lower loc_lower, generate(name_score)
matchit street_address street, gen(loc_score3)

gen advname = regexr(location_name, "[^a-zA-Z0-9]", "")
replace advname = subinstr(advname, " ", "", .)
gen advname6 = substr(advname, 1, 6)

gen gname = regexr(g_name, "[^a-zA-Z0-9]", "")
replace gname = subinstr(gname, " ", "", .)
gen gname6 = substr(gname, 1, 6)
replace advname6 = lower(advname6)
replace gname6 = lower(gname6)

gen advaddr = regexr(street_address, "[^a-zA-Z0-9]", "")
replace advaddr = subinstr(advaddr, " ", "", .)
gen advaddr6 = substr(advaddr, 1, 6)
replace advaddr6 = lower(advaddr6)

gen gaddr = regexr(street, "[^a-zA-Z0-9]", "")
replace gaddr = subinstr(gaddr, " " , "", .)
gen gaddr6 = substr(gaddr, 1, 6)
replace gaddr6 = lower(gaddr6)

matchit advaddr6 gaddr6, gen(loc_score6)

matchit advname6 gname6, gen(name_score6)

gen match = 0
replace match = 1 if name_score > .5 & loc_score3 > .5 & km_to_locid < .1
replace match = 1 if match == 0 & name_score6 >= .8 & km_to_locid < .1
replace match = 1 if match == 0 & name_score6 >= .8 & loc_score3 > .9
replace match = 1 if loc_score3 == 1
replace match = 1 if loc_score6 == 1 & km_to_locid < .1
replace match = 1 if name_score6 == 1 & loc_score6 == 1
replace match = 0 if name_score < .5 & km_to_locid > .5
sort match
order match
replace match = 0 if name_score6 < .6 & loc_score6 < .6
split street_address
rename street_address1 advnum
drop street_address2-street_address10
split street
rename street1 gnum
drop street2-street22
replace match = 1 if match == 0 & km_to_locid < .05 & advnum == gnum
tab match
order match location_name street_address g_name g_address name_score loc_score km_to_locid name_score6 loc_score6 latitude longitude raw_visitor_count status

keep if match == 1

save "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Matched/AllCigarMatch0524Final", replace


***The matching process creates some duplicates. We now reduce to one at each store***
cd "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Matched"
use AllVapeMatch0524Final, clear
drop tag
bys street_address: gen tag = _N
tab tag
bys street_address: egen double maxname = max(name_score)
drop if tag > 1 & name_score < maxname
drop tag 
bys street_address: gen tag = _N
order tag match
tab tag
sort tag latitude longitude
bys street_address: egen maxrev = max(review)
drop if tag > 1 & review < maxrev
sort tag
drop tag maxname maxrev
bys g_address: gen tag = _N
bys g_address: egen double maxname = max(name_score)
drop if tag > 1 & name_score < maxname
drop tag maxname
bys g_address: gen tag = _N
bys g_address: egen minkm = min(km_to_locid)
drop if tag > 1 & km_to_locid > minkm
save, replace

use AllSmokeMatch0524Final, clear
drop tag
bys street_address: gen tag = _N
tab tag
bys street_address: egen double maxname = max(name_score)
drop if tag > 1 & name_score < maxname
drop tag 
bys street_address: gen tag = _N
order tag match
tab tag
sort tag latitude longitude
bys street_address: egen maxrev = max(review)
drop if tag > 1 & review < maxrev
sort tag
bys street_address: egen double minkm = min(km_to_locid)
drop if tag > 1 & km_to_locid > minkm
drop tag 
bys street_address: gen tag = _N
order tag
sort tag latitude longitude
drop tag maxname maxrev minkm
bys g_address: gen tag = _N
bys g_address: egen double maxname = max(name_score)
drop if tag > 1 & name_score < maxname
drop tag
bys g_address: gen tag = _N
bys g_address: egen double minkm = min(km_to_locid)
drop if tag > 1 & km_to_locid > minkm
drop tag maxname minkm
bys g_address: gen tag = _N
save, replace

use AllCigarMatch0524Final, clear
drop tag
bys street_address: gen tag = _N
tab tag
bys street_address: egen double maxname = max(name_score)
drop if tag > 1 & name_score < maxname
drop tag 
bys street_address: gen tag = _N
order tag match
tab tag
sort tag latitude longitude
bys street_address: egen maxrev = max(review)
drop if tag > 1 & review < maxrev
drop tag maxname maxrev
bys g_address: gen tag = _N
bys g_address: egen double maxname = max(name_score)
drop if tag > 1 & name_score < maxname
drop tag maxname
bys g_address: gen tag = _N
bys g_address: egen double minkm = min(km_to_locid)
drop if tag > 1 & km_to_locid > minkm

save, replace

***Append the files**
**We decided not to include hookah in this**
use AllVapeMatch0524Final, clear
append using AllSmokeMatch0524Final
append using AllCigarMatch0524Final


save AllMatchVapeSmokeCigarFinal, replace

***Remove any Google Place duplicates, keeping the one with the closest name match***
drop tag
bys google_id: gen tag = _N
bys google_id: egen maxname = max(name_score)
gen tag1 = 1 if tag > 1 & name_score == maxname 
keep if tag == 1 | tag1 == 1

save, replace
log close 

***Begin separate results code log here***
*************************
***Google Only Results***
*************************
log using "/cluster/VAST/mp94p-lab/Landini/Figures/DatabaseResults.log", replace
use "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Cleaned/GoogleUSA0524", clear 
geoinpoly latitude longitude using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Matched/AllTracts_shp.dta"
merge m:1 _ID using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Matched/AllTracts.dta"
gen fips = TRACT
gen popdensity = POPULATION/LAND_AREA

drop ID AREA COLORING TRACT-_merge 
merge m:1 fips using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/ACSTract19.dta"
drop _merge 
drop if missing(fips)
drop tag 
gen store = 1 if vapetag == 1 | tobaccotag == 1 | cigartag == 1
bys fips: egen tractN = sum(store)
replace tractN = 0 if tractN == .
rename totalpop Population
rename age0008 AGE_15_TO
rename age0009 AGE_20_TO

gen tractNper = tractN/(Population/100000)
replace tractN = 0 if missing(tractN)
replace tractNper = 0 if missing(tractNper)

gen age1519pct = (AGE_15_TO/Population)*100
gen age2024pct = (AGE_20_TO/Population)*100
gen age1524pct = age1519pct + age2024pct
gen malepct = (totalmale/Population)*100

bys fips: egen tractvape = sum(vapetag)
bys fips: fillmissing(tractvape)
bys fips: replace tractvape = 0 if missing(tractvape)
gen tractvapeper = tractvape/(Population/100000)

bys fips: gen tracttobacco = sum(tobaccotag)
bys fips: fillmissing(tracttobacco)
bys fips: replace tracttobacco = 0 if missing(tracttobacco)
gen tracttobaccoper = tracttobacco/(Population/100000)

bys fips: gen tractcigar = sum(cigartag)
bys fips: fillmissing(tractcigar)
bys fips: replace tractcigar = 0 if missing(tractcigar)
gen tractcigarper = tractcigar/(Population/100000)

gen minoritypct = ((Population-NonHispanicWA)/Population)*100
gen bachelorpct = o25bachelorormore/o25*100

collapse (max) tractN tractNper bachelorpct minoritypct Population popdensity age1519pct age1524pct malepct tractvape tracttobacco tractcigar tractvapeper tracttobaccoper tractcigarper, by(fips)

label var tractN "Tract Locations"
label var tractNper "Tract Locations per 100K"
label var bachelorpct "Bachelors \%"
label var malepct "Male \%"
*label var vapeHHI "Herfindahl Visit Index"
label var Population "Population"
label var age1524pct "Age 15-24 \%"
label var minoritypct "Minority \%"

save ../BaseFiles/GoogleTractVapeSmokeCigarFinal, replace

preserve 
collapse (max) countyvape countytobacco countycigar statevape statetobacco statecigar, by(county)
save CountyStateTotals, replace
restore 

merge 1:1 fips using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Poverty.dta"
drop _merge 
label var povertypct "Poverty \%"
merge 1:1 fips using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/HHMedian.dta"
label var HH_MEDIAN_ "HH Median Income"
drop _merge

gen tract = fips
destring tract, replace

gen PopK = Population/1000 
label var PopK "Population (Thousands)"
gen HHMI_th = HH_MEDIAN_/1000
label var HHMI_th "HH Median Income (Thousands)"

gen state = substr(fips, 1, 2)
gen county = substr(fips, 1, 5)
destring county, replace
destring tract, replace


save, replace

label var tractvapeper "Vape per capita"
label var tracttobaccoper "Tobacco per capita"
label var tractcigarper "Cigar per capita"
label var popdensity "Population Density"
label var tractvape "Vape Shops"
label var tracttobacco "Smoke Shops"
label var tractcigar "Cigar Shops"

*gen county = substr(fips, 1, 5)
*destring county, replace 
merge m:1 county using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/rucc2013.dta"
drop _merge 
egen urbanpop = sum(Population) if rucc2013 < 4
egen ruralpop = sum(Population) if rucc2013 > 3
gen totalpop = urbanpop+ruralpop
gen rural = 0 
replace rural = 1 if rucc2013 > 3

fillmissing urbanpop ruralpop
format urbanpop ruralpop %15.0f

gen HSorLess = 100-bachelorpct
gen femalepct = 100-malepct
label var HSorLess "No Bachelors%"
label var femalepct "Female \%"

replace rural = rural*100
label var rural "Rural"
*gen state = substr(fips, 1, 2)
drop if inlist(state, "60", "66", "69", "72", "74", "78")
gen countyno = substr(fips, 3, 3)
destring countyno, replace
drop if countyno > 900

foreach v in tractvape tracttobacco tractcigar {
	gen ln`v' = ln(`v')
}

foreach v in lntractvape lntracttobacco lntractcigar {
	replace `v' = 0 if missing(`v')
}

save, replace

**Summary**
estpost sum tractvape tracttobacco tractcigar age1524pct minoritypct femalepct povertypct HSorLess [aweight = Population]

sum rural

esttab using GoogleTractSumFinal.tex, replace cells("mean(f(%9.4f)) sd(f(%9.4f)) min(f(%9.0f)) max(f(%9.0f))") label

***Stats in Results Paragraph***
replace tractN = 0 if missing(tractN)
distinct fips if tractN > 0

tab tractN if tractN > 0

sum tractvape tracttobacco tractcigar [aweight = Population]

***Figure 3***
estimates drop _all 
areg tractvapeper age1524pct minoritypct femalepct povertypct rural HSorLess [aweight = Population], absorb(state) vce(robust)
est sto m1
areg tracttobaccoper age1524pct minoritypct femalepct povertypct rural HSorLess [aweight = Population], absorb(state) vce(robust)
est sto m2
areg tractcigarper age1524pct minoritypct femalepct povertypct rural HSorLess [aweight = Population], absorb(state) vce(robust)
est sto m3
*areg tracthookahper age1524pct minoritypct femalepct povertypct rural HSorLess [aweight = Population], absorb(state) vce(robust)
*est sto m4 

label var age1524pct "Age 15-24 %"
label var minoritypct "Minority %"
label var povertypct "Poverty %"
label var rural "Rural = 1"
label var HSorLess "No Bachelors %"
ssc install coefplot 
coefplot (m1, label(Vape Shops) msymbol(circle)) (m2, label(Smoke Shops) msymbol(diamond)) (m3, label(Cigar Shops) msymbol(square)) /*(m4, label(Hookah) msymbol(triangle))*/, levels(95) drop(_cons femalepct) vertical yline(0, lwidth(thin)) title("", margin(0 0 2 0)) xlab(,labsize(small)) ylab(,labsize(small)) xline(1.5 2.5 3.5 4.5 5.5, lpattern(-) lcolor(gs15)) msize(small) 
graph save "Graph" "/cluster/VAST/mp94p-lab/Landini/Figures/GoogleFig3.gph", replace
graph export "/cluster/VAST/mp94p-lab/Landini/Figures/GoogleFig3.gph", as(png) replace

estimates drop _all 


***Maps***
bys county: egen countyPop = sum(Population)
bys state: egen statePop = sum(Population)

foreach v in N vape tobacco cigar {
bys county: egen county`v' = sum(tract`v')
bys state: egen state`v' = sum(tract`v')
bys county: gen county`v'per = county`v'/(countyPop/100000)
bys state: gen state`v'per = state`v'/(statePop/100000)
}

save, replace

collapse (max) countyN-statecigarper countyPop, by(county)

**Summary***
drop if countyPop == 0
sum countyvapeper countytobaccoper countycigarper [aweight = countyPop]
egen UStotalvape = sum(countyvape)
egen UStotalsmoke = sum(countytobacco)
egen UStotalcigar = sum(countycigar)

replace countyNper = . if countyNper == 0
maptile countyNper, geo(county2010) nq(10) stateoutline(vthin) twopt(title("") legend(label(1 "No Stores") size(small))) ndf(white) legf(%4.1f)
graph save "Graph" "../../Figures/GoogleStores.gph", replace
graph export "../../Figures/GoogleStores.png", as(png) name("Graph") replace

replace countyvapeper = . if countyvapeper == 0
maptile countyvapeper, geo(county2010) cutv(.5 1 2 5 10 20 30) stateoutline(vthin) twopt(legend(label(1 "No Stores") label(2 "0.1 {&minus} 0.5") label(9 "30.0+") size(small))) ndf(white) legf(%4.1f)
graph save "Graph" "../../Figures/GoogleVape.gph", replace
graph export "../../Figures/GoogleVape.png", as(png) name("Graph") replace

replace countytobaccoper = . if countytobaccoper == 0
maptile countytobaccoper, geo(county2010) cutv(.5 1 2 5 10 20 30) stateoutline(vthin) twopt(legend(label(1 "No Stores") label(2 "0.1 {&minus} 0.5") label(9 "30.0+") size(small))) ndf(white) legf(%4.1f)
graph save "Graph" "../../Figures/GoogleSmoke.gph", replace
graph export "../../Figures/GoogleSmoke.png", as(png) name("Graph") replace

replace countycigarper = . if countycigarper == 0
maptile countycigarper, geo(county2010) cutv(.5 1 2 5 10 20 30) stateoutline(vthin) twopt(legend(label(1 "No Stores") label(2 "0.1 {&minus} 0.5") label(9 "30.0+") size(small))) ndf(white) legf(%4.1f)
graph save "../../Figures/GoogleCigar.gph", replace
graph export "../../Figures/GoogleCigar.png", as(png) name("Graph") replace
tostring county, gen(fips) format(%05.0f)
save "CountyTobacco.dta", replace

spshape2dta "C:\Users\ajlncv\OneDrive - University of Missouri\PGC Project\Other Info\IowaShapefile\cb_2018_us_county_500k", replace
use cb_2018_us_county_500k, clear
gen fips = STATEFP+COUNTYFP
merge 1:1 fips using "CountyTobacco.dta"
keep if _merge == 3
drop _merge 
spset 

save cb_2018_us_county_500k, replace

drop if STATEFP == "02" | STATEFP == "15"
spcompress

bimap countyNper countyPop using cb_2018_us_county_500k_shp, bins(4) textx("Total Population") texty("Stores per 100k") ndfcolor(black) 

*********************
***Matched Results***
*********************
/*Tract level not used and is commented out
***First we need to tag our matched results to the correct census tract***
use "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Matched/AllMatchVapeSmokeCigarFinal", clear
sum vapetag tobaccotag cigartag 
geoinpoly latitude longitude using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Matched/AllTracts_shp.dta"
merge m:1 _ID using AllTracts.dta
gen fips = TRACT
gen popdensity = POPULATION/LAND_AREA

drop ID AREA COLORING TRACT-_merge 
rename raw_visit_counts visits
rename raw_visitor_counts visitors 
merge m:1 fips using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/ACSTract19.dta"
drop _merge 

bys fips: egen tractN = sum(match) if visits != 0
replace tractN = 0 if tractN == .
bys fips: egen tractvisits = sum(visits)
gen visitshare = visits/tractvisits
gen visitsharesq = visitshare^2
bys fips: egen HHI = sum(visitsharesq)
rename totpop Population
rename age0008 AGE_15_TO
rename age0009 AGE_20_TO

gen tractNper = tractN/(Population/100000)
replace tractN = 0 if missing(tractN)
replace tractNper = 0 if missing(tractNper)

gen age1519pct = (AGE_15_TO/Population)*100
gen age2024pct = (AGE_20_TO/Population)*100
gen age1524pct = age1519pct + age2024pct
gen malepct = (totalmale/Population)*100

bys fips: egen tractvape = sum(vapetag)
bys fips: fillmissing(tractvape)
bys fips: replace tractvape = 0 if missing(tractvape)
gen tractvapeper = tractvape/(Population/100000)

bys fips: gen tracttobacco = sum(tobaccotag)
bys fips: fillmissing(tracttobacco)
bys fips: replace tracttobacco = 0 if missing(tracttobacco)
gen tracttobaccoper = tracttobacco/(Population/100000)

bys fips: gen tractcigar = sum(cigartag)
bys fips: fillmissing(tractcigar)
bys fips: replace tractcigar = 0 if missing(tractcigar)
gen tractcigarper = tractcigar/(Population/100000)

/*
bys fips: gen tracthookah = sum(hookahtag)
bys fips: fillmissing(tracthookah)
bys fips: replace tracthookah = 0 if missing(tracthookah)
gen tracthookahper = tracthookah/(Population/100000)
*/

foreach v in vape tobacco cigar {
bys fips: egen tract`v'visits = sum(visits) if `v'tag == 1
bys fips: fillmissing(tract`v'visits)
replace tract`v'visits = 0 if tract`v'visits == .
gen tract`v'visitsper = tract`v'visits/(Population/100000)
bys fips: egen tract`v'visitors = sum(visitors) if `v'tag == 1
bys fips: fillmissing(tract`v'visitors)
replace tract`v'visitors = 0 if tract`v'visitors == .
gen tract`v'visitorsper = tract`v'visitors/(Population/100000)
}


gen minoritypct = ((Population-NonHispanicWA)/Population)*100
gen bachelorpct = o25bachelorormore/o25*100

gen visitorshare = visitors/tractvapevisitors
gen visitorsharesq = visitorshare^2 
bys fips: egen tractvisitors = sum(visitors)
bys fips: egen vapeHHIvisitors = sum(visitorsharesq)

collapse (max) tractN tractNper tractvisits tractvisitors bachelorpct minoritypct Population popdensity age1519pct age1524pct malepct tractvape tracttobacco tractcigar tractvapeper tracttobaccoper tractcigarper tractvapevisits tracttobaccovisits tractcigarvisits tractvapevisitsper tracttobaccovisitsper tractcigarvisitsper tractvapevisitors tracttobaccovisitors tractcigarvisitors tractvapevisitorsper tracttobaccovisitorsper tractcigarvisitorsper, by(fips)

label var tractN "Tract Locations"
label var tractNper "Tract Locations per 100K"
label var bachelorpct "Bachelors \%"
label var malepct "Male \%"
*label var vapeHHI "Herfindahl Visit Index"
label var Population "Population"
label var age1524pct "Age 15-24 \%"
label var minoritypct "Minority \%"

save ../BaseFiles/TractMapVapeSmokeCigarFinal, replace

***Need to add separate poverty and income variables***
merge 1:1 fips using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Poverty.dta"
drop _merge 
label var povertypct "Poverty \%"
merge 1:1 fips using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/HHMedian.dta"
label var HH_MEDIAN_ "HH Median Income"
drop _merge

gen tract = fips
destring tract, replace

gen PopK = Population/1000 
label var PopK "Population (Thousands)"
gen HHMI_th = HH_MEDIAN_/1000
label var HHMI_th "HH Median Income (Thousands)"

gen state = substr(fips, 1, 2)
gen county = substr(fips, 1, 5)
destring county, replace
destring tract, replace


save, replace

label var tractvapeper "Vape per capita"
label var tracttobaccoper "Tobacco per capita"
label var tractcigarper "Cigar per capita"
*label var tracthookahper "Hookah per capita"
*label var tractcannabisper "Cannabis per capita"
label var tractvapevisits "Vape visits"
label var tracttobaccovisits "Tobacco visits"
label var tractcigarvisits "Cigar visits"
*label var tracthookahvisits "Hookah visits"
*label var tractcannabisvisits "Cannabis visits"
label var popdensity "Population Density"
label var tractvapevisitors "Vape Visitors"
label var tracttobaccovisitors "Tobacco Visitors"
label var tractcigarvisitors "Cigar Visitors"
*label var tracthookahvisitors "Hookah Visitors"
label var tractvape "Vape Shops"
label var tracttobacco "Smoke Shops"
label var tractcigar "Cigar Shops"
*label var tracthookah "Hookah Shops"


merge m:1 county using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/rucc2013.dta"
drop _merge 
egen urbanpop = sum(Population) if rucc2013 < 4
egen ruralpop = sum(Population) if rucc2013 > 3
gen totalpop = urbanpop+ruralpop
gen rural = 0 
replace rural = 1 if rucc2013 > 3

fillmissing urbanpop ruralpop
format urbanpop ruralpop %15.0f

gen HSorLess = 100-bachelorpct
gen femalepct = 100-malepct
label var HSorLess "No Bachelors%"
label var femalepct "Female \%"

replace rural = rural*100
label var rural "Rural"
drop if inlist(state, "60", "66", "69", "72", "74", "78")

foreach v in tractvapevisits tractvapevisitors tracttobaccovisits tracttobaccovisitors tractcigarvisits tractcigarvisitors tractvape tracttobacco tractcigar {
	gen ln`v' = ln(`v')
}

foreach v in lntractvapevisits lntracttobaccovisits lntractcigarvisits lntractvape lntracttobacco lntractcigar lntractvapevisitors lntracttobaccovisitors lntractcigarvisitors {
	replace `v' = 0 if missing(`v')
}

save, replace

**Summary**
estpost sum tractvape tracttobacco tractcigar age1524pct minoritypct femalepct povertypct HSorLess tractvapevisitors tracttobaccovisitors tractcigarvisitors [aweight = Population]

sum rural

esttab using TractSumFinal.tex, replace cells("mean(f(%9.4f)) sd(f(%9.4f)) min(f(%9.0f)) max(f(%9.0f))") label

foreach v in vape tobacco cigar {
	sum tract`v' if tract`v' > 0
}

**************
***Figure 3***
**************
estimates drop _all 
areg tractvapeper age1524pct minoritypct femalepct povertypct rural HSorLess [aweight = Population], absorb(state) vce(robust)
est sto m1
areg tracttobaccoper age1524pct minoritypct femalepct povertypct rural HSorLess [aweight = Population], absorb(state) vce(robust)
est sto m2
areg tractcigarper age1524pct minoritypct femalepct povertypct rural HSorLess [aweight = Population], absorb(state) vce(robust)
est sto m3
*areg tracthookahper age1524pct minoritypct femalepct povertypct rural HSorLess [aweight = Population], absorb(state) vce(robust)
*est sto m4 

label var age1524pct "Age 15-24 %"
label var minoritypct "Minority %"
label var povertypct "Poverty %"
label var rural "Rural = 1"
label var HSorLess "No Bachelors %"
ssc install coefplot 
coefplot (m1, label(Vape) msymbol(circle)) (m2, label(Tobacco) msymbol(diamond)) (m3, label(Cigar) msymbol(square)) /*(m4, label(Hookah) msymbol(triangle))*/, levels(95) drop(_cons femalepct) vertical yline(0, lwidth(thin)) title("", margin(0 0 2 0)) xlab(,labsize(small)) ylab(,labsize(small)) xline(1.5 2.5 3.5 4.5 5.5, lpattern(-) lcolor(gs15)) msize(small) 

estimates drop _all 
*/
******************
***County Level***
******************
use AllMatchVapeSmokeCigarFinal, clear

geoinpoly latitude longitude using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Matched/AllTracts_shp.dta"
merge m:1 _ID using AllTracts.dta
gen fips = TRACT
gen county = substr(fips, 1, 5)
bys county: egen countyPop = sum(POPULATION)
bys county: egen countyArea = sum(LAND_AREA)
gen countypopdensity = countyPop/countyArea


drop ID AREA COLORING TRACT-_merge 
rename raw_visit_counts visits
rename raw_visitor_counts visitors 
merge m:1 fips using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/ACSTract19.dta"
drop _merge 
replace county = substr(fips, 1, 5)

rename totpop Population
rename age0008 AGE_15_TO
rename age0009 AGE_20_TO

bys county: fillmissing countyPop
bys county: egen countyN = sum(match)
replace countyN = 0 if missing(countyN)
gen countyNper = countyN/(countyPop/100000)
foreach v in vape tobacco cigar {
bys county: egen county`v' = sum(`v'tag)
bys county: fillmissing(county`v')
bys county: replace county`v' = 0 if missing(county`v')
gen county`v'per = county`v'/(countyPop/100000)
}

bys county: egen countyvisits = sum(visits)
bys county: egen countyvisitors = sum(visitors)

foreach v in vape tobacco cigar {
bys county: egen county`v'visits = sum(visits) if `v'tag == 1
bys county: fillmissing(county`v'visits)
replace county`v'visits = 0 if county`v'visits == .
gen county`v'visitsper = county`v'visits/(countyPop/100000)
bys county: egen county`v'visitors = sum(visitors) if `v'tag == 1
bys county: fillmissing(county`v'visitors)
replace county`v'visitors = 0 if county`v'visitors == .
gen county`v'visitorsper = county`v'visitors/(countyPop/100000)
}

***Need to add separate poverty and income variables***
merge m:1 fips using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Poverty.dta"
drop _merge 
label var povertypct "Poverty \%"
merge m:1 fips using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/HHMedian.dta"
label var HH_MEDIAN_ "HH Median Income"
drop _merge

bys county: egen countypovbase = sum(povbase)
bys county: egen countyinpov = sum(inpov)
gen countypovertypct = countyinpov/countypovbase*100
label var countypovertypct "Poverty%"

bys county: egen county1519 = sum(AGE_15_TO)
bys county: egen county2024 = sum(AGE_20_TO)
gen county1524pct = (county1519 + county2024)/countyPop*100

bys county: egen countybachelor = sum(o25bachelorormore)
bys county: egen countyo25 = sum(o25)
gen countybachelorpct = countybachelor/countyo25*100

bys county: egen CountyNH = sum(NonHispanicWA)
gen countyminoritypct = ((countyPop-CountyNH)/countyPop)*100

bys county: egen countyfemale = sum(totalfemale)
gen countyfemalepct = totalfemale/countyPop*100

destring county, replace 
merge m:1 county using "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/rucc2013.dta" 
drop _merge 
egen urbanpop = sum(Population) if rucc2013 < 4
egen ruralpop = sum(Population) if rucc2013 > 3
gen rural = 0 
replace rural = 1 if rucc2013 > 3

gen countyHSorLess = 100-countybachelorpct 

collapse (max) countyN countyNper countyvisits countyvisitors countybachelorpct countyminoritypct countyPop countypopdensity county1524pct countyfemalepct countypovertypct countyHSorLess rural countyvape countytobacco countycigar countyvapeper countytobaccoper countycigarper countyvapevisits countytobaccovisits countycigarvisits countyvapevisitsper countytobaccovisitsper countycigarvisitsper  countyvapevisitors countytobaccovisitors countycigarvisitors countyvapevisitorsper countytobaccovisitorsper countycigarvisitorsper, by(county)

save CountyRegVapeSmokeCigarFinal.dta, replace
/*
***Fig 3 at the County level***
tostring county, gen(countyfips) format(%05.0f)
gen state = substr(countyfips, 1, 2)
drop if inlist(state, "60", "66", "69", "72", "74", "78")
drop if missing(state)
estimates drop _all 
areg countyvapeper county1524pct countyminoritypct countyfemalepct countypovertypct rural countyHSorLess [aweight = countyPop], absorb(state) vce(robust)
est sto m1
areg countytobaccoper county1524pct countyminoritypct countyfemalepct countypovertypct rural countyHSorLess [aweight = countyPop], absorb(state) vce(robust)
est sto m2
areg countycigarper county1524pct countyminoritypct countyfemalepct countypovertypct rural countyHSorLess [aweight = countyPop], absorb(state) vce(robust)
est sto m3
areg countyhookahper county1524pct countyminoritypct countyfemalepct countypovertypct rural countyHSorLess [aweight = countyPop], absorb(state) vce(robust)
est sto m4 

label var county1524pct "Age 15-24 %"
label var countyminoritypct "Minority %"
label var countypovertypct "Poverty %"
label var rural "Rural = 1"
label var countyHSorLess "No Bachelors %"

coefplot (m1, label(Vape) msymbol(circle)) (m2, label(Tobacco) msymbol(diamond)) (m3, label(Cigar) msymbol(square)) (m4, label(Hookah) msymbol(triangle)), levels(95) drop(_cons countyfemalepct) vertical yline(0, lwidth(thin)) title("", margin(0 0 2 0)) xlab(,labsize(small)) ylab(,labsize(small)) xline(1.5 2.5 3.5 4.5 5.5, lpattern(-) lcolor(gs15)) msize(small) 
*/
estimates drop _all 

tostring county, gen(countyfips) format(%05.0f)
gen state = substr(countyfips, 1, 2)


foreach v of varlist countyvapevisits-countycigarvisitorsper {
	gen ln`v' = ln(`v')
}

order state, first
foreach v of varlist countyvape-countycigarvisitsper lncountyvapevisits-lncountycigarvisitorsper countyvapevisits-lncountycigarvisitsper {
	replace `v' = 0 if missing(`v')
}

save, replace
/*
***Table 2***
estimates drop _all 
reg lncountyvapevisitors countyvape [aweight = countyPop], robust
est sto m1
reg lncountyvapevisitors countyvape [aweight = countyPop] if countyvape > 0, robust
est sto m2

reg lncountytobaccovisitors countytobacco [aweight = countyPop], robust
est sto m1
reg lncountytobaccovisitors countytobacco [aweight = countyPop] if countytobacco > 0, robust
est sto m2

reg lncountycigarvisitors countycigar [aweight = countyPop], robust
est sto m1
reg lncountycigarvisitors countycigar [aweight = countyPop] if countycigar > 0, robust
est sto m2

reg lncountyhookahvisitors countyhookah [aweight = countyPop], robust
est sto m1
reg lncountyhookahvisitors countyhookah [aweight = countyPop] if countyhookah > 0, robust
est sto m2

***Table 3 County***
estimates drop _all 
areg lncountyvapevisitors countyvapeper [aweight = countyPop], absorb(state) robust
est sto m1
areg lncountytobaccovisitors countyvapeper [aweight = countyPop], absorb(state) robust
est sto m2 
areg lncountycigarvisitors countyvapeper [aweight = countyPop], absorb(state) robust
est sto m3
areg lncountyhookahvisitors countyvapeper [aweight = countyPop], absorb(state) robust
est sto m4
esttab m1 m2 m3 m4 using VapeImpact.tex, tex replace b(%5.3f) se(%5.3f) star(* .1 ** .05 *** .01) label

areg lncountyvapevisitors countytobaccoper [aweight = countyPop], absorb(state) robust
est sto m5
areg lncountytobaccovisitors countytobaccoper [aweight = countyPop], absorb(state) robust
est sto m6
areg lncountycigarvisitors countytobaccoper [aweight = countyPop], absorb(state) robust
est sto m7
areg lncountyhookahvisitors countytobaccoper [aweight = countyPop], absorb(state) robust
est sto m8 
esttab m5 m6 m7 m8 using SmokeImpact.tex, tex replace b(%5.3f) se(%5.3f) star(* .1 ** .05 *** .01) label


areg lncountyvapevisitors countycigarper [aweight = countyPop], absorb(state) robust
est sto m9
areg lncountytobaccovisitors countycigarper [aweight = countyPop], absorb(state) robust
est sto m10
areg lncountycigarvisitors countycigarper [aweight = countyPop], absorb(state) robust
est sto m11
areg lncountyhookahvisitors countycigarper [aweight = countyPop], absorb(state) robust
est sto m12
esttab m9 m10 m11 m12 using CigarImpact.tex, tex replace b(%5.3f) se(%5.3f) star(* .1 ** .05 *** .01) label


areg lncountyvapevisitors countyhookahper [aweight = countyPop], absorb(state) robust
est sto m13
areg lncountytobaccovisitors countyhookahper [aweight = countyPop], absorb(state) robust
est sto m14
areg lncountycigarvisitors countyhookahper [aweight = countyPop], absorb(state) robust
est sto m15
areg lncountyhookahvisitors countyhookahper [aweight = countyPop], absorb(state) robust
est sto m16
esttab m13 m14 m15 m16 using HookahImpact.tex, tex replace b(%5.3f) se(%5.3f) star(* .1 ** .05 *** .01) label
*/
***Table 2***
drop if missing(state)
destring state, replace
drop if state > 56
drop if countyN == .
**N = 3,144 matching number of counties in US**
estimates drop _all 
areg lncountyvapevisitors countyvape countytobacco countycigar [aweight = countyPop], absorb(state) robust 
est sto m1 
areg lncountytobaccovisitors countyvape countytobacco countycigar [aweight = countyPop], absorb(state) robust 
est sto m2
areg lncountycigarvisitors countyvape countytobacco countycigar [aweight = countyPop], absorb(state) robust 
est sto m3

esttab m1 m2 m3 using ImpactCombine.tex, tex replace b(%5.3f) se(%5.3f) star(* .1 ** .05 *** .01) label

***Table 2 with County Covariates***
estimates drop _all 
areg lncountyvapevisitors countyvape countytobacco countycigar county1524pct countyminoritypct countyfemalepct countypovertypct rural countyHSorLess [aweight = countyPop], absorb(state) robust 
est sto m1 
areg lncountytobaccovisitors countyvape countytobacco countycigar county1524pct countyminoritypct countyfemalepct countypovertypct rural countyHSorLess [aweight = countyPop], absorb(state) robust 
est sto m2
areg lncountycigarvisitors countyvape countytobacco countycigar county1524pct countyminoritypct countyfemalepct countypovertypct rural countyHSorLess [aweight = countyPop], absorb(state) robust 
est sto m3

esttab m1 m2 m3 using ImpactCombine1.tex, tex replace b(%5.3f) se(%5.3f) star(* .1 ** .05 *** .01) label
/*
***Table 3, Panel B***
estimates drop _all 
areg lncountyvapevisitors countyvape countytobacco countycigar [aweight = countyPop] if countyvape > 0, absorb(state) robust 
est sto m1 
areg lncountytobaccovisitors countyvape countytobacco countycigar countyhookah [aweight = countyPop] if countytobacco > 0, absorb(state) robust 
est sto m2
areg lncountycigarvisitors countyvape countytobacco countycigar countyhookah [aweight = countyPop] if countycigar > 0, absorb(state) robust 
est sto m3
areg lncountyhookahvisitors countyvape countytobacco countycigar countyhookah [aweight = countyPop] if countyhookah > 0, absorb(state) robust 
est sto m4 
esttab m1 m2 m3 m4 using ImpactCombine.tex, tex replace b(%5.3f) se(%5.3f) star(* .1 ** .05 *** .01) label

**Table 3, Extensive Margin***
gen anyvape = countyvape > 0
gen anysmoke = countytobacco > 0
gen anycigar = countycigar > 0
estimates drop _all 
areg lncountyvapevisitors anyvape countytobacco countycigar[aweight = countyPop], absorb(state) robust 
est sto m1 
areg lncountytobaccovisitors countyvape countytobacco countycigar countyhookah [aweight = countyPop], absorb(state) robust 
est sto m2
areg lncountycigarvisitors countyvape countytobacco countycigar countyhookah [aweight = countyPop], absorb(state) robust 
est sto m3
areg lncountyhookahvisitors countyvape countytobacco countycigar countyhookah [aweight = countyPop], absorb(state) robust 
est sto m4 
esttab m1 m2 m3 m4 using ImpactCombine.tex, tex replace b(%5.3f) se(%5.3f) star(* .1 ** .05 *** .01) label
*/
***Fig 1***
ssc install maptile
ssc install spmap 
maptile_install using "http://files.michaelstepner.com/geo_county2010.zip"
maptile_install using "http://files.michaelstepner.com/geo_state.zip"
replace countyNper = . if countyNper == 0
maptile countyNper, geo(county2010) nq(10) stateoutline(vthin) twopt(title("") legend(label(1 "No Stores") size(small))) ndf(white)

replace countyvapeper = . if countyvapeper == 0
maptile countyvapeper, geo(county2010) cutv(.5 1 2 5 10) stateoutline(vthin) twopt(legend(label(1 "No Stores") label(7 "10.0+") size(small))) ndf(white)
*graph save "Graph" "../../Figures/VapeDensity2.gph", replace
*graph export "../../Figures/VapeDensity2.png", as(png) name("VapeDensity2") replace

replace countytobaccoper = . if countytobaccoper == 0
maptile countytobaccoper, geo(county2010) cutv(.5 1 2 5 10) stateoutline(vthin) twopt(legend(label(1 "No Stores") label(7 "10.0+") size(small))) ndf(white)
*graph save "Graph" "../../Figures/tobaccoDensity2.gph", replace
*graph export "../../Figures/TobaccoDensity2.png", as(png) name("TobaccoDensity2") replace

replace countycigarper = . if countycigarper == 0
maptile countycigarper, geo(county2010) cutv(.5 1 2 5 10) stateoutline(vthin) twopt(legend(label(1 "No Stores") label(7 "10.0+") size(small))) ndf(white)
*graph save "../../Figures/cigarDensity2.gph"
*graph save "../../Figures/cigarDensity2.png"

/*
replace countyhookahper = . if countyhookahper == 0
maptile countyhookahper, geo(county2010) cutv(.5 1 2 5 10) stateoutline(vthin) twopt(legend(label(1 "No Stores") label(7 "10.0+") size(small))) ndf(white)
*graph save "../../Figures/hookahDensity2.gph"
*graph save "../../Figures/hookahDensity2.png"
*/

***State and County totals
use "/cluster/VAST/mp94p-lab/Landini/GoogleLocations/Matched/TractMapVapeSmokeCigarFinal.dta", clear

gen countyno = substr(fips, 3, 3)
destring countyno, replace
drop if countyno > 900
foreach v in vape tobacco cigar {
bys county: egen county`v'total = sum(tract`v')
bys state: egen state`v'total = sum(tract`v')
}

collapse (max) countyvapetotal-statecigartotal (first) state, by(county)
order state county
tostring county, gen(countyfips) format(%05.0f)

save StateCountyTotal, replace

use ../Matched/CountyRegVapeSmokeCigarFinal, clear
rename countyvape countyvapematch
rename countytobacco countytobaccomatch
rename countycigar countycigarmatch
rename statevape statevapematch 
rename statetobacco statetobaccomatch
rename statecigar statecigarmatch 

keep countyfips countyvapematch countyvapevisitors countytobaccomatch countytobaccovisitors countycigarmatch countycigarvisitors countyPop statevapematch statetobaccomatch statecigarmatch statevapevisitors statetobaccovisitors statecigarvisitors

merge 1:1 countyfips using "Y:/Landini/GoogleLocations/Matched/CountyStateTotals"
keep if _merge == 3
drop _merge 
drop if missing(countyPop)
***3143 remaining***
save StateCountyN1, replace

foreach v in vape tobacco cigar {
	gen state`v'matchrate = state`v'match/state`v'
	gen county`v'matchrate = county`v'match/county`v'
}



preserve
***drop smallest 20% of counties***
centile countyPop, centile(20)
drop if countyPop < 8872
keep countyfips countyvape countytobacco countycigar countyvapematchrate countytobaccomatchrate countycigarmatchrate countyvapevisitors countytobaccovisitors countycigarvisitors 
export excel using "Y:/Landini/Figures/CountyTobaccoN1.xlsx", replace firstrow(var)
restore 

preserve 
**Drop smallest 10% of states***
gen state = substr(countyfips, 1, 2)
bys state: egen statePop = sum(countyPop)
sum statePop, detail
centile statePop, centile(10)

collapse (max) statevape statetobacco statecigar state*matchrate statevapevisitors statetobaccovisitors statecigarvisitors statePop, by(state)
drop if statePop < 1000000
export excel using "Y:/Landini/Figures/StateTobaccoN1.xlsx", replace firstrow(var)
restore 


log close