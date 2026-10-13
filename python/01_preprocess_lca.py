"""
H-1B Sponsor Explorer - Step 1: Pre-process raw DOL LCA disclosure files
-----------------------------------------------------------------------
What this script does (in plain English):
  1. Opens each DOL LCA Excel file you list below
  2. Keeps only the ~30 columns we need (the raw file has ~95)
  3. Keeps only H-1B cases (drops E-3 and H-1B1)
  4. Tidies text (extra spaces, capitalization) and dates
  5. Removes the $ sign and commas from wage columns
  6. Adds a fiscal_year column so you can compare years later
  7. Removes duplicate case numbers
  8. Saves ONE clean CSV that PostgreSQL can import
  9. Prints a short "health check" so you can see what's in the data

Heavy business logic (annualizing wages, job-title filtering, employer
name cleanup) is intentionally left for SQL - that's the part to show off.

How to run (from the project folder, in Terminal / Anaconda Prompt):
    pip install pandas openpyxl python-calamine
    python python/01_preprocess_lca.py
"""

from pathlib import Path
import pandas as pd

# ---------------------------------------------------------------
# 1. SETTINGS - edit these two things only
# ---------------------------------------------------------------
# List each Excel file and the fiscal year it belongs to.
# IMPORTANT: each DOL file holds ONE quarter only (not the whole year),
# so a full fiscal year = 4 files (Q1 + Q2 + Q3 + Q4).
# If a file is missing, the script skips it and tells you.
INPUT_FILES = {
    "data/raw/LCA_Disclosure_Data_FY2025_Q1.xlsx": 2025,
    "data/raw/LCA_Disclosure_Data_FY2025_Q2.xlsx": 2025,
    "data/raw/LCA_Disclosure_Data_FY2025_Q3.xlsx": 2025,
    "data/raw/LCA_Disclosure_Data_FY2025_Q4.xlsx": 2025,
    "data/raw/LCA_Disclosure_Data_FY2024_Q1.xlsx": 2024,
    "data/raw/LCA_Disclosure_Data_FY2024_Q2.xlsx": 2024,
    "data/raw/LCA_Disclosure_Data_FY2024_Q3.xlsx": 2024,
    "data/raw/LCA_Disclosure_Data_FY2024_Q4.xlsx": 2024,
}

OUTPUT_FILE = "data/clean/lca_h1b_clean.csv"

# ---------------------------------------------------------------
# 2. COLUMNS TO KEEP (order matters - it must match the SQL table)
# ---------------------------------------------------------------
KEEP_COLUMNS = [
    "CASE_NUMBER", "CASE_STATUS", "RECEIVED_DATE", "DECISION_DATE",
    "VISA_CLASS", "JOB_TITLE", "SOC_CODE", "SOC_TITLE",
    "FULL_TIME_POSITION", "BEGIN_DATE", "END_DATE",
    "TOTAL_WORKER_POSITIONS", "NEW_EMPLOYMENT", "CONTINUED_EMPLOYMENT",
    "CHANGE_EMPLOYER",
    "EMPLOYER_NAME", "EMPLOYER_CITY", "EMPLOYER_STATE", "NAICS_CODE",
    "WORKSITE_CITY", "WORKSITE_COUNTY", "WORKSITE_STATE", "WORKSITE_POSTAL_CODE",
    "WAGE_RATE_OF_PAY_FROM", "WAGE_RATE_OF_PAY_TO", "WAGE_UNIT_OF_PAY",
    "PREVAILING_WAGE", "PW_UNIT_OF_PAY", "PW_WAGE_LEVEL",
    "H_1B_DEPENDENT", "WILLFUL_VIOLATOR",
]

DATE_COLUMNS = ["RECEIVED_DATE", "DECISION_DATE", "BEGIN_DATE", "END_DATE"]
MONEY_COLUMNS = ["WAGE_RATE_OF_PAY_FROM", "WAGE_RATE_OF_PAY_TO", "PREVAILING_WAGE"]
UPPERCASE_COLUMNS = ["EMPLOYER_NAME", "EMPLOYER_CITY", "EMPLOYER_STATE",
                     "WORKSITE_CITY", "WORKSITE_COUNTY", "WORKSITE_STATE"]


def read_one_file(path: str) -> pd.DataFrame:
    """Read one DOL Excel file, keeping only the columns we need."""
    print(f"\nReading {path} ... (large files can take 2-10 minutes)")
    wanted = set(KEEP_COLUMNS)
    pick = lambda col: str(col).strip().upper() in wanted
    try:
        # 'calamine' is much faster than the default Excel reader
        df = pd.read_excel(path, usecols=pick, dtype=str, engine="calamine")
    except Exception:
        print("  (calamine reader not available - using the slower default reader)")
        df = pd.read_excel(path, usecols=pick, dtype=str)

    df.columns = [str(c).strip().upper() for c in df.columns]

    missing = [c for c in KEEP_COLUMNS if c not in df.columns]
    if missing:
        print(f"  WARNING - these columns were not found and will be left blank: {missing}")
        print("  (DOL sometimes renames columns - check the Record Layout PDF)")
    # Add any missing columns as blanks and put everything in the fixed order
    df = df.reindex(columns=KEEP_COLUMNS)
    print(f"  Loaded {len(df):,} rows")
    return df


