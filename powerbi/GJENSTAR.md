# Gjenstår før publisering

Denne lista holder oversikt over kjente svakheter og utsatt arbeid i
prosjektet. Den er bevisst en del av repoet, ikke en privat huskeliste:
et repo uten en slik oversikt ser enten ferdig ut når det ikke er det,
eller uferdig uten forklaring.

Oppdatert: 24. august 2026

---

## Datagrunnlag

### `Landet` mangler i NKI-eksporten

`dim_enhet` har raden `Landet` med `enhet_niva = Nasjonalt`, men
`fact_indikator` har ingen rader for `Landet` på NKI-indikatorene.
NPR-indikatorene har nasjonalt nivå — det var mot dem kontrolltallene
1 654 620 og 1 614 030 ble validert. NKI-eksporten fra Helsedirektoratet
ble hentet på helseforetaksnivå uten den nasjonale raden.

**Konsekvens:** målene `Verdi nasjonalt` og `Avvik fra nasjonalt` returnerer
tomt for alle NKI-indikatorer. `Avvik fra nasjonalt` er derfor fjernet fra
field parameteren `Valgt måltall`, og siden «Sammenligning» bruker et snitt
av foretakene i stedet — merket `Snitt foretak`, ikke `Landet`, fordi et
uvektet snitt av foretak ikke er det samme som et nasjonalt tall.

**Tiltak:** hent NKI-eksporten på nytt med nasjonalt nivå inkludert, eller
beregn nasjonalt nivå vektet med `Antall målinger` i marts-laget.

### `er_prikket` settes aldri

`Antall prikkede` og `Andel prikket` er tomme for alle 19 212 målinger.
Kilden skjuler tall der pasientgrunnlaget er under 5, så noen rader skal
være merket. Sannsynlig årsak: skjulte verdier leses som null og filtreres
bort i staging i stedet for å beholdes med `er_prikket = true`.

**Konsekvens:** rapporten kan ikke svare på hvor mye av grunnlaget som er
borte. Det var hele poenget med å beholde prikkede rader i modellen.

**Tiltak:** sjekk hvordan kilden markerer skjulte verdier, og sett flagget i
`stg_nki_indikator.sql` / `stg_npr_nokkeltall.sql`.

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
Advarselen er forventet, men et bygg som alltid advarer er et bygg der
advarslene slutter å bli lest.

**Tiltak:** legg enhetene inn i seed-fila, eller filtrer dem eksplisitt i
staging med en kommentar som sier hvorfor.

---

## Beregningsgruppa `Analyse`

### Stavker fjernet 24.08

`I fjor`, `Endring` og `Endring %` er slettet. De refererte kolonnene
`dim_periode[sortering]` og `dim_periode[sortering_i_fjor]`, som ikke finnes
i modellen. Uttrykkene returnerte tomt uten feilmelding. Igjen står `Verdi`
(identitet) og `Mot landet`.

### Beregningsgruppe mot field parameter

Sliceren for `Analyse` er fjernet fra siden «Utvikling». En beregningsgruppe
griper ikke inn i en field parameter slik den griper inn i et vanlig mål:
`Målverdi` ble transformert, `Valgt måltall` ble det ikke.

Merk også at manuelt skrevet DAX for en field parameter mister unntaket fra
`discourage implicit measures`. Field parametere må lages via
**Modeling → New parameter → Fields**, ikke ved å skrive uttrykket selv.

**Tiltak:** plasser sliceren på en side der aksen bruker et vanlig mål, når
`Mot landet` igjen har data å regne på.

---

## Rapportside «Utvikling»

### Statisk undertittel

Undertittelen sier `Gjennomsnittlig ventetid, tertial 3`, men indikator velges
med filter. Velger leseren en annen indikator, står det feil tekst.

**Tiltak:** lag et mål og bind undertittelen til det med betinget formatering
(`Subtitle > fx > Field value`):

```dax
Undertittel Utvikling =
"Indikator: "
    & SELECTEDVALUE ( dim_indikator[indikator_navn], "flere valgt" )
    & ". Stiplet linje viser nasjonalt mål."
```

---

## Til slutt

- [ ] Tema lagret som `powerbi/tema.json`
- [ ] Skjermbilde per side i `docs/bilder/`, lenket inn i README
- [ ] Navigasjonsikon til «Metode» fra de tre andre sidene
- [ ] Les `dokumentasjon/forbehold.md` mot ferdig rapport og sjekk at alle ni
      forbehold er dekket et sted
- [ ] Siste `git status` skal være ren før repoet gjøres offentlig
