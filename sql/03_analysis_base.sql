-- =====================================================================
-- 03_analysis_base.sql
-- ANALYTICS layer: ITA_DB.ANALYTICS.ITA_SUMMARY_ANALYSIS_BASE
-- ---------------------------------------------------------------------
-- The single analysis-ready foundation. CLEAN stays faithful to source
-- (all rows kept). This view applies the analytical population filter
-- AND deduplication in one documented place, so every downstream
-- analysis runs on the same "one establishment-year, deduped, size-sane"
-- population.
--
-- Filter rationale (see docs/methodology.md and docs/eda_findings.md):
--   TOTAL_HOURS_WORKED   >= 10000  -> denominator big enough that rates
--                                     are stable (a tiny shop with 1
--                                     recordable case otherwise hits a
--                                     TCR in the hundreds).
--   ANNUAL_AVERAGE_EMPLOYEES >= 10 -> a genuinely operating establishment.
--   OPERATIONAL_INTENSITY <= 6000  -> cut physically-impossible values
--                                     caused by hours-field data entry
--                                     errors. p99 intensity is 4,128, so
--                                     real "running hot" plants survive.
--   No intensity LOWER bound here on purpose: low-intensity plants are
--   the left end of the curve and must be kept to test the relationship.
--
-- Effect of the filter: 2,805,762 -> ~2,435,253 analyzable rows
-- (~13% excluded). Most of that 13% is NOT garbage -- only ~20k rows are
-- true garbage (intensity > 6000); the rest (~350k) are screened out by
-- the size floors. Honest framing: "analysis focuses on establishments
-- large enough for stable rates", not "threw away bad data".
--
-- Dedup rationale: 4,703 establishment-year pairs appear as exact
-- duplicates (mostly in OLD, identical copies incl. blank timestamps).
-- ROW_NUMBER keeps one per establishment-year.
--   * PARTITION BY COALESCE(NULLIF(establishment_id,''), ID): if an old
--     record has a blank establishment_id, fall back to ID so distinct
--     establishments with missing IDs are NOT collapsed into one.
--   * WHERE filters BEFORE dedup -- safe because duplicates are identical
--     copies, so both rows pass or fail the filter together.
-- =====================================================================

CREATE OR REPLACE VIEW ITA_DB.ANALYTICS.ITA_SUMMARY_ANALYSIS_BASE AS
SELECT *
FROM ITA_DB.CLEAN.ITA_300A_SUMMARY_CLEAN
WHERE TOTAL_HOURS_WORKED >= 10000
  AND ANNUAL_AVERAGE_EMPLOYEES >= 10
  AND OPERATIONAL_INTENSITY <= 6000
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY COALESCE(NULLIF(TRIM(ESTABLISHMENT_ID), ''), ID), YEAR_FILING_FOR
    ORDER BY CREATED_TIMESTAMP DESC NULLS LAST, ID DESC
) = 1;


-- ---------------------------------------------------------------------
-- Validation: dedup worked (remaining_dups must be 0)
-- ---------------------------------------------------------------------
-- SELECT
--   COUNT(*) AS base_rows,
--   COUNT(*) - COUNT(DISTINCT
--     COALESCE(NULLIF(TRIM(ESTABLISHMENT_ID),''), ID) || '|' || YEAR_FILING_FOR
--   ) AS remaining_dups
-- FROM ITA_DB.ANALYTICS.ITA_SUMMARY_ANALYSIS_BASE;
-- Result: base_rows = 2,435,253 ; remaining_dups = 0
