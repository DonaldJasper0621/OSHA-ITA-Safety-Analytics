-- =====================================================================
-- 05_intensity_analysis.sql
-- Core analysis: does operational intensity drive injury rate?
-- ---------------------------------------------------------------------
-- Original hypothesis: there is a THRESHOLD where high labor intensity
-- ("running hot") starts to raise injury rates. Result: REJECTED. The
-- relationship is flat-to-mildly-INVERSE -- lower-intensity establishments
-- have HIGHER injury rates. This file documents that test end to end.
-- Results captured in results/intensity_bands_*.csv and within_industry_check.csv.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1. Aerospace 3364: injury rate by intensity band.
-- ---------------------------------------------------------------------
WITH aero AS (
  SELECT *
  FROM ITA_DB.ANALYTICS.ITA_SUMMARY_ANALYSIS_BASE
  WHERE LEFT(NAICS_CODE, 4) = '3364'
)
SELECT
  CASE
    WHEN OPERATIONAL_INTENSITY < 1500 THEN '1. <1500'
    WHEN OPERATIONAL_INTENSITY < 1800 THEN '2. 1500-1800'
    WHEN OPERATIONAL_INTENSITY < 2000 THEN '3. 1800-2000 (normal)'
    WHEN OPERATIONAL_INTENSITY < 2200 THEN '4. 2000-2200'
    WHEN OPERATIONAL_INTENSITY < 2500 THEN '5. 2200-2500 (high)'
    WHEN OPERATIONAL_INTENSITY < 3000 THEN '6. 2500-3000 (very high)'
    ELSE '7. 3000+ (extreme)'
  END AS intensity_band,
  COUNT(*)                          AS establishment_years,
  ROUND(MEDIAN(TCR_PER_200K), 2)    AS median_tcr,
  ROUND(AVG(TCR_PER_200K), 2)       AS avg_tcr,
  ROUND(MEDIAN(DART_PER_200K), 2)   AS median_dart,
  ROUND(AVG(DART_PER_200K), 2)      AS avg_dart
FROM aero
GROUP BY 1
ORDER BY 1;
-- Aerospace: median TCR stays flat 0.8-1.4 across bands. High bands (6,7)
-- have tiny N (238, 89). No threshold.


-- ---------------------------------------------------------------------
-- Q2. All manufacturing 31-33: injury rate by intensity band.
--     (Large N -> the robust version of the relationship.)
-- ---------------------------------------------------------------------
SELECT
  CASE
    WHEN OPERATIONAL_INTENSITY < 1500 THEN '1. <1500'
    WHEN OPERATIONAL_INTENSITY < 1800 THEN '2. 1500-1800'
    WHEN OPERATIONAL_INTENSITY < 2000 THEN '3. 1800-2000 (normal)'
    WHEN OPERATIONAL_INTENSITY < 2200 THEN '4. 2000-2200'
    WHEN OPERATIONAL_INTENSITY < 2500 THEN '5. 2200-2500 (high)'
    WHEN OPERATIONAL_INTENSITY < 3000 THEN '6. 2500-3000 (very high)'
    ELSE '7. 3000+ (extreme)'
  END AS intensity_band,
  COUNT(*)                          AS establishment_years,
  ROUND(MEDIAN(TCR_PER_200K), 2)    AS median_tcr,
  ROUND(AVG(TCR_PER_200K), 2)       AS avg_tcr,
  ROUND(MEDIAN(DART_PER_200K), 2)   AS median_dart,
  ROUND(AVG(DART_PER_200K), 2)      AS avg_dart
FROM ITA_DB.ANALYTICS.ITA_SUMMARY_ANALYSIS_BASE
WHERE LEFT(NAICS_CODE, 2) IN ('31','32','33')
GROUP BY 1
ORDER BY 1;
-- Manufacturing: median TCR DECLINES with intensity:
--   3.40 -> 3.00 -> 2.60 -> 2.40 -> 2.60 -> 2.40 -> 2.00
-- Lowest-intensity band (<1500) has the HIGHEST rate. Inverse, not rising.


-- ---------------------------------------------------------------------
-- Q3. Simpson's-paradox control: does the inverse hold WITHIN each
--     3-digit manufacturing subsector (not just pooled)?
-- ---------------------------------------------------------------------
SELECT
  LEFT(NAICS_CODE,3) AS naics3,
  COUNT(*) AS n,
  ROUND(MEDIAN(CASE WHEN OPERATIONAL_INTENSITY < 1800  THEN TCR_PER_200K END),2) AS tcr_low_intensity,
  ROUND(MEDIAN(CASE WHEN OPERATIONAL_INTENSITY >= 2200 THEN TCR_PER_200K END),2) AS tcr_high_intensity,
  SUM(CASE WHEN OPERATIONAL_INTENSITY < 1800  THEN 1 ELSE 0 END) AS n_low,
  SUM(CASE WHEN OPERATIONAL_INTENSITY >= 2200 THEN 1 ELSE 0 END) AS n_high
FROM ITA_DB.ANALYTICS.ITA_SUMMARY_ANALYSIS_BASE
WHERE LEFT(NAICS_CODE,2) IN ('31','32','33')
GROUP BY 1
HAVING COUNT(*) >= 1000
ORDER BY n DESC
LIMIT 15;
-- Result: 12 of 15 subsectors show tcr_low > tcr_high (inverse holds),
-- 2 flat, 1 marginal reversal (334 electronics, the safest subsector).
-- NOT a Simpson artifact -- the inverse is real within industry.
-- Low-intensity establishments run ~30% higher median TCR on average.


-- ---------------------------------------------------------------------
-- Q4. Industry hazard hierarchy: the dominant driver is INDUSTRY.
--     (Foundation/denominator for the peer-benchmarking scorecard.)
-- ---------------------------------------------------------------------
SELECT
  NAICS_CODE,
  ANY_VALUE(INDUSTRY_DESCRIPTION) AS industry,
  COUNT(*) AS establishment_years,
  ROUND(MEDIAN(TCR_PER_200K),2)  AS median_tcr,
  ROUND(MEDIAN(DART_PER_200K),2) AS median_dart
FROM ITA_DB.ANALYTICS.ITA_SUMMARY_ANALYSIS_BASE
WHERE LEFT(NAICS_CODE,2) IN ('31','32','33')
GROUP BY NAICS_CODE
HAVING COUNT(*) >= 300
ORDER BY median_tcr DESC
LIMIT 25;
-- Industry median TCR ranges from ~0 (electronics 334) to ~5.6 (wood 321).
-- That 5x+ spread dwarfs the ~30% intensity effect -> industry/work-type
-- is the dominant driver, intensity is a secondary, inverse signal.

-- INTERPRETATION (label as interpretation, not proof):
-- Intensity is most plausibly a PROXY for workforce stability/experience,
-- not overwork. High intensity = stable, full-time, experienced core crew;
-- low intensity (part-time/seasonal/high-turnover) = more new/inexperienced
-- workers = higher injury rate per hour. The dataset has no tenure/turnover
-- column, so this mechanism cannot be proven here.
--
-- ACTIONABLE INSIGHT: cutting overtime is NOT a safety lever. Injury risk
-- is driven by industry/work-type, and secondarily by unstable/low-
-- utilization workforces -> invest in training/onboarding, not hour cuts.
