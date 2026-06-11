-- =====================================================================
-- 00_setup.sql
-- Snowflake environment: database, schemas, stage, file formats.
-- ---------------------------------------------------------------------
-- NOTE: This file is a faithful reconstruction of the setup used. Adjust
-- warehouse name / sizes to match your account. The three-layer design is
-- the medallion pattern: RAW (untouched strings) -> CLEAN (typed,
-- standardized, derived metrics) -> ANALYTICS (deduped, filtered, ready).
-- =====================================================================

-- --- Database + schemas ----------------------------------------------
CREATE DATABASE IF NOT EXISTS ITA_DB;

CREATE SCHEMA IF NOT EXISTS ITA_DB.RAW;        -- landing zone, all STRING
CREATE SCHEMA IF NOT EXISTS ITA_DB.CLEAN;      -- typed, standardized
CREATE SCHEMA IF NOT EXISTS ITA_DB.ANALYTICS;  -- analysis-ready views

-- --- Internal stage for the OSHA bulk CSV files ----------------------
CREATE STAGE IF NOT EXISTS ITA_DB.RAW.ITA_STAGE;

-- --- File formats ----------------------------------------------------
-- Plain CSV with header, used for the uncompressed summary files.
CREATE OR REPLACE FILE FORMAT ITA_DB.RAW.CSV_AUTO_SKIP_HEADER_FORMAT
  TYPE = CSV
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  SKIP_HEADER = 1
  FIELD_DELIMITER = ','
  NULL_IF = ('', 'NULL', 'null')
  EMPTY_FIELD_AS_NULL = TRUE
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;   -- a few malformed rows skipped

-- Same, but for the gzip-compressed case-detail file (495MB -> 82MB).
-- The large case-detail CSV was latin1-encoded and gzip-compressed
-- locally before upload to keep the load fast and avoid encoding errors.
CREATE OR REPLACE FILE FORMAT ITA_DB.RAW.CSV_GZIP_FORMAT
  TYPE = CSV
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  SKIP_HEADER = 1
  FIELD_DELIMITER = ','
  COMPRESSION = GZIP
  ENCODING = 'iso-8859-1'                    -- latin1 fix
  NULL_IF = ('', 'NULL', 'null')
  EMPTY_FIELD_AS_NULL = TRUE
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

-- Upload files to the stage from SnowSQL / the UI, e.g.:
--   PUT file:///path/to/ITA_Data_2023.csv          @ITA_DB.RAW.ITA_STAGE;
--   PUT file:///path/to/case_detail_2024.csv.gz    @ITA_DB.RAW.ITA_STAGE;
