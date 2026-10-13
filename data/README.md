# Data

The raw data is not stored in this repo because the files are too large for GitHub.

**Source:** U.S. Department of Labor, Office of Foreign Labor Certification, LCA Disclosure Data
https://www.dol.gov/agencies/eta/foreign-labor/performance

**Files used (8, one per quarter):**
- FY2024 Q1, Q2, Q3, Q4
- FY2025 Q1, Q2, Q3, Q4

Each DOL file covers one quarter only, so all 8 are needed for two full fiscal years
(October 2023 to September 2025).

**How to rebuild:**
1. Put the 8 Excel files in `data/raw/`, named `LCA_Disclosure_Data_FY2024_Q1.xlsx` through
   `LCA_Disclosure_Data_FY2025_Q4.xlsx` (the names the script expects).
2. Run `python/01_preprocess_lca.py`. It writes the combined clean CSV to `data/clean/`
   (1,118,768 H-1B rows after deduplication).
3. Load that CSV into PostgreSQL with the scripts in `sql/` (see the main README).
