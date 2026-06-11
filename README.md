# OSHA Workplace-Injury Analytics — does running plants "hot" make them less safe?

A SQL + cloud-warehouse analysis of **9 years of federal workplace-injury
data** (2.4M+ establishment-years) that set out to find the point where
high labor intensity starts to raise injury rates — and found the
opposite.

**Stack:** Snowflake (medallion RAW → CLEAN → ANALYTICS) · SQL (window
functions, CTEs, `QUALIFY`) · Power BI / Tableau (dashboard) · OSHA ITA
public data.

---

## Executive summary

A common operations assumption is that pushing a plant harder — more
overtime, higher hours per worker — makes it less safe. I tested that
against every establishment in OSHA's Injury Tracking Application from
2016–2024.

**The assumption is false.** Within industry, higher operational
intensity is associated with **flat-to-lower** injury rates, not higher.
In manufacturing the median Total Case Rate *declines* as intensity rises
(3.40 → 2.00 across bands), and the lowest-intensity establishments carry
the **highest** injury rates. The pattern holds within 12 of 15
manufacturing subsectors, so it is not a Simpson's-paradox artifact.

The real driver of injury risk is **industry / work type** (median TCR
ranges from ~0 in electronics to ~5.6 in wood products — a 5x+ spread
that dwarfs any intensity effect), and secondarily a counterintuitive
signal: **low-utilization, unstable workforces** (part-time / seasonal /
high-turnover) are the hidden risk, most plausibly an experience effect.

**Actionable takeaway:** cutting overtime is not a safety lever. Safety
investment should target high-hazard work and unstable/new workforces
(training, onboarding), not labor intensity.

---

## Business problem

EHS and operations leaders need to know where to spend limited safety
resources. "Reduce overtime to reduce injuries" is intuitive and widely
assumed — but if it's wrong, money goes to an intervention that doesn't
move the outcome. This project asks two questions:

1. **Does operational intensity (hours per worker) actually predict
   injury risk?** (Tests the overtime assumption.)
2. **Within an industry, which establishments are persistently worse than
   their peers?** A company can't change its industry (uncontrollable
   risk), but it *can* fix the plants that underperform comparable
   facilities (controllable risk). The scorecard separates the two.

---

## Methodology

Three-layer Snowflake warehouse (medallion pattern):

- **RAW** — five all-string landing tables, 4.39M rows. Loads never fail;
  schema drift across years handled by keeping years in separate tables.
- **CLEAN** — one typed, standardized view unioning all years, with
  derived metrics (operational intensity, TCR, DART) defined once.
- **ANALYTICS** — deduplicated, size-filtered analysis base; one row per
  establishment-year.

Rates follow OSHA standards (TCR / DART per 200,000 hours). The
intensity–rate relationship is always evaluated **within industry** to
control for confounding, and reported as "associated with," never
"causes." Full detail in [`docs/methodology.md`](docs/methodology.md).

This was real data-quality work, not a clean dataset. Highlights (full
log in [`docs/eda_findings.md`](docs/eda_findings.md)):

- A nonsensical average intensity of **866,320** traced to data-entry
  errors in the hours field (one site reported 16 *trillion* hours) →
  switched to median + sanity bounds.
- NAICS codes with inconsistent `.00` suffixes that would have split
  industries → normalized with `SPLIT_PART`.
- 4,703 exact-duplicate establishment-years → deduplicated with a
  windowed `QUALIFY`, with a `COALESCE` fallback so blank-ID rows aren't
  wrongly merged.

---

## Skills demonstrated

- **SQL:** CTEs, window functions (`ROW_NUMBER` + `QUALIFY` for dedup),
  conditional aggregation, percentile/median functions, multi-table
  `UNION ALL` with schema reconciliation.
- **Cloud warehouse:** Snowflake medallion architecture, staging, file
  formats, gzip + encoding handling on a 495MB → 82MB load.
- **Analytical rigor:** median vs mean on skewed data, Simpson's-paradox
  control, within-industry benchmarking, correlation-vs-causation
  discipline, honest treatment of a rejected hypothesis.
- **Communication:** translating an injury-rate finding into an
  operations decision ("overtime isn't the lever").

---

## Results

**The intensity finding** (`results/intensity_bands_*.csv`,
`within_industry_check.csv`): manufacturing median TCR by intensity band
runs 3.40 → 3.00 → 2.60 → 2.40 → 2.60 → 2.40 → 2.00 — declining, not
rising. Inverse holds within 12/15 subsectors.

**The peer-benchmarking scorecard** (`results/aerospace_scorecard.csv`):
aerospace establishments that are **persistently** above their 6-digit
NAICS peer median (appear ≥3 years, above peers in ≥75% of years). The
list surfaces recognizable firms running 5–10x their peer median — e.g.
Scaled Composites (TCR 10.15 vs peer 1.18), and multiple Lockheed Martin,
Boeing, GKN, Safran, and Magellan sites. The method is industry-agnostic:
replicating to automobile manufacturing is a one-line filter change.

**SpaceX case study** (`results/spacex_establishment_year.csv`): within
SpaceX, sites vary sharply. Brownsville/Starbase (rapidly growing,
TCR 4.2–5.8) is the highest-rate site, well above the 0.40 space-vehicle
subsector median; Hawthorne (mature flagship, ~7,000+ employees,
TCR 1.2–1.8) is relatively safe; McGregor (engine test) sits at 2.4–3.8.
Both major sites run similar intensity (~2,200–2,500), so the gap is not
intensity — consistent with the macro finding that workforce newness and
work type, not overtime, drive risk.

*(Dashboard: Power BI / Tableau Public — link to be added.)*

---

## Next steps

- **Cost layer:** attach dollar estimates to incidents (lost workdays ×
  published lost-time-claim cost) to quantify the financial impact at
  high-risk sites, using the Case Detail table.
- **"What drives injuries":** use Case Detail event / source / body-part
  fields to characterize *what kind* of incidents dominate at the
  flagged establishments.
- **Replicate the scorecard** to automobile manufacturing (3361/3362/
  3363) — a single filter change.

---

## Repository layout

```
osha-ita-safety-analytics/
├── README.md                  ← you are here
├── sql/
│   ├── 00_setup.sql           database, schemas, stage, file formats
│   ├── 01_raw_load.sql        RAW landing tables + COPY INTO
│   ├── 02_clean_summary.sql   typed/standardized CLEAN view
│   ├── 03_analysis_base.sql   deduped, filtered analysis base
│   ├── 04_eda.sql             data-quality checks
│   ├── 05_intensity_analysis.sql   the core finding (hypothesis test)
│   └── 06_scorecard.sql       peer-benchmarking scorecard + SpaceX
├── docs/
│   ├── methodology.md         rate definitions, filters, caveats
│   └── eda_findings.md        data-quality decisions ("war stories")
├── results/                   query-output CSVs (+ charts/ for screenshots)
└── data/README.md             source link + how to reproduce (raw not committed)
```

## Data & reproducibility

Built on public OSHA ITA data; raw files are **not** committed (large,
public records). See [`data/README.md`](data/README.md) for the source
link and run order. Company names appear because the data is public
government record; they are presented factually for benchmarking, not as
claims about any company.
