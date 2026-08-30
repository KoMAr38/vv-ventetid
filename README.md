# Fjordhelse — datakvalitet i et fagsystem

**Fire av ti fristbrudd finnes ikke.**

Rapportert andel fristbrudd i Fjordhelse HF er 24,1 %. Etter kvalitetssikring av registreringsdataene er den 14,4 %. Forskjellen — 9,7 prosentpoeng, 42 489 henvisninger — er registreringspraksis, ikke ventetid.

Rangeringen mellom enhetene snur nesten fullstendig. TSB går fra å være verst (32,6 %) til å være best (14,2 %). Onkologi går fra best (16,5 %) til å ligge på nivå med de dårligste (14,5 %). En styringsbeslutning tatt på det rapporterte tallet ville pekt på feil enhet.

![Oversikt](docs/bilder/side0_oversikt.png)

---

## Hva dette er

Et porteføljeprosjekt som viser hele kjeden fra rådata til styringsinformasjon: syntetisk datagenerering, transformasjon i dbt, testing, semantisk modell og rapport i Power BI.

Dataene er syntetiske. Det finnes ingen pasienter bak radene, og Fjordhelse HF finnes ikke. Feilene i datasettet er lagt inn med vilje og i kjent omfang, slik at analysen kan kontrolleres mot en fasit.

**Dette er ikke en analyse av et virkelig foretak.** Tallene er konstruert for å vise en mekanisme, ikke for å beskrive en tilstand.

---

## Problemstillingen

Et fagsystem inneholder 426 484 henvisninger fordelt på åtte enheter over perioden 2022–2025. Uttrekksdato er 15.01.2026.

Seks feiltyper er lagt inn i registreringen:

| Feiltype | Hva den gjør |
|---|---|
| Duplikater | Samme henvisning registrert flere ganger |
| Manglende sluttdato | Forløpet er avsluttet, men `ventetid_slutt` er aldri registrert |
| Prioritet ikke vurdert | Feltet står på systemets standardverdi |
| Avvikende enhetsnavn | Samme enhet skrevet på flere måter |
| Tvetydig diagnosekode | Kode som har byttet betydning i kodeverket |
| Årsskifte | Forløp som krysser årsskiftet og telles i feil periode |

Spørsmålet rapporten svarer på: **hvor mye av det rapporterte fristbruddet skyldes faktisk ventetid, og hvor mye skyldes hvordan det er registrert?**

---

## Metode

### Definisjon av kvalitetssikret fristbrudd

Duplikater fjernes. En henvisning uten registrert sluttdato regnes ikke som fristbrudd dersom det finnes et registreringstidspunkt før fristen.

Definisjonen er bevisst konservativ. Den krever bevis for kontakt før fristen, ikke fravær av bevis for det motsatte. Den fanger derfor ikke opp forløp der all registrering uteble — de teller fortsatt som fristbrudd.

### Kontroll mot fasit

`data/raw/fasit.json` inneholder det faktiske antallet innlagte feil per type, sammen med `sha256` av datafila. Analysen leser aldri fasiten. Den gjenskaper feilratene fra dataene alene, og resultatet sammenlignes med fasiten etterpå.

Det er kontrollen på at metoden virker — ikke at tallene er pene.

---

## Resultater

| Enhet | Rapportert | Kvalitetssikret | Differanse |
|---|---:|---:|---:|
| TSB | 32,6 % | 14,2 % | 18,4 pp |
| BUP | 30,7 % | 14,3 % | 16,4 pp |
| Rehabilitering | 26,0 % | 14,3 % | 11,7 pp |
| DPS | 23,5 % | 14,5 % | 9,0 pp |
| Medisin | 21,9 % | 14,4 % | 7,5 pp |
| Ortopedi | 21,2 % | 14,4 % | 6,8 pp |
| Kirurgi | 20,7 % | 14,5 % | 6,2 pp |
| Onkologi | 16,5 % | 14,5 % | 2,0 pp |
| **Totalt** | **24,1 %** | **14,4 %** | **9,7 pp** |

