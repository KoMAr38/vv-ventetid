"""
Finner og validerer NKI-eksporten i data/manuell/.

Malfila (MAL_*) hoppes over. Filtreringen ligger her og ikke i .bat-fila,
fordi Windows-batch handterer filnavn og feilkoder darlig nok til at en
stille feil er lett a lage.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROT = Path(__file__).resolve().parents[1]
MAPPE = ROT / "data" / "manuell"

sys.path.insert(0, str(Path(__file__).resolve().parent))
from valider_nki import valider  # noqa: E402


def main() -> int:
    kandidater = [
        f
        for f in sorted(MAPPE.glob("*"))
        if f.suffix.lower() in {".csv", ".xlsx", ".xls"}
        and not f.name.upper().startswith("MAL_")
    ]

    if not kandidater:
        print()
        print("Fant ingen NKI-eksport i  data\\manuell\\")
        print()
        alle = [f.name for f in sorted(MAPPE.glob("*")) if f.suffix.lower() in {".csv", ".xlsx", ".xls"}]
        if alle:
            print("Filer som ligger der na:")
            for n in alle:
                merk = "  (malfil - teller ikke)" if n.upper().startswith("MAL_") else ""
                print(f"  - {n}{merk}")
        else:
            print("Mappa er tom.")
        print()
        print("Last ned eksporten forst. Se  powerbi\\NKI_EKSPORT.md")
        return 1

    feil = 0
    for f in kandidater:
        print(f"--- {f.name} ---")
        if valider(f) != 0:
            feil = 1
        print()
    return feil


if __name__ == "__main__":
    raise SystemExit(main())
