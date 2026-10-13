-- =============================================================
-- H-1B Sponsor Explorer - Step 2: Schema + staging table
-- Run in pgAdmin Query Tool while connected to database h1b_explorer
-- =============================================================

-- 2.1  A schema is just a folder inside the database to keep things tidy
CREATE SCHEMA IF NOT EXISTS h1b;

-- 2.2  STAGING table: every column is TEXT on purpose.
--      TEXT never rejects a value, so the import can't fail on a bad date
--      or a weird wage. We convert to proper types in the next step (SQL).
--      Column order MUST match the CSV produced by 01_preprocess_lca.py.
DROP TABLE IF EXISTS h1b.stg_lca;

CREATE TABLE h1b.stg_lca (
    case_number             TEXT,
    case_status             TEXT,
    received_date           TEXT,
    decision_date           TEXT,
    visa_class              TEXT,
    job_title               TEXT,
    soc_code                TEXT,
    soc_title               TEXT,
    full_time_position      TEXT,
    begin_date              TEXT,
    end_date                TEXT,
    total_worker_positions  TEXT,
    new_employment          TEXT,
    continued_employment    TEXT,
    change_employer         TEXT,
    employer_name           TEXT,
    employer_city           TEXT,
    employer_state          TEXT,
    naics_code              TEXT,
    worksite_city           TEXT,
    worksite_county         TEXT,
    worksite_state          TEXT,
    worksite_postal_code    TEXT,
    wage_rate_of_pay_from   TEXT,
    wage_rate_of_pay_to     TEXT,
    wage_unit_of_pay        TEXT,
    prevailing_wage         TEXT,
    pw_unit_of_pay          TEXT,
    pw_wage_level           TEXT,
    h_1b_dependent          TEXT,
    willful_violator        TEXT,
    fiscal_year             TEXT
);

-- 2.3  >>> Now import the CSV with pgAdmin's Import/Export dialog <<<
--      (right-click h1b.stg_lca > Import/Export Data...)

-- 2.4  CHECK THE IMPORT - run these one at a time after importing

-- Row count: should match "Saved N rows" from the Python output
SELECT COUNT(*) AS total_rows FROM h1b.stg_lca;

-- Peek at 10 rows
SELECT * FROM h1b.stg_lca LIMIT 10;

-- Status breakdown: should match the Python health check
SELECT case_status, COUNT(*) AS n
FROM h1b.stg_lca
GROUP BY case_status
ORDER BY n DESC;

-- Any duplicate case numbers? Should return zero rows
SELECT case_number, COUNT(*)
FROM h1b.stg_lca
GROUP BY case_number
HAVING COUNT(*) > 1;

-- Values that will NOT convert cleanly to numbers/dates later (should be 0)
SELECT
    SUM(CASE WHEN wage_rate_of_pay_from !~ '^[0-9]+(\.[0-9]+)?$' THEN 1 ELSE 0 END) AS bad_wage_from,
    SUM(CASE WHEN prevailing_wage       !~ '^[0-9]+(\.[0-9]+)?$' THEN 1 ELSE 0 END) AS bad_prevailing_wage,
    SUM(CASE WHEN received_date         !~ '^\d{4}-\d{2}-\d{2}$' THEN 1 ELSE 0 END) AS bad_received_date
FROM h1b.stg_lca;