Etter kvalitetssikring ligger samtlige enheter mellom 14,2 og 14,5 prosent. Spredningen mellom beste og dårligste enhet faller fra 16,1 til 0,3 prosentpoeng. Nesten hele forskjellen som styringstallet viste, var registreringspraksis.

De psykiske helsevernenhetene (TSB, BUP, DPS) og rehabilitering har lengst forløp og flest kontaktpunkter per pasient, og dermed flest anledninger til at en sluttregistrering uteblir. Onkologi har korte, tett oppfulgte forløp og nesten ingen avvik.

![Fristbrudd per enhet](docs/bilder/side1_fristbrudd.png)

---

## Teknisk oppbygning

```
data/raw/          syntetisk datasett + fasit.json
dbt/               staging → intermediate → marts
data/mart/         parquet + csv, klar for Power BI
powerbi/           .pbip-prosjekt og tema.json
docs/bilder/       skjermbilder av rapporten
dokumentasjon/     funn og anbefalinger
```

### Stack

Python for datagenerering, dbt med DuckDB for transformasjon, Power BI Desktop i `.pbip`-format for rapport. Alt versjonskontrollert som tekst — også den semantiske modellen, som ligger i TMDL og dermed kan leses i en diff.

### Datamodell

Stjerneskjema med to faktatabeller på ulik granularitet:

- `fact_henvisning` — én rad per henvisning (426 484 rader)
- `fact_datakvalitet` — aggregert per enhet, måned og kvalitetsdimensjon

Dimensjoner: `dim_enhet`, `dim_periode`, `dim_diagnose`, `dim_dato`.

**To datotabeller.** `dim_periode` betjener `fact_datakvalitet`, som er aggregert per måned. `dim_dato` er en daglig, sammenhengende kalender (1 461 rader, 2022–2025) markert som date table, og betjener `fact_henvisning` på `henvisning_mottatt`. Tidsintelligens krever daglig granularitet — en månedstabell er ikke sammenhengende, og `SAMEPERIODLASTYEAR` returnerer tomt mot den.

`dim_diagnose` er bevisst frakoblet. `diagnose_kode` er ikke unik: koden R51 finnes to ganger, gyldig til 30.06.2024 som «Hodepine» og fra 01.07.2024 som «Hodepine, uspesifisert». Oppslaget gjøres i dbt på kode *og* dato, ikke i den semantiske modellen.

### Testing

41 dbt-tester kjører ved hver build. I tillegg til generiske tester på nøkler og nullverdier finnes fire domenespesifikke:

- `assert_alle_enheter_har_data` — ingen enhet forsvinner ut av datasettet
- `assert_ett_forlop_per_pasient_og_frist` — ingen dupliserte forløp etter deduplisering
- `assert_kvalitetssikring_reduserer_fristbrudd` — kvalitetssikret tall er aldri høyere enn rapportert
- `assert_ventetid_ikke_negativ` — sluttdato kommer aldri før startdato

### Semantisk modell

Målene ligger i en egen tabell `_Mål`. Utvalgte definisjoner:

**Andel avvik** — andeler kan ikke summeres. Målet deler summert teller på summert nevner:

```dax
Andel avvik =
DIVIDE (
    SUM ( fact_datakvalitet[antall_avvik] ),
    SUM ( fact_datakvalitet[antall_rader] )
)
```

**Simulering** — en what-if-parameter (0–100 %, steg 5 %) lar leseren stille spørsmålet «hva om sluttregistreringen forbedres?»:

```dax
Andel fristbrudd rapportert simulert =
VAR Forbedring = [Forbedring i registrering Value]
VAR IkkeReelle = [Fristbrudd rapportert] - [Fristbrudd kvalitetssikret]
VAR NyeFristbrudd = [Fristbrudd rapportert] - ( IkkeReelle * Forbedring )
RETURN
DIVIDE ( NyeFristbrudd, [Antall henvisninger] )
```

Parameteren endrer ikke dataene. Den endrer forutsetningen målet regner med. Ved 0 % gir målet 24,1 %, ved 100 % gir det 14,4 % — grensene faller ut av logikken, de er ikke hardkodet.

