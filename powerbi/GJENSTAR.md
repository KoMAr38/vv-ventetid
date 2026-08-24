# Gjenstår før publisering

Denne lista holder oversikt over kjente svakheter og utsatt arbeid i
prosjektet. Den er bevisst en del av repoet, ikke en privat huskeliste:
et repo uten en slik oversikt ser enten ferdig ut når det ikke er det,
eller uferdig uten forklaring.

Oppdatert: 24. august 2026

---

## Modell

### Sorteringskolonner i `dim_periode`

`dim_periode` mangler kolonnene `sortering` og `sortering_i_fjor`.

Sortering på x-aksen fungerer i dag fordi datagrunnlaget bare inneholder
tertial 3, og `2021 T3 < 2022 T3 < 2023 T3` er alfabetisk og kronologisk
samtidig. Dersom kilden senere publiserer T1 og T2, vil `2023 T1` sorteres
foran `2022 T3`, og kurvene blir feil uten at noe feiler.

**Tiltak:** legg til begge kolonner i `dbt/models/marts/dim_periode.sql`,
sett `Sort by column` på `periode_etikett` i modellen.

### Advarsel i dbt-bygget

`3_VALIDER_NKI.bat` gir fortsatt `WARN 1` for 7 enheter som er kommuner,
legevakter eller lignende, og som ikke står i `enhet_mapping.csv`.

Advarselen er forventet og blokkerer ingenting, men et bygg som alltid
advarer er et bygg der advarslene slutter å bli lest.

**Tiltak:** enten legg enhetene inn i seed-fila, eller filtrer dem eksplisitt
i staging-laget med en kommentar som sier hvorfor.

---

## Rapportside «Utvikling»

### Statisk undertittel

Undertittelen sier `Gjennomsnittlig ventetid, tertial 3`, men indikator
velges med filter. Velger leseren en annen indikator, står det feil tekst
under tittelen.

**Tiltak:** lag et mål og bind undertittelen til det med betinget
formatering (`Subtitle > fx > Field value`):

```dax
Undertittel Utvikling =
"Indikator: "
    & SELECTEDVALUE ( dim_indikator[indikator_navn], "flere valgt" )
    & ". Stiplet linje viser nasjonalt mål."
```

---

## Beregningsgruppa `Analyse`

### Stavker fjernet 24.08

`I fjor`, `Endring` og `Endring %` er slettet. De refererte kolonnene
`dim_periode[sortering]` og `dim_periode[sortering_i_fjor]`, som ikke
finnes i modellen. Uttrykkene returnerte tomt uten feilmelding.

Igjen står `Verdi` (identitet) og `Mot landet`.

### Beregningsgruppe mot field parameter

Slicer for `Analyse` er fjernet fra siden «Utvikling». Y-aksen der er
field parameteren `Valgt måltall`, og en beregningsgruppe griper ikke inn
i en field parameter slik den griper inn i et vanlig mål — `Målverdi` ble
transformert, `Valgt måltall` ble det ikke.

**Tiltak:** plasser sliceren på «Sammenligning», der aksen bruker et vanlig
mål. Beregningsgruppa blir da en reell andre valgdimensjon i stedet for en
kontroll som ser ut til å virke uten å gjøre det.

---

## Til slutt

- [ ] Les gjennom `dokumentasjon/forbehold.md` mot ferdig rapport og sjekk
      at alle ni forbehold er dekket et sted i rapporten
- [ ] Rydd bort midlertidige visualiseringer brukt til kontroll
- [ ] Siste `git status` skal være ren før repoet gjøres offentlig
