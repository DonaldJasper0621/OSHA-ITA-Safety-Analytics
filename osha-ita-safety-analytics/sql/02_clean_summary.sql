-- =====================================================================
-- 02_clean_summary.sql
-- CLEAN layer: ITA_DB.CLEAN.ITA_300A_SUMMARY_CLEAN
-- ---------------------------------------------------------------------
-- Purpose: take the three RAW 300A summary tables (split apart in RAW
-- because of schema drift across years) and UNION them into ONE typed,
-- standardized table with derived safety metrics. This is the single
-- source of truth for all downstream analysis.
--
-- Four jobs this view does:
--   1. UNION ALL three RAW tables onto one common column set (2016-2024).
--   2. Type-cast (TRY_TO_NUMBER) -- RAW is all-string on purpose so the
--      load never fails; numeric casting happens HERE. TRY_ returns NULL
--      instead of erroring, so the EDA step can count "how many failed
--      to cast" as a data-quality check.
--   3. Keep code columns (NAICS_CODE, ZIP_CODE, EIN) as STRING so leading
--      zeros are not eaten.
--   4. Compute derived metrics once (OPERATIONAL_INTENSITY, TCR, DART)
--      so every downstream view uses the same definitions.
--
-- Headline rate metrics follow OSHA standards:
--   TCR  (Total Case Rate / TRIR) = recordable cases * 200,000 / hours
--   DART (lost-time severity)      = (DAFW + DJTR)   * 200,000 / hours
--
-- NAICS normalization note: some RAW NAICS codes carry a ".00" suffix
-- (e.g. 442110.00) while others do not (332322). SPLIT_PART strips it so
-- industry grouping does not split "442110" and "442110.00" into two
-- industries. SPLIT_PART is safe on codes with no delimiter.
--
-- Built as a VIEW (not a table): cheap, always reflects latest RAW,
-- easy to revise during EDA. Materialize to a table only if/when the
-- analytics layer needs to run faster.
-- =====================================================================