---

## Rapporten

Fire sider:

| Side | Innhold |
|---|---|
| **Oversikt** | KPI-fliser med endring mot i fjor, sparklines per enhet, what-if-simulering |
| **Fristbrudd** | Rangering per enhet, før og etter kvalitetssikring |
| **Datakvalitet** | Matrise over seks feiltyper, tidsserie for manglende sluttregistrering |
| **Metode og forbehold** | Definisjoner, datagrunnlag, begrensninger |

![Datakvalitet](docs/bilder/side2_datakvalitet.png)

Mørkt tema definert i `powerbi/tema.json`. Blå er alltid rapportert, grønn er alltid kvalitetssikret, rød er forbeholdt avvik. Fargene betyr det samme på alle fire sidene.

---

## Kjøre prosjektet

```
1_INSTALLER.bat
2_BYGG.bat
```

Første fil installerer avhengigheter, andre genererer data og kjører hele dbt-pipelinen. Forventet resultat: `Done. PASS=41 WARN=0 ERROR=0 SKIP=0`.

Åpne deretter `powerbi/Fjordhelse_Datakvalitet.pbip`. Rapporten er ferdig bygget og ligger i repoet som TMDL og JSON — sider, mål og visualer følger med. Den eneste tilpasningen som kan trengs er parameteren `MartMappe` i Power Query, som må peke til `data/mart/` med skråstrek på slutten.

`powerbi/STEG_FOR_STEG.md` er ikke nødvendig for å bruke rapporten. Den er en logg over hvordan den ble bygget og hvorfor hvert valg ble tatt.

Krever Python 3.10+ og Power BI Desktop med `.pbip`-format aktivert under Preview features.

---

## Fire feil som formet prosjektet

Dokumentert fordi de er mer opplysende enn det som gikk bra.

**`date_trunc` returnerer timestamp.** I DuckDB gir `date_trunc('month', d)` en timestamp, mens `cast(d as date)` gir en date. Samme kolonnenavn i to tabeller, to ulike typer, og relasjonen lar seg ikke opprette. Løses med to trinn i Power Query: Date/Time først, deretter Date.

**Summerte andeler.** `andel_avvik_pst` summert over måneder ga 26 744 %. Andeler er ikke additive. Et mål må regne fra teller og nevner, ikke fra ferdig beregnede andeler.

**Høyrekutting.** Tidsserien for manglende sluttregistrering steg mot 100 % gjennom høsten 2025. Ingen dbt-test fanget det, fordi dataene er korrekte: forløp mottatt sent er ikke ferdige på uttrekksdatoen. Manglende sluttdato er der reell, ikke en registreringsfeil. Tidsserien er derfor avgrenset til juni 2025, med det opplyst i undertittelen.

En test kontrollerer at dataene er som forventet. En graf viser hva de faktisk betyr. Denne feilen kunne bare oppdages visuelt.

**`DATESINPERIOD` fra månedsslutt.** `DATESINPERIOD(dim_dato[Date], DATE(2025,6,30), -1, MONTH)` returnerer 31.05–30.06 — altså én dag fra mai. Undertittelen sa «juni 2025». Erstattet med et filter på `maned_start`, som gir nøyaktig den måneden det står at det er.

---

## Forbehold

Med ekte data ville `registrert_tidspunkt` alene ikke vært godt nok bevis på pasientkontakt. Et fagsystem har flere spor — kontaktregistreringer, notater, prosedyrekoder — og en reell kvalitetssikring bør bruke dem samlet.

Sammenligningen mot samme måned i fjor er tatt med for å vise tidsintelligens i modellen. På et syntetisk datasett med fast seed er den bevegelsen støy, ikke et funn.

Definisjonen av kvalitetssikret fristbrudd er ett av flere mulige valg. Den er dokumentert i rapportens metodeside slik at den kan bestrides.

![Metode og forbehold](docs/bilder/side3_metode.png)

---

## Videre lesning

`dokumentasjon/funn_og_anbefalinger.md` — utfyllende gjennomgang av funnene og hva de ville betydd i en reell styringssammenheng.
