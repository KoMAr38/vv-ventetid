# data/manuell/

NKI-eksporten fra Helsedirektoratet legges her.

Se `powerbi/STEG_FOR_STEG.md` del 0.2 for filtervalg og eksportfremgangsmåte.

Fila `MAL_nki_eksport.csv` er en **strukturmal**, ikke data. Den finnes for at
pipelinen skal kunne testes før man har lastet ned noe. Alle tallfelt inneholder
999 slik at den aldri kan forveksles med et resultat, og
`stg_nki_indikator.sql` filtrerer den eksplisitt bort.

Kjør alltid valideringen før `dbt build`:

    python src/valider_nki.py data/manuell/nki_eksport.csv
