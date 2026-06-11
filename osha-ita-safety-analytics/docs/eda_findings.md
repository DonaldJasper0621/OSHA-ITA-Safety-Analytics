# EDA findings & data-quality decisions

Each finding follows the pattern: **what I checked → what I found →
what I decided.** These are the data-quality issues that shaped the
cleaning rules.

---

## 1. A broken mean exposed data-entry errors in the hours field

**Checked:** average operational intensity on the full CLEAN table.

**Found:** `AVG(intensity) = 866,320` — absurd (a worker can log at most
8,760 hours in a year). But `MEDIAN(intensity) = 1,811` (sane), with
p25–p75 = 1,417–2,063 and p99 = 4,128. So 99% of establishments are in a
reasonable range; the mean was being destroyed by a few extreme outliers.
Drilling into the worst rows showed the root cause is the
`TOTAL_HOURS_WORKED` field, not employee count — e.g. an establishment
with 7 employees reporting **16,831,620,723,179 hours** (16 trillion,
older than the universe). Employee counts looked normal; the hours were
fat-fingered.

**Decided:** the formula is correct; this is right-skewed data with a few
data-entry errors. Report the median, not the mean, and filter the
analytical population on `intensity <= 6000` to remove the impossible
values (keeps p99 = 4,128, so real high-intensity plants survive). After
the filter the mean dropped to 1,741 (tracking the median 1,811), TCR
from 24 → 4.99, DART from 13 → 3.26 — all sane.

Counts of problem rows: impossible (intensity > 8,760) = 16,398 (0.58%);
employees = 0 → 10,322; hours = 0 → 9,882; very low (intensity < 500) →
102,089 (mostly legitimate seasonal/part-time).

---

## 2. NAICS codes carried an inconsistent ".00" suffix

**Checked:** distinct NAICS codes.

**Found:** some codes had a trailing `.00` (e.g. `238140.00`,
`442110.00`, `561730.00`) while others did not (`332322`). Left as-is,
`group by` industry would split `442110` and `442110.00` into two
different industries.

**Decided:** normalize in the CLEAN view with
`SPLIT_PART(TRIM(NAICS_CODE), '.', 1)`, which strips the suffix and is
safe on codes that have no delimiter.

---

## 3. Exact-duplicate establishment-year rows

**Checked:** total rows vs distinct establishment-year combinations.

**Found:** 4,703 establishment-year pairs appear exactly twice (9,406
rows, 0.33%). Spot-checks (e.g. Ricoh USA 2018) showed the two rows are
**identical in every field**, including the blank `created_timestamp` —
so these are true duplicate copies, not amended versions. The duplicates
are concentrated in the OLD (2016–2022) data, where `created_timestamp`
is blank.

**Decided:** deduplicate in the analysis base with
`ROW_NUMBER() ... QUALIFY = 1`, partitioned by
`COALESCE(NULLIF(establishment_id,''), ID)` and year. The `COALESCE`
fallback to `ID` prevents distinct establishments with a blank
`establishment_id` from being collapsed into one. Filtering happens
before dedup, which is safe because the duplicates are identical (both
copies pass or fail the filter together).

---

## 4. Schema drift across years

**Checked:** column layouts of the source files.

**Found:** the OLD summary (2016–2022) has no `NAICS_YEAR` and a different
column order; 2023 vs 2024 swap the positions of `CREATED_TIMESTAMP` and
`CHANGE_REASON`; case detail uses `YEAR_FILING_FOR` (2023) vs
`YEAR_OF_FILING` (2024).

**Decided:** keep the years in separate RAW tables and re-align them by
column **name** in the CLEAN union (not by position), filling missing
columns (`NAICS_YEAR` for OLD) with NULL.

---

## 5. The headline hypothesis was overturned (the most important finding)

**Checked:** median TCR/DART by intensity band, within aerospace (3364)
and all manufacturing (31–33).

**Found:** higher intensity is **not** associated with higher injury
rates. Manufacturing median TCR *declines* across bands
(3.40 → 3.00 → 2.60 → 2.40 → 2.60 → 2.40 → 2.00); the lowest-intensity
band has the highest rate. Aerospace is flat. Re-tested within each
3-digit manufacturing subsector to rule out Simpson's paradox: 12 of 15
subsectors show low-intensity TCR > high-intensity, 2 flat, 1 marginal
reversal (electronics, the safest subsector). The inverse is real, not a
pooling artifact.

**Decided:** reframe the project. The original "find the overwork
threshold" hypothesis is rejected; the headline becomes "tested a common
assumption, found it false, identified the real drivers." Industry is the
dominant driver (median TCR ranges ~0 in electronics to ~5.6 in wood —
a 5x+ spread that dwarfs the ~30% intensity effect). Intensity is most
plausibly a proxy for workforce stability/experience (label: interpretation,
not proven — no tenure column). This honest pivot is the centerpiece of
the writeup.