CREATE OR REPLACE VIEW ITA_DB.CLEAN.ITA_300A_SUMMARY_CLEAN AS
WITH unioned AS (

    -- ===== ARM 1: 2016-2022 (OLD layout, no NAICS_YEAR) =====
    SELECT
        TRIM(ID)                                    AS ID,
        TRIM(ESTABLISHMENT_ID)                      AS ESTABLISHMENT_ID,
        TRIM(ESTABLISHMENT_NAME)                    AS ESTABLISHMENT_NAME,
        TRIM(COMPANY_NAME)                          AS COMPANY_NAME,
        TRIM(EIN)                                   AS EIN,
        TRIM(STREET_ADDRESS)                        AS STREET_ADDRESS,
        TRIM(CITY)                                  AS CITY,
        UPPER(TRIM(STATE))                          AS STATE,
        TRIM(ZIP_CODE)                              AS ZIP_CODE,
        SPLIT_PART(TRIM(NAICS_CODE), '.', 1)        AS NAICS_CODE,
        CAST(NULL AS NUMBER)                        AS NAICS_YEAR,
        TRIM(INDUSTRY_DESCRIPTION)                  AS INDUSTRY_DESCRIPTION,
        TRIM(ESTABLISHMENT_TYPE)                    AS ESTABLISHMENT_TYPE,
        TRIM(SIZE)                                  AS SIZE,
        TRY_TO_NUMBER(ANNUAL_AVERAGE_EMPLOYEES)     AS ANNUAL_AVERAGE_EMPLOYEES,
        TRY_TO_NUMBER(TOTAL_HOURS_WORKED)           AS TOTAL_HOURS_WORKED,
        TRIM(NO_INJURIES_ILLNESSES)                 AS NO_INJURIES_ILLNESSES,
        TRY_TO_NUMBER(TOTAL_DEATHS)                 AS TOTAL_DEATHS,
        TRY_TO_NUMBER(TOTAL_DAFW_CASES)             AS TOTAL_DAFW_CASES,
        TRY_TO_NUMBER(TOTAL_DJTR_CASES)             AS TOTAL_DJTR_CASES,
        TRY_TO_NUMBER(TOTAL_OTHER_CASES)            AS TOTAL_OTHER_CASES,
        TRY_TO_NUMBER(TOTAL_DAFW_DAYS)              AS TOTAL_DAFW_DAYS,
        TRY_TO_NUMBER(TOTAL_DJTR_DAYS)              AS TOTAL_DJTR_DAYS,
        TRY_TO_NUMBER(TOTAL_INJURIES)               AS TOTAL_INJURIES,
        TRY_TO_NUMBER(TOTAL_SKIN_DISORDERS)         AS TOTAL_SKIN_DISORDERS,
        TRY_TO_NUMBER(TOTAL_RESPIRATORY_CONDITIONS) AS TOTAL_RESPIRATORY_CONDITIONS,
        TRY_TO_NUMBER(TOTAL_POISONINGS)             AS TOTAL_POISONINGS,
        TRY_TO_NUMBER(TOTAL_HEARING_LOSS)           AS TOTAL_HEARING_LOSS,
        TRY_TO_NUMBER(TOTAL_OTHER_ILLNESSES)        AS TOTAL_OTHER_ILLNESSES,
        COALESCE(
            TRY_TO_TIMESTAMP_NTZ(CREATED_TIMESTAMP, 'MM/DD/YYYY HH24:MI'),
            TRY_TO_TIMESTAMP_NTZ(CREATED_TIMESTAMP, 'MM/DD/YYYY')
        )                                           AS CREATED_TIMESTAMP,
        TRIM(CHANGE_REASON)                         AS CHANGE_REASON,
        TRY_TO_NUMBER(YEAR_FILING_FOR)              AS YEAR_FILING_FOR,
        'SUMMARY_OLD_2016_2022'                     AS SOURCE_GROUP
    FROM ITA_DB.RAW.ITA_300A_SUMMARY_OLD_RAW

    UNION ALL

    -- ===== ARM 2: 2023 =====
    SELECT
        TRIM(ID), TRIM(ESTABLISHMENT_ID), TRIM(ESTABLISHMENT_NAME), TRIM(COMPANY_NAME),
        TRIM(EIN), TRIM(STREET_ADDRESS), TRIM(CITY), UPPER(TRIM(STATE)), TRIM(ZIP_CODE),
        SPLIT_PART(TRIM(NAICS_CODE), '.', 1), TRY_TO_NUMBER(NAICS_YEAR), TRIM(INDUSTRY_DESCRIPTION),
        TRIM(ESTABLISHMENT_TYPE), TRIM(SIZE),
        TRY_TO_NUMBER(ANNUAL_AVERAGE_EMPLOYEES), TRY_TO_NUMBER(TOTAL_HOURS_WORKED),
        TRIM(NO_INJURIES_ILLNESSES),
        TRY_TO_NUMBER(TOTAL_DEATHS), TRY_TO_NUMBER(TOTAL_DAFW_CASES), TRY_TO_NUMBER(TOTAL_DJTR_CASES),
        TRY_TO_NUMBER(TOTAL_OTHER_CASES), TRY_TO_NUMBER(TOTAL_DAFW_DAYS), TRY_TO_NUMBER(TOTAL_DJTR_DAYS),
        TRY_TO_NUMBER(TOTAL_INJURIES), TRY_TO_NUMBER(TOTAL_SKIN_DISORDERS),
        TRY_TO_NUMBER(TOTAL_RESPIRATORY_CONDITIONS), TRY_TO_NUMBER(TOTAL_POISONINGS),
        TRY_TO_NUMBER(TOTAL_HEARING_LOSS), TRY_TO_NUMBER(TOTAL_OTHER_ILLNESSES),
        COALESCE(
            TRY_TO_TIMESTAMP_NTZ(CREATED_TIMESTAMP, 'MM/DD/YYYY HH24:MI'),
            TRY_TO_TIMESTAMP_NTZ(CREATED_TIMESTAMP, 'MM/DD/YYYY')
        ),
        TRIM(CHANGE_REASON), TRY_TO_NUMBER(YEAR_FILING_FOR), 'SUMMARY_2023'
    FROM ITA_DB.RAW.ITA_300A_SUMMARY_2023_RAW

    UNION ALL

    -- ===== ARM 3: 2024 =====
    -- NOTE: in the 2024 RAW file, CREATED_TIMESTAMP / CHANGE_REASON sit in
    -- swapped source positions. They were loaded under the correct column
    -- NAMES, so selecting by name (as below) already aligns them. If your
    -- build loaded them under swapped names, swap these two columns here.
    SELECT
        TRIM(ID), TRIM(ESTABLISHMENT_ID), TRIM(ESTABLISHMENT_NAME), TRIM(COMPANY_NAME),
        TRIM(EIN), TRIM(STREET_ADDRESS), TRIM(CITY), UPPER(TRIM(STATE)), TRIM(ZIP_CODE),
        SPLIT_PART(TRIM(NAICS_CODE), '.', 1), TRY_TO_NUMBER(NAICS_YEAR), TRIM(INDUSTRY_DESCRIPTION),
        TRIM(ESTABLISHMENT_TYPE), TRIM(SIZE),
        TRY_TO_NUMBER(ANNUAL_AVERAGE_EMPLOYEES), TRY_TO_NUMBER(TOTAL_HOURS_WORKED),
        TRIM(NO_INJURIES_ILLNESSES),
        TRY_TO_NUMBER(TOTAL_DEATHS), TRY_TO_NUMBER(TOTAL_DAFW_CASES), TRY_TO_NUMBER(TOTAL_DJTR_CASES),
        TRY_TO_NUMBER(TOTAL_OTHER_CASES), TRY_TO_NUMBER(TOTAL_DAFW_DAYS), TRY_TO_NUMBER(TOTAL_DJTR_DAYS),
        TRY_TO_NUMBER(TOTAL_INJURIES), TRY_TO_NUMBER(TOTAL_SKIN_DISORDERS),
        TRY_TO_NUMBER(TOTAL_RESPIRATORY_CONDITIONS), TRY_TO_NUMBER(TOTAL_POISONINGS),
        TRY_TO_NUMBER(TOTAL_HEARING_LOSS), TRY_TO_NUMBER(TOTAL_OTHER_ILLNESSES),
        COALESCE(
            TRY_TO_TIMESTAMP_NTZ(CREATED_TIMESTAMP, 'MM/DD/YYYY HH24:MI'),
            TRY_TO_TIMESTAMP_NTZ(CREATED_TIMESTAMP, 'MM/DD/YYYY')
        ),
        TRIM(CHANGE_REASON), TRY_TO_NUMBER(YEAR_FILING_FOR), 'SUMMARY_2024'
    FROM ITA_DB.RAW.ITA_300A_SUMMARY_2024_RAW
)