def clean(df: pd.DataFrame, fiscal_year: int) -> pd.DataFrame:
    # Trim spaces on every text column; turn empty strings into real blanks
    for col in df.columns:
        df[col] = df[col].astype("string").str.strip().replace({"": pd.NA, "nan": pd.NA})

    # Keep H-1B only
    before = len(df)
    df = df[df["VISA_CLASS"].str.upper() == "H-1B"].copy()
    print(f"  Kept {len(df):,} H-1B rows (dropped {before - len(df):,} E-3 / H-1B1 rows)")

    # Consistent capitalization + collapse double spaces
    for col in UPPERCASE_COLUMNS:
        df[col] = df[col].str.upper().str.replace(r"\s+", " ", regex=True)

    # Dates -> YYYY-MM-DD text (PostgreSQL reads this format reliably)
    for col in DATE_COLUMNS:
        df[col] = pd.to_datetime(df[col], errors="coerce").dt.strftime("%Y-%m-%d")

    # Money -> plain numbers ("$85,000.00" -> "85000.00")
    for col in MONEY_COLUMNS:
        df[col] = df[col].str.replace(r"[$,]", "", regex=True)

    # First 5 digits of ZIP only (drops "-1234" extensions)
    df["WORKSITE_POSTAL_CODE"] = df["WORKSITE_POSTAL_CODE"].str[:5]

    df["FISCAL_YEAR"] = fiscal_year
    return df


def health_check(df: pd.DataFrame) -> None:
    print("\n================ HEALTH CHECK ================")
    print(f"Total rows: {len(df):,}")
    print("\nRows by fiscal year:")
    print(df["FISCAL_YEAR"].value_counts().sort_index().to_string())
    print("\nRows by decision month (check: no missing months = all quarters loaded):")
    print(pd.to_datetime(df["DECISION_DATE"]).dt.to_period("M").value_counts().sort_index().to_string())
    print("\nCase status breakdown:")
    print(df["CASE_STATUS"].value_counts().to_string())
    print("\nWage unit breakdown (we will convert all to yearly in SQL):")
    print(df["WAGE_UNIT_OF_PAY"].value_counts(dropna=False).to_string())
    print("\nPrevailing wage level breakdown:")
    print(df["PW_WAGE_LEVEL"].value_counts(dropna=False).to_string())
    print("\nTop 15 employers by number of LCAs (raw names - messy on purpose):")
    print(df["EMPLOYER_NAME"].value_counts().head(15).to_string())
    print("\nRows by NAICS 2-digit prefix (used for industry mapping in SQL):")
    print(df["NAICS_CODE"].str[:2].value_counts(dropna=False).head(20).to_string())
    print("\nTop 25 job titles (used to design the analyst-role filter in SQL):")
    print(df["JOB_TITLE"].str.upper().value_counts().head(25).to_string())
    print("\nPercent blank per column (only columns with blanks):")
    blanks = (df.isna().mean() * 100).round(1)
    print(blanks[blanks > 0].sort_values(ascending=False).to_string())
    print("==============================================")


def main():
    frames = []
    for path, fy in INPUT_FILES.items():
        if not Path(path).exists():
            print(f"\nSKIPPED (file not found): {path}")
            continue
        frames.append(clean(read_one_file(path), fy))

    if not frames:
        raise FileNotFoundError("No input files found - check that the .xlsx files are in data/raw/")

    df = pd.concat(frames, ignore_index=True)

    # One row per case number (keep the most recent decision if repeated)
    before = len(df)
    df = (df.sort_values("DECISION_DATE")
            .drop_duplicates(subset="CASE_NUMBER", keep="last"))
    print(f"\nRemoved {before - len(df):,} duplicate case numbers")

    # lowercase column names = no quotation marks needed in PostgreSQL
    df.columns = [c.lower() for c in df.columns]

    Path(OUTPUT_FILE).parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUTPUT_FILE, index=False, encoding="utf-8")
    print(f"Saved {len(df):,} rows to {OUTPUT_FILE}")

    df.columns = [c.upper() for c in df.columns]

    # Print the health check AND save it to a text file for your README
    import io, contextlib
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        health_check(df)
    report = buffer.getvalue()
    print(report)
    report_path = Path(OUTPUT_FILE).parent / "health_check.txt"
    report_path.write_text(report, encoding="utf-8")
    print(f"Health check saved to {report_path}")


if __name__ == "__main__":
    main()
