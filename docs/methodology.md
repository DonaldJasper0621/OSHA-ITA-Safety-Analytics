# Methodology

## Grain

- **Summary table:** one row = one establishment × one reporting year.
- **Analysis base:** same grain, deduplicated to one row per
  establishment-year and filtered to a stable analytical population.

## Metrics

**Operational intensity** = `total_hours_worked / annual_average_employees`
≈ average annual hours per worker. ~2,000 is normal full-time; >2,200 is
"running hot" (overtime); <1,800 signals part-time / seasonal / under-
utilized. This is a derived proxy, computed in the CLEAN view.

**Injury rates** follow OSHA conventions and are computed per 200,000
hours worked (≈ 100 full-time workers per year), so establishments of
different sizes are comparable:

- **TCR (Total Case Rate, a.k.a. TRIR)**
  = `(deaths + DAFW + DJTR + other recordable cases) × 200,000 / hours`
- **DART (Days Away, Restricted, or Transferred)**
  = `(DAFW + DJTR) × 200,000 / hours` — captures lost-time severity.

A fatality is a recordable case, so deaths are included in TCR. An
"injury-only" rate (excluding illnesses) is kept as a supplementary
column but is **not** used as a headline metric — TCR and DART are the
standards an EHS reviewer expects.

## Analytical population (filters)

Applied in `ANALYTICS.ITA_SUMMARY_ANALYSIS_BASE`:

| Filter | Reason |
|--------|--------|
| `total_hours_worked >= 10000` | denominator large enough that rates are stable (a tiny shop with one recordable case otherwise hits a TCR in the hundreds) |
| `annual_average_employees >= 10` | a genuinely operating establishment |
| `operational_intensity <= 6000` | removes physically impossible values from hours-field data-entry errors (p99 intensity is 4,128, so real high-intensity plants survive) |

No intensity **lower** bound is applied at this stage — low-intensity
plants are the left end of the curve and are needed to test the
intensity–rate relationship.

For the **scorecard** only, two extra guardrails are added to suppress
self-report errors before ranking individual establishments:
`TCR_PER_200K <= 40` (physical ceiling) and
`operational_intensity BETWEEN 800 AND 4500`.

Net effect of the base filter: 2,805,762 → ~2,435,253 rows (~13%
excluded). Only ~20k of the excluded rows are true garbage
(intensity > 6000); the rest are screened by the size floors. The honest
framing is "analysis focuses on establishments large enough for stable
rates," not "discarded bad data."

## Confounding control (Simpson's paradox)

The intensity–rate relationship is always evaluated **within industry**
(by NAICS), never pooled across all industries — hazardous industries
also tend to run more hours, which would create a spurious signal in a
pooled view. The key finding was explicitly re-tested within each
3-digit manufacturing subsector to confirm it is not a pooling artifact.

## Correlation vs causation

All relationships are reported as "associated with," never "causes."
This is observational data; the workforce-stability interpretation of the
intensity finding is labeled as interpretation, because the dataset has
no tenure or turnover field to prove the mechanism.

## Known limitations

- Self-reported data with real extreme-value errors (handled via cleaning
  and sanity bounds; see `eda_findings.md`).
- The ITA reporting population is not a fixed panel year to year, so
  trends are read as rate trends, not volume.
- Space-vehicle subsectors (336414/415/419) are thin and low-injury, so
  within-subsector benchmarking is statistically weak; SpaceX is therefore
  presented as a named case study via within-company site comparison, not
  a standalone subsector benchmark.
