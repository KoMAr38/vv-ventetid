"""
Validerer den manuelle eksporten fra Helsedirektoratets NKI-eksportvisning
for filen legges inn i dbt.

Bakgrunn: NKI-data pa helseforetaksniva har ikke apent API. De hentes ved a
eksportere til Excel eller CSV fra eksportvisningen. Da er det den som
eksporterer som er kvalitetsleddet, og en manuell eksport uten kontroll er
den vanligste kilden til stille feil i et datagrunnlag: feil filter star pa,
en periode mangler, desimalskilletegnet er komma i stedet for punktum.

Skriptet gjor fire ting:
  1. sjekker at kolonnene er de forventede
  2. sjekker at ingen nokkelkolonne er tom
  3. sjekker at det ikke finnes duplikate nokler
  4. skriver et manifest med sjekksum, radantall og hvilke perioder som er med

Forventede kolonner folger eksportvisningen hos Helsedirektoratet:
Tidsperiode, Kvalitetsindikator, Maltall, Lokasjon, Verdi, Sektor, Niva

Bruk:
    python src/valider_nki.py data/manuell/nki_eksport.csv
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

import pandas as pd

FORVENTEDE = ["Tidsperiode", "Kvalitetsindikator", "Måltall", "Lokasjon", "Verdi", "Sektor", "Nivå"]
NOKKEL = ["Tidsperiode", "Kvalitetsindikator", "Måltall", "Lokasjon"]


def les(sti: Path) -> pd.DataFrame:
    if sti.suffix.lower() in {".xlsx", ".xls"}:
        return pd.read_excel(sti, dtype=str)
    for sep in (";", ","):
        df = pd.read_csv(sti, sep=sep, dtype=str, encoding="utf-8-sig")
        if df.shape[1] > 1:
            return df
    raise ValueError("Klarte ikke lese fila som CSV med ; eller ,")


def valider(sti: Path) -> int:
    df = les(sti)
    feil: list[str] = []
    advarsler: list[str] = []

    mangler = [k for k in FORVENTEDE if k not in df.columns]
    ekstra = [k for k in df.columns if k not in FORVENTEDE]
    if mangler:
        feil.append(f"Mangler kolonner: {mangler}")
    if ekstra:
        advarsler.append(f"Ukjente kolonner (tas ikke inn i modellen): {ekstra}")

    if not mangler:
        for k in NOKKEL:
            tomme = int(df[k].isna().sum() + (df[k].astype(str).str.strip() == "").sum())
            if tomme:
                feil.append(f"{tomme} rader har tom verdi i nokkelkolonnen '{k}'")

        dupl = int(df.duplicated(subset=NOKKEL).sum())
        if dupl:
            feil.append(f"{dupl} duplikate rader pa nokkelen {NOKKEL}")

        # Verdi kan vaere tom: Hdir prikker tall der pasientgrunnlaget er lavt.
        # Det er ikke en feil, men det skal telles og vises i rapporten.
        prikket = int(df["Verdi"].isna().sum() + (df["Verdi"].astype(str).str.strip().isin(["", ":", "-"])).sum())
        if prikket:
            advarsler.append(f"{prikket} rader har ingen verdi (trolig prikket av personvernhensyn)")

        komma = int(df["Verdi"].astype(str).str.contains(",", na=False).sum())
        if komma:
            advarsler.append(f"{komma} verdier bruker komma som desimalskilletegn - konverteres i staging")

    print(f"Fil        : {sti.name}")
    print(f"Rader      : {len(df)}")
    print(f"Perioder   : {sorted(df['Tidsperiode'].dropna().unique())[:12] if 'Tidsperiode' in df else 'n/a'}")
    print(f"Lokasjoner : {df['Lokasjon'].nunique() if 'Lokasjon' in df else 'n/a'}")
    print(f"Indikatorer: {df['Kvalitetsindikator'].nunique() if 'Kvalitetsindikator' in df else 'n/a'}")

    for a in advarsler:
        print(f"  ADVARSEL  {a}")
    for f in feil:
        print(f"  FEIL      {f}")

    manifest = {
        "fil": sti.name,
        "kilde": "Helsedirektoratet, Nasjonale kvalitetsindikatorer (manuell eksport)",
        "lisens": "NLOD - Norsk lisens for offentlige data",
        "antall_rader": len(df),
        "sha256": hashlib.sha256(sti.read_bytes()).hexdigest(),
        "kolonner": list(df.columns),
        "perioder": sorted(df["Tidsperiode"].dropna().unique().tolist()) if "Tidsperiode" in df else [],
        "advarsler": advarsler,
        "feil": feil,
    }
    sti.with_suffix(".manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    if feil:
        print("\nAvvist. Rett eksporten og kjor pa nytt.")
        return 1
    print("\nGodkjent.")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        raise SystemExit(2)
    raise SystemExit(valider(Path(sys.argv[1])))
