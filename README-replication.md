# Replication Package: Patterns of Specialty Tobacco Retail Locations and Visitor Counts in the Unitd States

This folder contains the code and instructions to replicate the findings of "Patterns of Specialty Tobacco Retail Locations and Visitor Counts in the United States", under review at Tobacco Control.

## Data Availability Statement
- **Raw Data:** Data is proprietary with subscription from Dewey Data to Advan monthly foot traffic counts. 
- **Data Access:** Contact authors for data access instructions.

## Software Requirements
- **Primary Software:** Stata
- **Required Packages/Libraries:** - Stata: `ssc install geonear`, `ssc install matchit`, `ssc install geoinpoly`, `ssc install coefplot`, `ssc install spmap`, `ssc install maptile`, `ssc install bimap`


## Instructions
1. **Set Directory:** Open `DraftCodeFinal.do` and update `working_directory` path to your local machine folder where the relevant files are downloaded.
2. **Run Analysis:** Execute DraftCodeFinal.do from the same folder as data is stored.
3. **Estimated Run Time:**  2 hours

## List of Tables and Figures
| Exhibit | Script | Output File |
| :--- | :--- | :--- |
| Table 1: Tract Summary Statistics | `DraftCodeFinal.do` lines 520-524 | `GoogleTractSumFinal.tex` |
| Table 2: Visitor Counts by Store Type | `DraftCodeFinal.do` lines     |
`ImpactCombine1.tex`
| Figure 1: Density of Tobacco Specialty Retailers, per 100k Population | `DraftCodeFinal.do` lines         | `GoogleStores.png` |
| Figure 1: Density of Smoke, Vape and Cigar Retailers, per 100k Population | `DraftCodeFinal.do` lines         | `GoogleVape.png`, `GoogleSmoke.png`, `GoogleCigar.png` |

## Contact
For questions regarding this replication package, contact Austin Landini at Austin.Landini@missouri.edu.