SELECT
    u.*,
    TOTAL_HOURS_WORKED / NULLIF(ANNUAL_AVERAGE_EMPLOYEES, 0)                  AS OPERATIONAL_INTENSITY,
    (TOTAL_DEATHS + TOTAL_DAFW_CASES + TOTAL_DJTR_CASES + TOTAL_OTHER_CASES)  AS TOTAL_RECORDABLE_CASES,
    (TOTAL_DEATHS + TOTAL_DAFW_CASES + TOTAL_DJTR_CASES + TOTAL_OTHER_CASES)
        / NULLIF(TOTAL_HOURS_WORKED, 0) * 200000                             AS TCR_PER_200K,
    (TOTAL_DAFW_CASES + TOTAL_DJTR_CASES)
        / NULLIF(TOTAL_HOURS_WORKED, 0) * 200000                             AS DART_PER_200K,
    TOTAL_DAFW_CASES / NULLIF(TOTAL_HOURS_WORKED, 0) * 200000                AS DAFW_RATE_PER_200K,
    TOTAL_DJTR_CASES / NULLIF(TOTAL_HOURS_WORKED, 0) * 200000                AS DJTR_RATE_PER_200K,
    TOTAL_INJURIES   / NULLIF(TOTAL_HOURS_WORKED, 0) * 200000                AS INJURY_ONLY_RATE_PER_200K
FROM unioned u;


-- ---------------------------------------------------------------------
-- Validation 1: row counts per source group (expect total 2,805,762)
-- ---------------------------------------------------------------------
-- SELECT SOURCE_GROUP, COUNT(*) AS row_count
-- FROM ITA_DB.CLEAN.ITA_300A_SUMMARY_CLEAN
-- GROUP BY SOURCE_GROUP ORDER BY SOURCE_GROUP;
-- Expected: SUMMARY_OLD_2016_2022 = 2,012,910
--           SUMMARY_2023          =   394,232
--           SUMMARY_2024          =   398,620

-- ---------------------------------------------------------------------
-- Validation 2: did casting succeed + are metrics sane?
-- ---------------------------------------------------------------------
-- SELECT
--   COUNT(*)                             AS total_rows,
--   COUNT(TOTAL_HOURS_WORKED)            AS hours_parsed,
--   COUNT(*) - COUNT(TOTAL_HOURS_WORKED) AS hours_null,
--   ROUND(AVG(OPERATIONAL_INTENSITY), 1) AS avg_intensity,
--   ROUND(AVG(TCR_PER_200K), 2)          AS avg_tcr,
--   ROUND(AVG(DART_PER_200K), 2)         AS avg_dart
-- FROM ITA_DB.CLEAN.ITA_300A_SUMMARY_CLEAN;
-- NOTE: on the FULL clean table the raw AVG_INTENSITY comes out ~866,320
-- because a handful of data-entry errors in TOTAL_HOURS_WORKED (values in
-- the billions/trillions) wreck the mean. The median is ~1,811 (sane).
-- See docs/eda_findings.md. The analysis base view (03) filters these out.
