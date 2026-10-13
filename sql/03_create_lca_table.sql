-- =============================================================
-- H-1B Sponsor Explorer - Step 3: Build the clean, typed table
-- Run in pgAdmin Query Tool while connected to database h1b_explorer
--
-- What this does:
--   * Copies every row from h1b.stg_lca (all TEXT) into h1b.lca
--     with proper data types (DATE, NUMERIC, INTEGER, BOOLEAN)
--   * Converts every wage to a YEARLY amount (hourly x 2080, etc.)
--   * Adds helper columns for the dashboard: fiscal quarter,
--     wage-vs-prevailing ratio, certified flag, wage outlier flag
--
-- HOW TO RUN: highlight everything from "DROP TABLE" down to the
-- last "CREATE INDEX" line and press F5. Takes about 1-3 minutes.
-- =============================================================

DROP TABLE IF EXISTS h1b.lca;

CREATE TABLE h1b.lca AS
WITH typed AS (
    SELECT
        -- ---------- Case info ----------
        case_number,
        case_status,
        (case_status = 'Certified')                  AS is_certified,
        received_date::DATE                          AS received_date,
        decision_date::DATE                          AS decision_date,
        fiscal_year::INTEGER                         AS fiscal_year,

        -- ---------- Job info ----------
        UPPER(TRIM(job_title))                       AS job_title,
        soc_code,
        UPPER(TRIM(soc_title))                       AS soc_title,
        (full_time_position = 'Y')                   AS is_full_time,
        begin_date::DATE                             AS begin_date,
        end_date::DATE                               AS end_date,
        total_worker_positions::INTEGER              AS total_workers,
        new_employment::INTEGER                      AS new_employment,
        continued_employment::INTEGER                AS continued_employment,
        change_employer::INTEGER                     AS change_employer,

        -- ---------- Employer info ----------
        employer_name,
        employer_city,
        employer_state,
        naics_code,
        LEFT(naics_code, 2)                          AS naics_2digit,
        h_1b_dependent,
        willful_violator,

        -- ---------- Worksite ----------
        worksite_city,
        worksite_county,
        worksite_state,
        worksite_postal_code,

        -- ---------- Wages (raw) ----------
        wage_rate_of_pay_from::NUMERIC               AS wage_from,
        wage_rate_of_pay_to::NUMERIC                 AS wage_to,
        wage_unit_of_pay                             AS wage_unit,
        prevailing_wage::NUMERIC                     AS prevailing_wage,
        pw_unit_of_pay                               AS pw_unit,
        pw_wage_level,

        -- How many pay periods in a year, for each unit
        CASE wage_unit_of_pay
            WHEN 'Year'      THEN 1
            WHEN 'Month'     THEN 12
            WHEN 'Bi-Weekly' THEN 26
            WHEN 'Week'      THEN 52
            WHEN 'Hour'      THEN 2080      -- 40 hrs x 52 weeks
        END                                          AS wage_multiplier,
        CASE pw_unit_of_pay
            WHEN 'Year'      THEN 1
            WHEN 'Month'     THEN 12
            WHEN 'Bi-Weekly' THEN 26
            WHEN 'Week'      THEN 52
            WHEN 'Hour'      THEN 2080
        END                                          AS pw_multiplier
    FROM h1b.stg_lca
)
SELECT
    t.*,

    -- Fiscal quarter label, e.g. 'FY2025 Q1'  (Oct-Dec = Q1)
    'FY' || fiscal_year || ' Q' ||
        CASE
            WHEN EXTRACT(MONTH FROM decision_date) IN (10, 11, 12) THEN 1
            WHEN EXTRACT(MONTH FROM decision_date) IN (1, 2, 3)    THEN 2
            WHEN EXTRACT(MONTH FROM decision_date) IN (4, 5, 6)    THEN 3
            ELSE 4
        END                                          AS fy_quarter,

    -- TRUE when the unit is wrong: e.g. "$85,000 per Week" is really $85,000
    -- per YEAR. Any amount of $30,000+ is treated as already yearly.
    (wage_unit <> 'Year' AND wage_from >= 30000)     AS wage_unit_corrected,

    -- Yearly wages (rounded to whole dollars)
    ROUND(CASE WHEN wage_from >= 30000 THEN wage_from
               ELSE wage_from * wage_multiplier END)          AS annual_wage,
    ROUND(CASE WHEN prevailing_wage >= 30000 THEN prevailing_wage
               ELSE prevailing_wage * pw_multiplier END)     AS annual_prevailing_wage
FROM typed t;

-- Add the ratio + outlier flag (easier to read as a second step)
ALTER TABLE h1b.lca
    ADD COLUMN wage_to_pw_ratio NUMERIC,
    ADD COLUMN is_wage_outlier  BOOLEAN;

UPDATE h1b.lca
SET
    -- Offered wage / required minimum wage.  1.25 = pays 25% above minimum
    wage_to_pw_ratio = ROUND(annual_wage / NULLIF(annual_prevailing_wage, 0), 2),
    -- Flag unrealistic yearly wages (typos, part-time hourly, etc.)
    -- so the dashboard can exclude them from averages
    is_wage_outlier  = (annual_wage < 30000 OR annual_wage > 1000000);

-- Primary key = one row per case, and makes lookups fast
ALTER TABLE h1b.lca ADD PRIMARY KEY (case_number);

-- Indexes = faster filtering in Power BI and later SQL steps
CREATE INDEX idx_lca_employer ON h1b.lca (employer_name);
CREATE INDEX idx_lca_naics    ON h1b.lca (naics_code);
CREATE INDEX idx_lca_state    ON h1b.lca (worksite_state);


-- =============================================================
-- CHECKS - run these one at a time (highlight one, press F5)
-- =============================================================

-- 1) Row count: must equal the staging table (1,118,768)
SELECT
    (SELECT COUNT(*) FROM h1b.stg_lca) AS staging_rows,
    (SELECT COUNT(*) FROM h1b.lca)     AS clean_rows;

-- 2) Rows per fiscal quarter: expect 8 rows, FY2024 Q1 ... FY2025 Q4
SELECT fy_quarter, COUNT(*) AS lcas
FROM h1b.lca
GROUP BY fy_quarter
ORDER BY fy_quarter;

-- 3) Yearly wage sanity check by wage unit
--    (median should be roughly $80k-$150k for every unit; outliers small)
SELECT
    wage_unit,
    COUNT(*)                                                   AS lcas,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY annual_wage)   AS median_annual_wage,
    SUM(CASE WHEN is_wage_outlier THEN 1 ELSE 0 END)           AS outliers
FROM h1b.lca
GROUP BY wage_unit
ORDER BY lcas DESC;

-- 4) Median wage and ratio by DOL wage level (should rise from I to IV)
SELECT
    pw_wage_level,
    COUNT(*)                                                        AS lcas,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY annual_wage)        AS median_annual_wage,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY wage_to_pw_ratio)   AS median_wage_to_pw_ratio
FROM h1b.lca
WHERE is_certified AND NOT is_wage_outlier
GROUP BY pw_wage_level
ORDER BY pw_wage_level;
