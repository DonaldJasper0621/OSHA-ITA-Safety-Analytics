# Results

Query outputs from the analysis. All numbers come from the SQL in `../sql/`
run against the OSHA ITA data in Snowflake.

| File | What it is | Produced by |
|------|------------|-------------|
| `intensity_bands_aerospace.csv` | Injury rate (TCR/DART) by operational-intensity band, aerospace 3364 | `05_intensity_analysis.sql` Q1 |
| `intensity_bands_manufacturing.csv` | Same, all manufacturing 31-33 (large N) | `05_intensity_analysis.sql` Q2 |
| `within_industry_check.csv` | Simpson's-paradox control: low- vs high-intensity TCR within each 3-digit manufacturing subsector | `05_intensity_analysis.sql` Q3 |
| `aerospace_scorecard.csv` | Establishments persistently above their 6-digit aerospace peer median (appears ≥3 yrs, above peers ≥75% of years) | `06_scorecard.sql` |
| `spacex_establishment_year.csv` | Every SpaceX (Space Exploration Technologies) establishment-year, used for the within-SpaceX site case study | derived from ITA, filtered on company name |
| `space_vehicle_subsector_medians.csv` | Sample size + median TCR for the three space-vehicle NAICS subsectors | benchmark context |

Charts/dashboard screenshots (Power BI / Tableau Public) go in `charts/`
once built, and are linked from the top-level README.

Note: a few result tables were captured during the analysis session and
transcribed here. They reproduce by re-running the corresponding SQL; the
ITA reporting population shifts slightly year to year, so absolute counts
can move marginally as OSHA revises filings.
