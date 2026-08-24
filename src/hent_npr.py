"""
Henter nokkeltall for spesialisthelsetjenesten fra Folkehelseinstituttets apne API
(Norsk pasientregister) og lagrer datert rafil i data/raw/.

Kilde:   https://statistikk-data.fhi.no/api/open/v1
Lisens:  Norsk lisens for offentlige data (NLOD). Kilde skal oppgis.
Eier:    Folkehelseinstituttet er dataansvarlig for Norsk pasientregister.

Skriptet hardkoder ikke dimensjonsverdier. Det leser dimensjonene fra API-et
for hver tabell og ber om alle tilgjengelige verdier. Nar FHI legger til et nytt
ar eller et nytt maltall, folger uttrekket med uten kodeendring.

Bruk:
    python src/hent_npr.py
    python src/hent_npr.py --tabell 517
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
from datetime import date
from pathlib import Path

import requests

API = "https://statistikk-data.fhi.no/api/open/v1"
KILDE = "npr"

# Fire tjenesteomrader publisert som separate tabeller hos FHI.
TABELLER = {
    517: "som",    # Somatikk
    518: "phv",    # Psykisk helsevern for voksne
    464: "phbu",   # Psykisk helsevern for barn og unge
    520: "tsb",    # Tverrfaglig spesialisert rusbehandling
}

ROT = Path(__file__).resolve().parents[1]
RAA = ROT / "data" / "raw"
TIMEOUT = 90


def hent_dimensjoner(tabell_id: int) -> list[dict]:
    """Leser dimensjonene for en tabell slik de er definert hos FHI i dag."""
    r = requests.get(f"{API}/{KILDE}/Table/{tabell_id}/dimension", timeout=TIMEOUT)
    r.raise_for_status()
    return r.json()["dimensions"]


def bygg_foresporsel(dimensjoner: list[dict]) -> dict:
    """
    API-et krever at alle dimensjoner er med, og minst en verdi per dimensjon.
    Vi ber om alt som finnes, og filtrerer heller i dbt.
    """
    return {
        "dimensions": [
            {
                "code": d["code"],
                "filter": "item",
                "values": [k["value"] for k in d["categories"]],
            }
            for d in dimensjoner
        ],
        "response": {"format": "csv2", "maxRowCount": 500_000},
    }


def hent_data(tabell_id: int, foresporsel: dict) -> str:
    """
    NB: API-et svarer med "Content-Type: text/csv" uten charset. Etter
    HTTP-standarden faller requests da tilbake pa ISO-8859-1, mens innholdet
    faktisk er UTF-8. Bruker man r.text direkte, blir "År" til "Ãr" og fila
    far NEL-linjeskift (0x85) som DuckDB tolker som radskille midt i en tekst.

    Feilen er stille: fila ser riktig ut i antall rader, og bryter forst nar
    en kolonne med norsk tegn skal slas opp. Derfor dekodes svaret eksplisitt
    her, og det er ikke noe som skal "ryddes opp i" senere i Power Query.
    """
    r = requests.post(
        f"{API}/{KILDE}/Table/{tabell_id}/data",
        json=foresporsel,
        headers={"Accept": "text/csv"},
        timeout=TIMEOUT,
    )
    r.raise_for_status()
    return r.content.decode("utf-8")


def skriv_med_manifest(navn: str, tabell_id: int, innhold: str, dimensjoner: list[dict]) -> Path:
    """
    Skriver rafila datert, og et manifest ved siden av.

    Manifestet er poenget: det gjor et uttrekk etterprovbart. Uten sjekksum og
    uttrekkstidspunkt kan man ikke i ettertid vite om et tall som endret seg
    skyldtes ny publisering hos kilden eller en feil i egen kode.
    """
    RAA.mkdir(parents=True, exist_ok=True)
    stempel = date.today().isoformat()
    fil = RAA / f"npr_{navn}_{stempel}.csv"
    fil.write_text(innhold, encoding="utf-8")

    meta = requests.get(f"{API}/{KILDE}/Table/{tabell_id}/metadata", timeout=TIMEOUT).json()
    manifest = {
        "kilde": "Folkehelseinstituttet, Norsk pasientregister",
        "api": f"{API}/{KILDE}/Table/{tabell_id}/data",
        "tabell_id": tabell_id,
        "tabellnavn": meta.get("name", "").strip(),
        "uttrekt_dato": stempel,
        "uttrekt_tidspunkt": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "antall_rader": innhold.count("\n") - 1,
        "sha256": hashlib.sha256(innhold.encode("utf-8")).hexdigest(),
        "lisens": "NLOD - Norsk lisens for offentlige data",
        "dimensjoner": {
            d["code"]: [k["value"] for k in d["categories"]] for d in dimensjoner
        },
    }
    (RAA / f"npr_{navn}_{stempel}.manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return fil


def main() -> int:
    p = argparse.ArgumentParser(description="Uttrekk fra FHIs apne NPR-API")
    p.add_argument("--tabell", type=int, help="Hent bare en tabell")
    args = p.parse_args()

    valgte = {args.tabell: TABELLER[args.tabell]} if args.tabell else TABELLER

    for tabell_id, navn in valgte.items():
        try:
            dim = hent_dimensjoner(tabell_id)
            csv = hent_data(tabell_id, bygg_foresporsel(dim))
            fil = skriv_med_manifest(navn, tabell_id, csv, dim)
            print(f"OK   {navn:5s} tabell {tabell_id}: {csv.count(chr(10)) - 1:>5} rader -> {fil.name}")
        except requests.HTTPError as e:
            print(f"FEIL {navn:5s} tabell {tabell_id}: {e}", file=sys.stderr)
            return 1
        time.sleep(0.5)  # vaer grei mot en gratis offentlig tjeneste

    print("\nRauttrekk ferdig.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
