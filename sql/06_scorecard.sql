-- =====================================================================
-- 06_scorecard.sql
-- Within-industry peer-benchmarking scorecard.
-- ---------------------------------------------------------------------
-- Business framing: a company cannot change which industry it is in
-- (uncontrollable risk), but it CAN fix the plants that are worse than
-- their own industry peers (controllable risk). This scorecard separates
-- the two and surfaces establishments that are PERSISTENTLY above their
-- 6-digit-NAICS peer median.
--
-- Data-quality guardrails (learned from a first naive pass that surfaced
-- garbage like TCR 1606 from understated-hours / overstated-case errors):
--   TCR_PER_200K <= 40                  -> physical ceiling, catches both
--                                          error directions.
--   OPERATIONAL_INTENSITY BETWEEN 800 AND 4500 -> screens understated-hours
--                                          rows (e.g. intensity 24).
--   appears >= 3 years AND above peer median in >= 75% of years -> a single
--                                          bad year is noise; persistence
--                                          is a real, controllable problem.
-- Replication to another industry = change ONE filter (the NAICS prefix).
-- =====================================================================


-- ---------------------------------------------------------------------
-- Aerospace 3364 scorecard (anchor industry, serves SpaceX context).
-- Result: results/aerospace_scorecard.csv
-- ---------------------------------------------------------------------
WITH aero AS (
  SELECT *
  FROM ITA_DB.ANALYTICS.ITA_SUMMARY_ANALYSIS_BASE
  WHERE LEFT(NAICS_CODE,4) = '3364'
    AND ESTABLISHMENT_ID IS NOT NULL AND TRIM(ESTABLISHMENT_ID) <> ''
    AND OPERATIONAL_INTENSITY BETWEEN 800 AND 4500
    AND TCR_PER_200K <= 40
),
bench AS (   -- per 6-digit NAICS, per year peer median (controls hazard)
  SELECT NAICS_CODE, YEAR_FILING_FOR, MEDIAN(TCR_PER_200K) AS ind_median_tcr
  FROM aero GROUP BY 1,2
),
flagged AS (
  SELECT a.ESTABLISHMENT_ID, a.COMPANY_NAME, a.ESTABLISHMENT_NAME, a.STATE,
         a.NAICS_CODE, a.INDUSTRY_DESCRIPTION, a.ANNUAL_AVERAGE_EMPLOYEES,
         a.TCR_PER_200K, b.ind_median_tcr,
         CASE WHEN a.TCR_PER_200K > b.ind_median_tcr THEN 1 ELSE 0 END AS above_peer
  FROM aero a
  JOIN bench b ON a.NAICS_CODE=b.NAICS_CODE AND a.YEAR_FILING_FOR=b.YEAR_FILING_FOR
)
SELECT
  ESTABLISHMENT_ID,
  ANY_VALUE(COMPANY_NAME)              AS company,
  ANY_VALUE(ESTABLISHMENT_NAME)        AS establishment,
  ANY_VALUE(STATE)                     AS state,
  ANY_VALUE(NAICS_CODE)                AS naics,
  ANY_VALUE(INDUSTRY_DESCRIPTION)      AS industry,
  COUNT(*)                             AS years_reported,
  SUM(above_peer)                      AS years_above_peer,
  ROUND(AVG(TCR_PER_200K),2)           AS avg_tcr,
  ROUND(AVG(ind_median_tcr),2)         AS avg_peer_median,
  ROUND(AVG(ANNUAL_AVERAGE_EMPLOYEES)) AS avg_employees
FROM flagged
GROUP BY ESTABLISHMENT_ID
HAVING COUNT(*) >= 3                       -- appears at least 3 years
   AND SUM(above_peer) >= COUNT(*) * 0.75  -- above peer median in 75%+ of years
ORDER BY avg_tcr DESC
LIMIT 25;


-- ---------------------------------------------------------------------
-- Replication to automobile manufacturing: change ONLY the NAICS filter.
--   WHERE LEFT(NAICS_CODE,4) IN ('3361','3362','3363')   -- vehicles/body/parts
-- Everything else (bench, flagged, persistence logic) is identical.
-- ---------------------------------------------------------------------


-- =====================================================================
-- SpaceX named case study (space-vehicle mfg).
-- ---------------------------------------------------------------------
-- The space-vehicle subsectors (336414/415/419) are thin and low-injury
-- (median TCR 0.4-0.6), so within-subsector benchmarking is statistically
-- weak. The stronger story is WITHIN-SpaceX site comparison.
--
-- Data hygiene: real SpaceX = COMPANY_NAME = 'Space Exploration Technologies'.
-- Contractors (ABM, US Tool Group, Performance Contractors, Austin
-- Commercial, PCAM, Mosaic) carry "SPACEX" in the establishment name but
-- are NOT SpaceX -- match on company name, not establishment name.
-- Result: results/spacex_sites.csv
-- ---------------------------------------------------------------------
SELECT
  ESTABLISHMENT_ID,
  ANY_VALUE(ESTABLISHMENT_NAME) AS site,
  ANY_VALUE(STATE) AS state,
  COUNT(*) AS years,
  ROUND(AVG(ANNUAL_AVERAGE_EMPLOYEES)) AS avg_emp,
  ROUND(AVG(TCR_PER_200K),2) AS avg_tcr,
  ROUND(AVG(DART_PER_200K),2) AS avg_dart
FROM ITA_DB.CLEAN.ITA_300A_SUMMARY_CLEAN
WHERE COMPANY_NAME = 'Space Exploration Technologies'
  AND NAICS_CODE = '336414'
GROUP BY ESTABLISHMENT_ID
ORDER BY avg_tcr DESC;
-- Finding: Brownsville/Starbase TX (rapidly growing, TCR 4.2-5.8) is the
-- highest-rate site, well above the 0.40 subsector median; Hawthorne CA
-- (mature flagship, 6,400-7,500 emp, TCR 1.2-1.8) is relatively safe;
-- McGregor TX (engine test) 2.4-3.8. Both run similar intensity
-- (~2,200-2,500) -> the gap is NOT intensity -- consistent with the macro
-- finding (workforce newness / work type, not overtime).
