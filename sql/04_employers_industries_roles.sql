-- =============================================================
-- H-1B Sponsor Explorer - Step 4: Employers, industries, roles
-- Run in pgAdmin Query Tool while connected to database h1b_explorer
--
-- Adds 5 columns to h1b.lca:
--   employer_clean   - name without LLC/INC/punctuation
--   employer_group   - one name per company (e.g. all Amazon entities = "Amazon")
--   industry         - one industry per company (your 5 targets + 4 others)
--   role_family      - Data Analyst / Business Analyst / BI / Data Scientist ...
--   is_target_role   - TRUE for Data Analyst, Business Analyst, BI / Reporting
-- Then creates the view h1b.vw_lca_dashboard for Power BI.
--
-- HOW TO RUN: run each PART separately (highlight PART, press F5),
-- in order: PART 1 -> PART 2 -> ... -> PART 6. Then run the CHECKS.
-- =============================================================


-- =============================================================
-- PART 1 - Clean employer names   (about 1 minute)
-- "JPMORGAN CHASE & CO." -> "JPMORGAN CHASE"
-- =============================================================
ALTER TABLE h1b.lca
    ADD COLUMN IF NOT EXISTS employer_clean TEXT,
    ADD COLUMN IF NOT EXISTS employer_group TEXT,
    ADD COLUMN IF NOT EXISTS industry       TEXT,
    ADD COLUMN IF NOT EXISTS role_family    TEXT,
    ADD COLUMN IF NOT EXISTS is_target_role BOOLEAN;

UPDATE h1b.lca
SET employer_clean =
    TRIM(BOTH ' &-' FROM
        REGEXP_REPLACE(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(UPPER(employer_name), '\s+D/?B/?A\s.*$', ''),    -- drop "D/B/A ..." part
                '[.,''"()]', '', 'g'),                                              -- drop punctuation
            '\m(THE|LLC|INC|CORP|CORPORATION|LIMITED|LTD|LLP|LP|CO|COMPANY|NA|PLLC|PC)\M', '', 'g'),
        '\s+', ' ', 'g')
    );


-- =============================================================
-- PART 2 - Employer lookup table (your hand-built mapping)
-- pattern uses LIKE:  'AMAZON%' = any name starting with AMAZON
-- To add a company later: add a line here, then re-run PART 2-6.
-- =============================================================
DROP TABLE IF EXISTS h1b.employer_lookup;

CREATE TABLE h1b.employer_lookup (
    pattern         TEXT PRIMARY KEY,
    employer_group  TEXT NOT NULL,
    industry        TEXT NOT NULL
);

