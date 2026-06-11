# Data

The raw data is **not committed** to this repo. The files are large
(hundreds of MB) and are public records that should be pulled from the
source rather than mirrored here.

## Source

OSHA Injury Tracking Application (ITA) — Establishment-Specific Injury
and Illness Data (public bulk CSV download):

https://www.osha.gov/Establishment-Specific-Injury-and-Illness-Data

Two record types are used:

- **300A Summary** — establishment × year, with total hours worked,
  average employees, and recordable case counts. Covers 2016–2024.
- **Case Detail** — incident-level records (injury type, body part,
  event, source). Covers 2023 onward. Used for the cost / "what drives
  injuries" layer.

## Reproducing the warehouse

1. Download the summary CSVs (2016–2022, 2023, 2024) and the case-detail
   CSVs (2023, 2024) from the link above.
2. Run the SQL in `../sql/` in order:
   - `00_setup.sql` — database, schemas, stage, file formats
   - `01_raw_load.sql` — RAW landing tables + COPY INTO
   - `02_clean_summary.sql` — typed/standardized CLEAN view
   - `03_analysis_base.sql` — deduped, filtered analysis base
   - `04_eda.sql` — data-quality checks (see `../docs/eda_findings.md`)
   - `05_intensity_analysis.sql` — the core finding
   - `06_scorecard.sql` — peer-benchmarking scorecard + SpaceX case study

## Important caveats about the data

- **Self-reported.** The data has real entry errors at the extremes
  (e.g. hours fields in the billions/trillions, impossible case counts).
  The cleaning and sanity bounds in this project exist to handle that —
  see `../docs/eda_findings.md`.
- **Reporting population is not a fixed panel.** Which establishments
  must report changes year to year as coverage rules change. Year-over-
  year comparisons use rates (per 200,000 hours), not raw counts, and
  trends should be read as rate trends, not absolute volume.
- **Case Detail is a subset of Summary** (higher-hazard establishments,
  100+ employees, with actual injuries). They join on `establishment_id`.
