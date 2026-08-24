"""
Eksporterer mart-tabellene fra DuckDB til CSV i data/mart/.

Power BI kan lese DuckDB direkte via ODBC, men det krever driverinstallasjon
pa maskinen og gjor prosjektet vanskeligere a apne for andre. CSV er valgt
fordi det holder terskelen lav for den som skal se pa arbeidet, og fordi
kildedataene her er sma nok til at formatet ikke koster noe.

I en produksjonslosning ville dette laget vaert et datavarehus eller en
lakehouse-tabell, ikke fildump. Det er beskrevet i dokumentasjon/datamodell.md.
"""

from pathlib import Path

import duckdb

ROT = Path(__file__).resolve().parents[1]
DB = ROT / "data" / "vv_ventetid.duckdb"
UT = ROT / "data" / "mart"

TABELLER = [
    "dim_enhet",
    "dim_periode",
    "dim_indikator",
    "dim_tjenesteomrade",
    "fact_indikator",
    "bro_enhet_rls",
]


def main() -> None:
    UT.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(DB), read_only=True)
    for t in TABELLER:
        fil = UT / f"{t}.csv"
        con.sql(f"copy (select * from {t}) to '{fil}' (header, delimiter ',')")
        n = con.sql(f"select count(*) from {t}").fetchone()[0]
        merk = "  <- tom til NKI-eksporten er lagt inn" if n == 0 else ""
        print(f"{t:22s} {n:>6} rader -> {fil.name}{merk}")
    con.close()


if __name__ == "__main__":
    main()