INSERT INTO h1b.employer_lookup (pattern, employer_group, industry) VALUES
-- ---------- IT Services & Consulting ----------
('COGNIZANT%',                'Cognizant',                'IT Services & Consulting'),
('TATA CONSULTANCY%',         'TCS',                      'IT Services & Consulting'),
('INFOSYS%',                  'Infosys',                  'IT Services & Consulting'),
('HCL %',                     'HCLTech',                  'IT Services & Consulting'),
('WIPRO%',                    'Wipro',                    'IT Services & Consulting'),
('ACCENTURE%',                'Accenture',                'IT Services & Consulting'),
('CAPGEMINI%',                'Capgemini',                'IT Services & Consulting'),
('DELOITTE%',                 'Deloitte',                 'IT Services & Consulting'),
('ERNST & YOUNG%',            'EY',                       'IT Services & Consulting'),
('PRICEWATERHOUSECOOPERS%',   'PwC',                      'IT Services & Consulting'),
('KPMG%',                     'KPMG',                     'IT Services & Consulting'),
('IBM%',                      'IBM',                      'IT Services & Consulting'),
('INTERNATIONAL BUSINESS MACHINES%', 'IBM',               'IT Services & Consulting'),
('LTIMINDTREE%',              'LTIMindtree',              'IT Services & Consulting'),
('TECH MAHINDRA%',            'Tech Mahindra',            'IT Services & Consulting'),
('MPHASIS%',                  'Mphasis',                  'IT Services & Consulting'),
('COMPUNNEL%',                'Compunnel',                'IT Services & Consulting'),
('VIRTUSA%',                  'Virtusa',                  'IT Services & Consulting'),
('UST GLOBAL%',               'UST',                      'IT Services & Consulting'),
('CGI TECHNOLOGIES%',         'CGI',                      'IT Services & Consulting'),
('NTT DATA%',                 'NTT Data',                 'IT Services & Consulting'),
('HEXAWARE%',                 'Hexaware',                 'IT Services & Consulting'),
('COFORGE%',                  'Coforge',                  'IT Services & Consulting'),
('RANDSTAD%',                 'Randstad',                 'IT Services & Consulting'),
('KFORCE%',                   'Kforce',                   'IT Services & Consulting'),
('L&T TECHNOLOGY%',           'L&T Technology Services',  'IT Services & Consulting'),
('ATOS SYNTEL%',              'Atos Syntel',              'IT Services & Consulting'),
('BOSTON CONSULTING%',        'Boston Consulting Group',  'IT Services & Consulting'),
('MCKINSEY%',                 'McKinsey',                 'IT Services & Consulting'),
('GENPACT%',                  'Genpact',                  'IT Services & Consulting'),
-- ---------- Technology ----------
('MICROSOFT%',                'Microsoft',                'Technology'),
('GOOGLE%',                   'Google',                   'Technology'),
('META PLATFORMS%',           'Meta',                     'Technology'),
('FACEBOOK%',                 'Meta',                     'Technology'),
('APPLE',                     'Apple',                    'Technology'),
('NVIDIA%',                   'NVIDIA',                   'Technology'),
('INTEL',                     'Intel',                    'Technology'),
('CISCO%',                    'Cisco',                    'Technology'),
('QUALCOMM%',                 'Qualcomm',                 'Technology'),
('ORACLE%',                   'Oracle',                   'Technology'),
('SALESFORCE%',               'Salesforce',               'Technology'),
('ADOBE%',                    'Adobe',                    'Technology'),
('INTUIT%',                   'Intuit',                   'Technology'),
('SERVICENOW%',               'ServiceNow',               'Technology'),
('WORKDAY%',                  'Workday',                  'Technology'),
('SNOWFLAKE%',                'Snowflake',                'Technology'),
('LINKEDIN%',                 'LinkedIn',                 'Technology'),
('UBER TECHNOLOGIES%',        'Uber',                     'Technology'),
('DOORDASH%',                 'DoorDash',                 'Technology'),
('BYTEDANCE%',                'ByteDance / TikTok',       'Technology'),
('TIKTOK%',                   'ByteDance / TikTok',       'Technology'),
('NETFLIX%',                  'Netflix',                  'Technology'),
('ADVANCED MICRO DEVICES%',   'AMD',                      'Technology'),
('MICRON TECHNOLOGY%',        'Micron',                   'Technology'),
('PALO ALTO NETWORKS%',       'Palo Alto Networks',       'Technology'),
('WESTERN DIGITAL%',          'Western Digital',          'Technology'),
('BLOOMBERG%',                'Bloomberg',                'Technology'),
-- ---------- Financial Services & Banking ----------
('JPMORGAN%',                 'JPMorgan Chase',           'Financial Services & Banking'),
('JP MORGAN%',                'JPMorgan Chase',           'Financial Services & Banking'),
('GOLDMAN SACHS%',            'Goldman Sachs',            'Financial Services & Banking'),
('MORGAN STANLEY%',           'Morgan Stanley',           'Financial Services & Banking'),
('CITIBANK%',                 'Citi',                     'Financial Services & Banking'),
('CITIGROUP%',                'Citi',                     'Financial Services & Banking'),
('CITICORP%',                 'Citi',                     'Financial Services & Banking'),
('BANK OF AMERICA%',          'Bank of America',          'Financial Services & Banking'),
('WELLS FARGO%',              'Wells Fargo',              'Financial Services & Banking'),
('CAPITAL ONE%',              'Capital One',              'Financial Services & Banking'),
('AMERICAN EXPRESS%',         'American Express',         'Financial Services & Banking'),
('FIDELITY TECHNOLOGY%',      'Fidelity Investments',     'Financial Services & Banking'),
('FMR%',                      'Fidelity Investments',     'Financial Services & Banking'),
('VISA %',                    'Visa',                     'Financial Services & Banking'),
('VISA',                      'Visa',                     'Financial Services & Banking'),
('MASTERCARD%',               'Mastercard',               'Financial Services & Banking'),
('PAYPAL%',                   'PayPal',                   'Financial Services & Banking'),
('FISERV%',                   'Fiserv',                   'Financial Services & Banking'),
('FIS %',                     'FIS',                      'Financial Services & Banking'),
('CHARLES SCHWAB%',           'Charles Schwab',           'Financial Services & Banking'),
('BLACKROCK%',                'BlackRock',                'Financial Services & Banking'),
('STATE STREET%',             'State Street',             'Financial Services & Banking'),
('UBS %',                     'UBS',                      'Financial Services & Banking'),
('BARCLAYS%',                 'Barclays',                 'Financial Services & Banking'),
('US BANK%',                  'U.S. Bank',                'Financial Services & Banking'),
('DFS CORPORATE%',            'Discover',                 'Financial Services & Banking'),
('DISCOVER%',                 'Discover',                 'Financial Services & Banking'),
-- ---------- Healthcare ----------
('OPTUM%',                    'UnitedHealth Group',       'Healthcare'),
('UNITEDHEALTH%',             'UnitedHealth Group',       'Healthcare'),
('ELEVANCE%',                 'Elevance Health',          'Healthcare'),
('AETNA%',                    'CVS Health',               'Healthcare'),
('CVS%',                      'CVS Health',               'Healthcare'),
('CIGNA%',                    'Cigna',                    'Healthcare'),
('HUMANA%',                   'Humana',                   'Healthcare'),
('MAYO CLINIC%',              'Mayo Clinic',              'Healthcare'),
('KAISER%',                   'Kaiser Permanente',        'Healthcare'),
('ELI LILLY%',                'Eli Lilly',                'Healthcare'),
('PFIZER%',                   'Pfizer',                   'Healthcare'),
('JOHNSON & JOHNSON%',        'Johnson & Johnson',        'Healthcare'),
('MERCK%',                    'Merck',                    'Healthcare'),
('AMGEN%',                    'Amgen',                    'Healthcare'),
('UNIVERSITY OF TEXAS MD ANDERSON%', 'MD Anderson',       'Healthcare'),
('CITIUSTECH%',               'CitiusTech',               'Healthcare'),
-- ---------- Retail & E-commerce ----------
('AMAZON%',                   'Amazon',                   'Retail & E-commerce'),
('WAL-MART%',                 'Walmart',                  'Retail & E-commerce'),
('WALMART%',                  'Walmart',                  'Retail & E-commerce'),
('TARGET',                    'Target',                   'Retail & E-commerce'),
('TARGET ENTERPRISE%',        'Target',                   'Retail & E-commerce'),
('HOME DEPOT%',               'Home Depot',               'Retail & E-commerce'),
('LOWES%',                    'Lowe''s',                  'Retail & E-commerce'),
('COSTCO%',                   'Costco',                   'Retail & E-commerce'),
('EBAY%',                     'eBay',                     'Retail & E-commerce'),
('WAYFAIR%',                  'Wayfair',                  'Retail & E-commerce'),
('CHEWY%',                    'Chewy',                    'Retail & E-commerce'),
('BEST BUY%',                 'Best Buy',                 'Retail & E-commerce'),
('KROGER%',                   'Kroger',                   'Retail & E-commerce'),
('WALGREEN%',                 'Walgreens',                'Retail & E-commerce'),
-- ---------- Energy & Utilities ----------
('EXXON%',                    'ExxonMobil',               'Energy & Utilities'),
('CHEVRON%',                  'Chevron',                  'Energy & Utilities'),
('SHELL %',                   'Shell',                    'Energy & Utilities'),
('CONOCOPHILLIPS%',           'ConocoPhillips',           'Energy & Utilities'),
('SCHLUMBERGER%',             'SLB',                      'Energy & Utilities'),
('SLB %',                     'SLB',                      'Energy & Utilities'),
('HALLIBURTON%',              'Halliburton',              'Energy & Utilities'),
('BAKER HUGHES%',             'Baker Hughes',             'Energy & Utilities'),
('DUKE ENERGY%',              'Duke Energy',              'Energy & Utilities'),
('NEXTERA%',                  'NextEra Energy',           'Energy & Utilities'),
('FLORIDA POWER%',            'NextEra Energy',           'Energy & Utilities'),
('SOUTHERN COMPANY%',         'Southern Company',         'Energy & Utilities'),
('DOMINION ENERGY%',          'Dominion Energy',          'Energy & Utilities'),
('PHILLIPS 66%',              'Phillips 66',              'Energy & Utilities'),
('VALERO%',                   'Valero',                   'Energy & Utilities'),
('MARATHON PETROLEUM%',       'Marathon Petroleum',       'Energy & Utilities');


