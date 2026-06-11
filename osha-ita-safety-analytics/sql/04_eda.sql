-- =====================================================================
-- 04_eda.sql
-- Exploratory data analysis on CLEAN.ITA_300A_SUMMARY_CLEAN.
-- ---------------------------------------------------------------------
-- Philosophy: EDA is INTERROGATING the data, not "looking" at it. Every
-- query asks one question and the answer drives a documented decision.
-- Findings + decisions are written up in docs/eda_findings.md.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1. Real distribution of operational intensity (median + percentiles,
--     NOT mean). The mean is destroyed by a few outliers; the median
--     tells the truth.
-- ---------------------------------------------------------------------
SELECT
  COUNT(OPERATIONAL_INTENSITY) AS n,
  ROUND(MEDIAN(OPERATIONAL_INTENSITY),1) AS median_i,
  ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY OPERATIONAL_INTENSITY),1) AS p25,
  ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY OPERATIONAL_INTENSITY),1) AS p75,
  ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY OPERATIONAL_INTENSITY),1) AS p95,
  ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY OPERATIONAL_INTENSITY),1) AS p99,
  ROUND(MAX(OPERATIONAL_INTENSITY),1) AS max_i
FROM ITA_DB.CLEAN.ITA_300A_SUMMARY_CLEAN;
-- Result: median 1,811 | p25 1,417 | p75 2,063 | p95 2,516 | p99 4,128
--         max ~2.4 trillion (garbage). 99% of plants are in a sane range.


-- ---------------------------------------------------------------------
-- Q2. How much problem data is there?
-- ---------------------------------------------------------------------
SELECT
  COUNT(*) AS total,
  SUM(CASE WHEN OPERATIONAL_INTENSITY > 8760 THEN 1 ELSE 0 END) AS impossible_gt_8760,
  SUM(CASE WHEN OPERATIONAL_INTENSITY > 5000 THEN 1 ELSE 0 END) AS implausible_gt_5000,
  SUM(CASE WHEN OPERATIONAL_INTENSITY < 500  THEN 1 ELSE 0 END) AS very_low_lt_500,
  SUM(CASE WHEN ANNUAL_AVERAGE_EMPLOYEES = 0 THEN 1 ELSE 0 END) AS emp_zero,
  SUM(CASE WHEN ANNUAL_AVERAGE_EMPLOYEES IS NULL THEN 1 ELSE 0 END) AS emp_null,
  SUM(CASE WHEN TOTAL_HOURS_WORKED = 0 THEN 1 ELSE 0 END) AS hours_zero
FROM ITA_DB.CLEAN.ITA_300A_SUMMARY_CLEAN;
-- Result: impossible (>8760) = 16,398 (0.58%) | emp=0 = 10,322
--         hours=0 = 9,882 | very low (<500) = 102,089 (mostly seasonal/PT)


-- ---------------------------------------------------------------------
-- Q3. Look at the most extreme establishments -- find the root cause.
-- ---------------------------------------------------------------------
SELECT ESTABLISHMENT_NAME, STATE, NAICS_CODE,
       ANNUAL_AVERAGE_EMPLOYEES, TOTAL_HOURS_WORKED,
       ROUND(OPERATIONAL_INTENSITY,1) AS intensity
FROM ITA_DB.CLEAN.ITA_300A_SUMMARY_CLEAN
WHERE OPERATIONAL_INTENSITY > 8760
ORDER BY OPERATIONAL_INTENSITY DESC
LIMIT 20;
-- Finding: root cause is the TOTAL_HOURS_WORKED field, NOT employee count.
-- e.g. an establishment with 7 employees reporting 16,831,620,723,179
-- hours (16 trillion). Employee counts look normal; hours were fat-fingered.


-- ---------------------------------------------------------------------
-- Q4. Did the analytical filter rescue the mean?
-- ---------------------------------------------------------------------
SELECT
  COUNT(*)                               AS analyzable_rows,
  ROUND(MEDIAN(OPERATIONAL_INTENSITY),1) AS median_i,
  ROUND(AVG(OPERATIONAL_INTENSITY),1)    AS avg_i,
  ROUND(AVG(TCR_PER_200K),2)             AS avg_tcr,
  ROUND(AVG(DART_PER_200K),2)            AS avg_dart
FROM ITA_DB.CLEAN.ITA_300A_SUMMARY_CLEAN
WHERE TOTAL_HOURS_WORKED >= 10000
  AND ANNUAL_AVERAGE_EMPLOYEES >= 10
  AND OPERATIONAL_INTENSITY <= 6000;
-- Result: avg_i 866,320 -> 1,741 (now tracks median 1,811)
--         avg_tcr 24 -> 4.99 ; avg_dart 13 -> 3.26 (all sane now)


-- ---------------------------------------------------------------------
-- Q5. Exact-duplicate establishment-year pairs?
-- ---------------------------------------------------------------------
SELECT
  COUNT(*) AS rows,
  COUNT(DISTINCT ESTABLISHMENT_ID || '|' || YEAR_FILING_FOR) AS distinct_estab_years,
  SUM(CASE WHEN ESTABLISHMENT_ID IS NULL THEN 1 ELSE 0 END) AS estab_id_null
FROM ITA_DB.CLEAN.ITA_300A_SUMMARY_CLEAN;
-- Finding: 4,703 establishment-year pairs duplicated once (9,406 rows,
-- 0.33%). Spot-checks show identical copies (incl. blank created_timestamp)
-- -> true duplicates, deduped in 03_analysis_base.sql.


-- ---------------------------------------------------------------------
-- Q6. Sample size in the focus industries (does aerospace have enough?)
-- ---------------------------------------------------------------------
-- Manufacturing (31-33) vs other, after the analytical filter:
SELECT
  CASE WHEN LEFT(NAICS_CODE,2) IN ('31','32','33')
       THEN 'Manufacturing (31-33)' ELSE 'Other' END AS sector,
  COUNT(*) AS establishment_years,
  COUNT(DISTINCT ESTABLISHMENT_ID) AS distinct_establishments
FROM ITA_DB.ANALYTICS.ITA_SUMMARY_ANALYSIS_BASE
GROUP BY 1;
-- Manufacturing: ~219,775 distinct establishments (plenty).

-- Aerospace 3364 six-digit breakdown:
SELECT
  NAICS_CODE,
  ANY_VALUE(INDUSTRY_DESCRIPTION) AS industry,
  COUNT(*) AS establishment_years,
  COUNT(DISTINCT ESTABLISHMENT_ID) AS distinct_establishments
FROM ITA_DB.ANALYTICS.ITA_SUMMARY_ANALYSIS_BASE
WHERE LEFT(NAICS_CODE,4) = '3364'
GROUP BY NAICS_CODE
ORDER BY establishment_years DESC;
-- Aerospace 3364 total ~4,300 distinct establishments -> enough for
-- within-industry analysis. Space-vehicle (336414/415/419) is only ~527
-- distinct -> too thin to benchmark alone; treat as a highlighted subgroup.
