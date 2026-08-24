"""
Kontrollerer at modellen faktisk inneholder det den skal, etter et bygg.

Denne fila finnes fordi et skript som sier "FERDIG" uten a ha kontrollert
noe, er verre enn et skript som sier ingenting. Da tror man at det virket.

Kontrollen er den samme typen som brukes mot et datavarehus i drift: ikke
"kjorte jobben uten feil", men "ligger radene der de skal ligge".
"""

from __future__ import annotations

import sys
from pathlib import Path

import duckdb

ROT = Path(__file__).resolve().parents[1]
DB = ROT / "data" / "vv_ventetid.duckdb"


def main() -> int:
    if not DB.exists():
        print("FEIL: databasen finnes ikke. Kjor 2_HENT_DATA.bat forst.")
        return 1

    con = duckdb.connect(str(DB), read_only=True)
    npr = con.sql("select count(*) from fact_indikator where datakilde='NPR'").fetchone()[0]
    nki = con.sql("select count(*) from fact_indikator where datakilde='NKI'").fetchone()[0]
    hf = con.sql("select count(*) from dim_enhet where enhet_niva='Helseforetak'").fetchone()[0]
    bro = con.sql("select count(*) from bro_enhet_rls").fetchone()[0]
    umappet = con.sql(
        "select enhet_navn from dim_enhet "
        "where er_umappet = 1 and enhet_niva in ('Region','Helseforetak') "
        "order by enhet_navn"
    ).fetchall()
    utenfor = con.sql(
        "select count(*) from dim_enhet where vis_i_rapport = 0"
    ).fetchone()[0]

    print()
    print("=" * 46)
    print("  KONTROLL AV MODELLEN")
    print("=" * 46)
    print(f"  NPR-rader (aktivitet)      {npr:>6}")
    print(f"  NKI-rader (kvalitet)       {nki:>6}")
    print(f"  Helseforetak i dim_enhet   {hf:>6}")
    print(f"  Rader i bro_enhet_rls      {bro:>6}")
    print()

    if npr == 0:
        print("  FEIL: ingen NPR-data. Kjor 2_HENT_DATA.bat.")
        return 1

    if nki == 0:
        print("  IKKE FERDIG - NKI-dataene er ikke med i det hele tatt.")
        print()
        print("  Mulige arsaker:")
        print("   - eksporten er ikke lastet ned enna")
        print("   - fila ligger et annet sted enn data\\manuell\\")
        print("   - du eksporterte Underliggende data i stedet for Summerte")
        print()
        print("  Se powerbi\\NKI_EKSPORT.md")
        return 1

    if hf == 0:
        nivaer = con.sql(
            "select distinct enhet_niva from dim_enhet "
            "where enhet_id in (select enhet_id from fact_indikator where datakilde='NKI')"
        ).fetchall()
        enheter = con.sql(
            "select enhet_navn from dim_enhet "
            "where enhet_id in (select enhet_id from fact_indikator where datakilde='NKI') "
            "order by enhet_navn"
        ).fetchall()
        print("  DELVIS FERDIG - NKI-dataene er inne, men uten helseforetak.")
        print()
        print(f"  Eksporten dekker bare nivaet: {', '.join(n for (n,) in nivaer)}")
        print(f"  Enheter i eksporten ({len(enheter)}):")
        for (n,) in enheter:
            print(f"    - {n}")
        print()
        print("  Du far et fungerende dashbord med sammenligning mellom de fire")
        print("  regionale helseforetakene, men ikke Vestre Viken mot andre")
        print("  foretak, og radnivasikkerheten kan ikke testes.")
        print()
        print("  Losning: last ned et uttrekk til med Niva satt til")
        print("  helseforetak eller sykehus. Legg fila i samme mappe -")
        print("  modellen leser alle CSV-filer der og setter dem sammen.")
        print()
        print("  Du kan ogsa ga videre til Power BI na og legge til")
        print("  foretaksnivaet senere. Modellen tar det uten endringer.")
        return 2

    if utenfor:
        print(f"  {utenfor} enheter er kommuner, legevakter eller lignende.")
        print("  De folger med i eksporten, men filtreres bort i rapporten")
        print("  med dim_enhet[vis_i_rapport] = 1. Det er som forventet.")
        print()

    if umappet:
        print("  ADVARSEL: foretak som ikke star i oppslagstabellen:")
        for (n,) in umappet:
            print(f"    - {n}")
        print("  Legg dem inn i dbt\\seeds\\enhet_mapping.csv om de skal")
        print("  ha riktig region og kortnavn i rapporten.")
        print()

    print("  OK - modellen er komplett.")
    print("  Neste steg: powerbi\\STEG_FOR_STEG.md, DEL 1.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