-- =============================================================
-- PART 3 - Employer group   (about 1-2 minutes)
-- Lookup match first; otherwise the cleaned name in Title Case
-- =============================================================
DROP TABLE IF EXISTS h1b.employer_map;

-- One row per distinct cleaned name (much faster than matching 1.1M rows)
CREATE TABLE h1b.employer_map AS
SELECT DISTINCT ON (n.employer_clean)
    n.employer_clean,
    COALESCE(l.employer_group, INITCAP(n.employer_clean)) AS employer_group,
    l.industry                                            AS lookup_industry
FROM (SELECT DISTINCT employer_clean FROM h1b.lca) n
LEFT JOIN h1b.employer_lookup l
       ON n.employer_clean LIKE l.pattern
ORDER BY n.employer_clean, LENGTH(l.pattern) DESC NULLS LAST;

CREATE INDEX ON h1b.employer_map (employer_clean);

UPDATE h1b.lca a
SET employer_group = m.employer_group
FROM h1b.employer_map m
WHERE a.employer_clean = m.employer_clean;


-- =============================================================
-- PART 4 - Industry   (about 1-2 minutes)
-- Step A: industry from each row's NAICS code
-- Step B: each employer gets its MOST COMMON industry (so Amazon
--         isn't split across 3 codes), unless the lookup says otherwise
-- =============================================================
DROP TABLE IF EXISTS h1b.employer_industry;

CREATE TABLE h1b.employer_industry AS
WITH row_industry AS (
    SELECT
        employer_group,
        CASE
            WHEN naics_code ~ '^(5415|5416|5412|5613)'     THEN 'IT Services & Consulting'
            WHEN naics_code ~ '^(62|3254|524114|525120)'   THEN 'Healthcare'
            WHEN naics_code ~ '^52'                        THEN 'Financial Services & Banking'
            WHEN naics_code ~ '^(44|45)'                   THEN 'Retail & E-commerce'
            WHEN naics_code ~ '^(211|213|22|324|486)'      THEN 'Energy & Utilities'
            WHEN naics_code ~ '^(51|334)'                  THEN 'Technology'
            WHEN naics_code ~ '^(611|5417)'                THEN 'Education & Research'
            WHEN naics_code ~ '^(31|32|33)'                THEN 'Manufacturing'
            ELSE 'Other'
        END AS naics_industry
    FROM h1b.lca
),
ranked AS (
    SELECT
        employer_group,
        naics_industry,
        ROW_NUMBER() OVER (PARTITION BY employer_group ORDER BY COUNT(*) DESC) AS rn
    FROM row_industry
    GROUP BY employer_group, naics_industry
)
SELECT
    r.employer_group,
    COALESCE(o.industry, r.naics_industry) AS industry
FROM ranked r
LEFT JOIN (SELECT DISTINCT employer_group, industry FROM h1b.employer_lookup) o
       ON o.employer_group = r.employer_group
WHERE r.rn = 1;

CREATE INDEX ON h1b.employer_industry (employer_group);

UPDATE h1b.lca a
SET industry = e.industry
FROM h1b.employer_industry e
WHERE a.employer_group = e.employer_group;


-- =============================================================
-- PART 5 - Role family   (about 1 minute)
-- Order matters: the first matching rule wins
-- =============================================================
-- Collapse double spaces first ("BUSINESS   ANALYST" -> "BUSINESS ANALYST")
UPDATE h1b.lca
SET job_title = REGEXP_REPLACE(job_title, '\s+', ' ', 'g')
WHERE job_title ~ '\s{2,}';

UPDATE h1b.lca
SET role_family = CASE
    -- Exclude testing / coding "analyst" titles first
    WHEN job_title ~ '(QA|QUALITY ASSURANCE|TEST|PROGRAMMER|SECURITY|CYBER)'
         AND job_title ~ 'ANALY'                                     THEN 'Other Tech'
    WHEN job_title ~ '(BUSINESS INTELLIGENCE|\mBI\M|POWER BI|TABLEAU|REPORTING ANALY)'
                                                                     THEN 'BI / Reporting'
    WHEN job_title ~ '(DATA ANALY|ANALYTICS ANALY|PRODUCT ANALY|INSIGHTS ANALY|ANALYTICS SPECIALIST)'
                                                                     THEN 'Data Analyst'
    WHEN job_title ~ '(BUSINESS ANALY|BUSINESS SYSTEMS ANALY|BUSINESS PROCESS ANALY)'
                                                                     THEN 'Business Analyst'
    WHEN job_title ~ '(DATA SCIEN|MACHINE LEARNING)'                 THEN 'Data Scientist'
    WHEN job_title ~ 'DATA ENGINEER'                                 THEN 'Data Engineer'
    -- Generic "ANALYST" titles: use the occupation (SOC) code
    WHEN job_title ~ 'ANALY' AND soc_code LIKE '15-2051.01%'         THEN 'BI / Reporting'
    WHEN job_title ~ 'ANALY' AND soc_code LIKE '15-2051%'            THEN 'Data Analyst'
    WHEN job_title ~ 'ANALY' AND soc_code ~ '^(13-1111|15-2031|13-1161|13-1081)'
                                                                     THEN 'Other Business Analyst'
    WHEN job_title ~ 'ANALY' AND soc_code ~ '^13-20'                 THEN 'Financial Analyst'
    WHEN job_title ~ '(SOFTWARE|DEVELOPER|PROGRAMMER|DEVOPS|ENGINEER|ARCHITECT)'
         AND soc_code LIKE '15-%'                                    THEN 'Software & IT Engineering'
    WHEN soc_code LIKE '15-%'                                        THEN 'Other Tech'
    ELSE 'Other'
END;

UPDATE h1b.lca
SET is_target_role = role_family IN ('Data Analyst', 'Business Analyst', 'BI / Reporting');


-- =============================================================
-- PART 6 - View for Power BI
-- Power BI connects to THIS view (not the raw table)
-- =============================================================
DROP VIEW IF EXISTS h1b.vw_lca_dashboard;

CREATE VIEW h1b.vw_lca_dashboard AS
SELECT
    case_number,
    case_status,
    is_certified,
    fiscal_year,
    fy_quarter,
    decision_date,
    received_date,
    employer_group          AS employer,
    industry,
    job_title,
    soc_title,
    role_family,
    is_target_role,
    pw_wage_level           AS wage_level,
    annual_wage,
    annual_prevailing_wage,
    wage_to_pw_ratio,
    is_wage_outlier,
    total_workers,
    new_employment,
    continued_employment,
    change_employer,
    is_full_time,
    worksite_city,
    worksite_state,
    worksite_postal_code,
    h_1b_dependent,
    naics_code
FROM h1b.lca;


-- =============================================================
-- CHECKS - run one at a time
-- =============================================================

-- 1) No blanks: all four numbers should be 0
SELECT
    SUM(CASE WHEN employer_group IS NULL THEN 1 ELSE 0 END) AS no_employer,
    SUM(CASE WHEN industry       IS NULL THEN 1 ELSE 0 END) AS no_industry,
    SUM(CASE WHEN role_family    IS NULL THEN 1 ELSE 0 END) AS no_role,
    SUM(CASE WHEN is_target_role IS NULL THEN 1 ELSE 0 END) AS no_target_flag
FROM h1b.lca;

-- 2) Top 25 sponsors (Amazon should appear ONCE, near the top)
SELECT employer_group, industry, COUNT(*) AS lcas
FROM h1b.lca
WHERE is_certified
GROUP BY employer_group, industry
ORDER BY lcas DESC
LIMIT 25;

-- 3) LCAs per industry
SELECT industry, COUNT(*) AS lcas, COUNT(DISTINCT employer_group) AS employers
FROM h1b.lca
WHERE is_certified
GROUP BY industry
ORDER BY lcas DESC;

-- 4) LCAs per role family, with median yearly wage
SELECT
    role_family,
    COUNT(*)                                                  AS lcas,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY annual_wage)  AS median_wage
FROM h1b.lca
WHERE is_certified AND NOT is_wage_outlier
GROUP BY role_family
ORDER BY lcas DESC;

-- 5) Spot-check: 30 random target-role titles (do they look right?)
SELECT job_title, soc_title, role_family
FROM h1b.lca
WHERE is_target_role
ORDER BY RANDOM()
LIMIT 30;
