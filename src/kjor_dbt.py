"""
Kjorer dbt fra Python.

Bakgrunn: dbt installerer et kommandolinjeprogram (dbt.exe) i en Scripts-mappe
som ofte ikke ligger pa PATH pa Windows. Samtidig kan ikke pakken kalles med
"python -m dbt", fordi den ikke har en __main__.py.

Riktig inngang er dbt.cli.main:dbtRunner, som er det offisielle
programmeringsgrensesnittet. Da slipper vi a vite hvor dbt.exe ligger,
og vi far strukturert resultat tilbake i stedet for a matte tolke tekst.

Bruk:
    python src/kjor_dbt.py deps
    python src/kjor_dbt.py build --full-refresh
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROT = Path(__file__).resolve().parents[1]
DBT = ROT / "dbt"


def main() -> int:
    if not (DBT / "dbt_project.yml").exists():
        print(f"FEIL: finner ikke dbt-prosjektet i {DBT}", file=sys.stderr)
        return 1

    # dbt leter etter profiles.yml i ~/.dbt/ som standard. Vi har den i
    # prosjektmappa slik at repoet er selvforsynt.
    os.environ.setdefault("DBT_PROFILES_DIR", str(DBT))
    os.chdir(DBT)

    try:
        from dbt.cli.main import dbtRunner
    except ImportError:
        print(
            "FEIL: dbt er ikke installert. Kjor 1_INSTALLER.bat forst.",
            file=sys.stderr,
        )
        return 1

    argumenter = sys.argv[1:] or ["build"]
    resultat = dbtRunner().invoke(argumenter)

    if not resultat.success:
        if resultat.exception is not None:
            print(f"\nFEIL: {resultat.exception}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
