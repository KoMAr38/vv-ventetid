# Byggelogg for rapporten

**Dette er ikke nødvendig for å bruke prosjektet.** Rapporten ligger ferdig i
`VV_Styringsdashboard.pbip` — sider, mål, relasjoner, beregningsgruppe og
radnivåsikkerhet er versjonert som TMDL og JSON. Åpne fila, og alt er der.

Dokumentet er en logg: hva som ble gjort, i hvilken rekkefølge, og hvorfor hvert
valg som ikke var åpenbart ble tatt. Kontrollpunktene underveis er de faktiske
tallene modellen skal gi, og kan brukes til å verifisere at et nytt uttrekk fra
FHI gir samme resultat.

Menyvalg står på norsk med engelsk i parentes, siden Power BI Desktop bruker
språket i Windows-installasjonen.

Bygging fra bunnen tar fire økter. Commit til Git etter hver del —
commit-historikken er en del av leveransen, ikke administrasjon.

---

# DEL 0 — Før du åpner Power BI

## 0.1 Kjør pipelinen

Har du ikke gjort dette ennå: se **`START_HER.md`** først. Den tar deg gjennom
installasjon av Python og de andre programmene.

Dobbeltklikk `1_INSTALLER.bat`, deretter `2_HENT_DATA.bat`.

Alle 51 tester skal være grønne. Er de ikke det, ikke gå videre — en modell
bygget på et datagrunnlag som feiler tester blir feil uansett hvor pen den blir.

## 0.2 Last ned NKI-eksporten

Uten denne har du bare region- og landsnivå. Ingen helseforetak, ingen ventetid,
ingen fristbrudd, og `bro_enhet_rls` blir tom.

Egen guide med lenke og klikk for klikk: **`powerbi/NKI_EKSPORT.md`**.

Kort versjon: last ned fra Helsedirektoratets eksportvisning med filtrene
Sektor = Spesialisthelsetjenesten og Nivå = Helseforetak, legg CSV-fila i
`data\manuell\`, og dobbeltklikk `3_VALIDER_NKI.bat`.

## 0.3 Fyll inn målverdier

Åpne `dbt/models/marts/dim_indikator.sql` og erstatt
`cast(null as double) as malverdi` med en `case`-blokk. Ikke gjett tallene —
hent dem fra oppdragsdokumentet til de regionale helseforetakene og skriv
kilden inn i `dokumentasjon/maaltall.md`.

Kjør `dbt build` og `eksporter_mart.py` på nytt etterpå.

## 0.4 Slå på .pbip

**Fil > Alternativer og innstillinger > Alternativer > Forhåndsvisningsfunksjoner**
(File > Options and settings > Options > Preview features)

Kryss av:

- **Power BI-prosjekt (.pbip) lagringsformat**
- **Lagre semantisk modell med TMDL-format**

Start Power BI Desktop på nytt. Uten dette blir alt liggende i en binærfil, og
hele Git-argumentet i prosjektet faller bort.

## 0.5 Installer Tabular Editor 2

Gratisversjonen holder. Trengs til beregningsgruppen i Del 7.

Etter installasjon: **Eksterne verktøy** (External Tools) i båndet i Power BI.

---

# DEL 1 — Opprett prosjektet

1. Ny tom fil i Power BI Desktop
2. **Fil > Lagre som > Bla gjennom denne enheten**
3. Velg filtype **Power BI-prosjektfil (.pbip)**
4. Lagre i `powerbi/` med navnet `VV_Styringsdashboard`

Du skal nå se denne strukturen på disk:

```
powerbi/
  VV_Styringsdashboard.pbip
  VV_Styringsdashboard.Report/
  VV_Styringsdashboard.SemanticModel/
    definition/
      tables/          <- .tmdl-filer, lesbar tekst
      relationships.tmdl
```

**Commit 1:**

```bash
git add . && git commit -m "Opprett Power BI-prosjekt i pbip-format"
```

---

# DEL 2 — Hent data

## 2.1 Parameter

**Hjem > Transformer data** (Home > Transform data) åpner Power Query.

**Hjem > Behandle parametere > Ny parameter**:

| Felt | Verdi |
|---|---|
| Navn | `MartMappe` |
| Type | Tekst |
| Foreslått verdi | Enhver verdi |
| Gjeldende verdi | din absolutte bane til `data\mart\` |

Husk bakstrek til slutt.

## 2.2 Funksjonen `fnLesMart`

**Hjem > Ny kilde > Tom spørring**, deretter høyreklikk spørringen >
**Avansert redigering**. Lim inn koden fra `m_queries.md`. Gi den navnet
`fnLesMart`.

## 2.3 De seks tabellene

For hver av `dim_enhet`, `dim_periode`, `dim_indikator`,
`dim_tjenesteomrade`, `fact_indikator`, `bro_enhet_rls`:

- Ny tom spørring → Avansert redigering → lim inn M-koden fra `m_queries.md`
- Gi spørringen samme navn som tabellen

Lag deretter `_Mål` med den tomme tabellkoden.

## 2.4 Rydd før innlasting

- Legg `fnLesMart` og `MartMappe` i en mappe som heter `_Hjelp`
  (høyreklikk > Flytt til gruppe)
- Høyreklikk `fnLesMart` og `MartMappe` > fjern haken på **Aktiver innlasting**
  (Enable load). De skal ikke bli tabeller i modellen.

**Hjem > Lukk og bruk.**

> Får du feilen «Vi fant ikke fila»: banen i `MartMappe` mangler bakstrek til
> slutt, eller du har brukt relativ bane. Power Query krever absolutt bane.

**Commit 2:** `git commit -am "Hent mart-tabeller via Power Query"`

---

# DEL 3 — Kolonneegenskaper

Gjøres i **Modellvisning** (Model view, ikonet nederst til venstre).
Marker en kolonne og bruk ruten **Egenskaper** til høyre.

## 3.1 Skjul nøkler

Skjul alle disse i rapportvisning (høyreklikk > Skjul i rapportvisning):

```
fact_indikator:  enhet_id, periode_id, indikator_id, tjenesteomrade_id
dim_enhet:       enhet_id, niva_nr, er_umappet, er_referanse, er_eget_foretak
dim_periode:     periode_id, sortering, sortering_i_fjor, periode_nr
dim_indikator:   indikator_id
dim_tjenesteomrade: tjenesteomrade_id
bro_enhet_rls:   alle kolonner
```

Hele tabellen `bro_enhet_rls` skjules: høyreklikk tabellnavnet > **Skjul**.

En feltliste som viser tekniske nøkler er ubrukelig for den som skal lage sine
egne analyser. Dette er ikke kosmetikk — det er forskjellen på en modell noen
andre kan bruke og en modell bare du kan bruke.

## 3.2 Sorteringskolonner

Uten dette sorteres perioder alfabetisk, og «2026 jan-apr» havner før
«2025 jan-aug».

| Kolonne | Sorter etter kolonne |
|---|---|
| `dim_periode[periode_etikett]` | `dim_periode[sortering]` |
| `dim_periode[periode_navn]` | `dim_periode[periode_nr]` |
| `dim_enhet[enhet_navn]` | `dim_enhet[niva_nr]` |

Marker kolonnen > **Kolonneverktøy > Sorter etter kolonne**
(Column tools > Sort by column).

## 3.3 Sammendrag av tallkolonner

Marker `fact_indikator[verdi]` > **Kolonneverktøy > Sammendrag > Ikke summer**
(Summarization > Don't summarize).

Marker `dim_indikator[malverdi]` > samme.

Grunnen: så lenge en tallkolonne har implisitt aggregering, kan noen dra den
rett inn i en figur og få et tall som ikke går gjennom målene dine — altså uten
riktig aggregering per indikatortype og uten forbeholdene.

## 3.4 Beskrivelser

Skriv en `Description` på hver synlige kolonne. Minst disse:

| Kolonne | Beskrivelse |
|---|---|
| `dim_periode[er_kumulativ]` | Sann for NPR-perioder som er kumulative fra januar. Kumulative perioder kan ikke summeres med hverandre. |
| `dim_indikator[retning]` | Om en høy eller lav verdi er ønskelig. Styrer fargelegging av avvik mot mål. |
| `dim_indikator[malverdi]` | Nasjonalt styringsmål. Tom der indikatoren ikke har et vedtatt mål. |
| `fact_indikator[er_prikket]` | Sann når kilden har skjult tallet fordi pasientgrunnlaget er under 5. |
| `fact_indikator[datakilde]` | NPR eller NKI. De to beregner fristbrudd ulikt og skal ikke blandes i samme figur. |
| `dim_enhet[enhet_niva]` | Nasjonalt, Region eller Helseforetak. |

Dette er det du blir spurt om på intervju når de sier «hvordan gjør du en modell
selvbetjent».

## 3.5 Display folders

Marker flere kolonner samtidig og sett feltet **Vis mappe** (Display folder):

- `dim_periode`: `Tid` for `aar`, `periode_navn`, `periode_etikett`, `periodetype`
- `dim_indikator`: `Klassifisering` for `enhet`, `retning`, `indikatorgruppe`
- `dim_enhet`: `Hierarki` for `enhet_niva`, `forelder_navn`

## 3.6 Hierarki

Høyreklikk `dim_enhet[enhet_niva]` > **Opprett hierarki**. Kall det
`Enhetshierarki`. Dra `enhet_navn` inn under.

**Commit 3:** `git commit -am "Kolonneegenskaper, sortering, beskrivelser"`

---

# DEL 4 — Relasjoner

Power BI gjetter noen relasjoner ved innlasting. Slett alle først:
**Modellvisning > Behandle relasjoner > marker alt > Slett.**

Opprett så disse fem manuelt:

| Fra | Til | Kardinalitet | Kryssfilter | Aktiv |
|---|---|---|---|---|
| `dim_enhet[enhet_id]` | `fact_indikator[enhet_id]` | Én til mange | Enkel | Ja |
| `dim_periode[periode_id]` | `fact_indikator[periode_id]` | Én til mange | Enkel | Ja |
| `dim_indikator[indikator_id]` | `fact_indikator[indikator_id]` | Én til mange | Enkel | Ja |
| `dim_tjenesteomrade[tjenesteomrade_id]` | `fact_indikator[tjenesteomrade_id]` | Én til mange | Enkel | Ja |
| `bro_enhet_rls[enhet_id]` | `dim_enhet[enhet_id]` | Mange til én | **Enkel** | Ja |

**Ingen toveisrelasjoner.** Hvis Power BI foreslår «Begge» på den siste, sett den
til Enkel. Toveis på en RLS-brotabell åpner en sti der filteret kan gå tilbake og
oppheve sikkerheten.

Kontroll: modelldiagrammet skal se ut som en stjerne med `fact_indikator` i
midten, og `bro_enhet_rls` hengende utenpå `dim_enhet`.

**Commit 4:** `git commit -am "Relasjoner - stjerneskjema uten toveisfiltre"`

---

# DEL 5 — Målene

Marker tabellen `_Mål` i feltlista før du lager hvert mål, ellers havner de i
faktatabellen.

**Hjem > Nytt mål**, lim inn fra `DAX_maal.md`, i denne rekkefølgen:

1. `Verdi`
2. `Antall målinger`
3. `Antall prikkede`
4. `Andel prikket`
5. `Verdi (riktig aggregert)`
6. `Verdi i fjor`
7. `Endring år over år`
8. `Endring år over år %`
9. `Målverdi`
10. `Avvik mot mål`
11. `Status mot mål`
12. `Farge status`
13. `Verdi nasjonalt`
14. `Avvik fra nasjonalt`
15. `Sist oppdatert`
16. `Kildehenvisning`
17. `Forbehold aktiv periode`

Rekkefølgen er ikke tilfeldig — mål 6 og utover bygger på mål 5.

## 5.1 Format

Marker målet > **Målverktøy** (Measure tools):

| Mål | Format |
|---|---|
| `Verdi`, `Verdi (riktig aggregert)`, `Verdi i fjor`, `Verdi nasjonalt` | Desimaltall, 0 desimaler, tusenskille på |
| `Endring år over år %`, `Andel prikket` | Prosent, 1 desimal |
| `Avvik mot mål`, `Avvik fra nasjonalt` | Desimaltall, 1 desimal |

## 5.2 Beskrivelser

Lim inn `Description` fra `DAX_maal.md` på hvert mål. Ikke hopp over dette.
Et mål uten beskrivelse er et mål bare du forstår, og da er ikke modellen
selvbetjent uansett hvor riktig DAX-en er.

## 5.3 Test målene

Lag en midlertidig tabellfigur med:

- `dim_periode[periode_etikett]` i rader
- `Verdi (riktig aggregert)`, `Verdi i fjor`, `Endring år over år`

Filtrer på `dim_indikator[indikator_kode] = ANT_PAS`,
`dim_tjenesteomrade[tjenesteomrade_kode] = SOM`,
`dim_enhet[enhet_navn] = Landet`, `aktor_navn = Alle aktører`.

Du skal se **1 654 620** for 2025 jan-apr og **1 614 030** for 2026 jan-apr.
Stemmer ikke det, er noe galt med relasjonene — ikke med DAX-en.

Slett figuren etterpå.

**Commit 5:** `git commit -am "DAX-mål med beskrivelser"`

---

# DEL 6 — Field parameters

Lar brukeren bytte indikator uten at du lager en figur per indikator.

**Modellering > Ny parameter > Felt**
(Modeling > New parameter > Fields)

- Navn: `Valgt måltall`
- Dra inn: `Verdi (riktig aggregert)`, `Endring år over år`,
  `Endring år over år %`, `Avvik mot mål`, `Avvik fra nasjonalt`
- Kryss av **Legg til slicer på denne siden**

Lag én til:

- Navn: `Valgt nivå`
- Dra inn: `dim_enhet[enhet_navn]`, `dim_enhet[enhet_niva]`,
  `dim_tjenesteomrade[tjenesteomrade_navn]`, `dim_periode[aar]`

**Commit 6:** `git commit -am "Field parameters"`

---

# DEL 7 — Beregningsgruppe

Power BI Desktop kan ikke lage disse. Bruk Tabular Editor.

1. **Eksterne verktøy > Tabular Editor**
2. Høyreklikk `Tables` > **Create New > Calculation Group**
3. Gi den navnet `Analyse`
4. Marker kolonnen under gruppen, sett `Name` til `Analyse`
5. Høyreklikk `Calculation Items` > **New Calculation Item** for hver rad i
   tabellen i `DAX_maal.md` avsnitt 7
6. Sett `Ordinal` slik tabellen viser — uten det sorteres elementene alfabetisk
7. På elementet `Endring %`: sett `Format String Expression` til `"0.0 %"`
8. **Fil > Lagre** i Tabular Editor
9. Tilbake i Power BI: **Hjem > Oppdater**

Kontroll: dra `Analyse[Analyse]` inn i en slicer. Nå skal én og samme figur kunne
vise verdi, endring eller avvik uten at figuren endres.

> Faller alt til tomt når du velger et element: du har mest sannsynlig satt
> `Ordinal` som tekst i stedet for tall, eller glemt å lagre i Tabular Editor.

**Commit 7:** `git commit -am "Beregningsgruppe Analyse"`

---

# DEL 8 — Radnivåsikkerhet

Gjør dette **etter** at NKI-eksporten er inne. Uten helseforetak i `dim_enhet`
er `bro_enhet_rls` tom, og rollen filtrerer bort alt.

**Modellering > Håndter roller** (Modeling > Manage roles).

**Rolle 1 — `HF-leder`**

Tabell `bro_enhet_rls`, DAX-uttrykk:

```dax
[brukerprinsipal] = USERPRINCIPALNAME ()
```

**Rolle 2 — `Analytiker`**

Opprett rollen, ikke sett noe filter. Ser alt.

## Test

**Modellering > Vis som** (View as) > kryss av **Andre bruker** og skriv inn en
av e-postadressene fra `data/mart/bro_enhet_rls.csv`, for eksempel
`vestre.viken.hf@eksempel.no`. Velg samtidig rollen `HF-leder`.

Du skal nå se:

- Vestre Viken HF med fulle tall
- Landet og Helse Sør-Øst RHF som referanse
- **ingen** andre helseforetak

Ser du andre foretak, er kryssfiltreringen på relasjonen satt til Begge.

**Commit 8:** `git commit -am "Radnivåsikkerhet med referansetilgang"`

---

# DEL 9 — Rapportsidene

Fire sider. Hver side svarer på ett spørsmål. En side som svarer på tre
spørsmål svarer i praksis på null.

## Felles oppsett

- Sidestørrelse 16:9, 1280×720
- Bunntekst på alle sider: kortvisning (Card) med `Kildehenvisning`, skriftstørrelse 8
- Øverst til høyre på alle sider: kortvisning med `Sist oppdatert`
- Slicere øverst: `dim_tjenesteomrade[tjenesteomrade_navn]`,
  `dim_periode[periodetype]`, `dim_periode[aar]`
- Synkroniser slicerne på tvers av sidene:
  **Vis > Synkroniser slicere**, kryss av alle fire sidene

`periodetype`-sliceren settes til **Enkelt valg** (Single select) og
standardverdi `Kumulativ`. Det er den viktigste sliceren i rapporten — den
hindrer at kumulative perioder blandes med tertialer.

---

## Side 1 — «Status»

Spørsmålet: *hvor ligger vi an akkurat nå?*

| Element | Innhold |
|---|---|
| 4 KPI-kort øverst | `Verdi (riktig aggregert)` per tjenesteområde, med `Farge status` som betinget bakgrunn |
| Tekstboks under kortene | målet `Forbehold aktiv periode` |
| Matrise venstre | rader: `dim_indikator[indikator_navn]`, verdier: `Verdi (riktig aggregert)`, `Målverdi`, `Avvik mot mål`, `Status mot mål` |
| KPI-kort høyre | `Andel prikket` — synlig, ikke gjemt |

Betinget formatering på `Avvik mot mål` i matrisen:
**Format > Celleelementer > Skriftfarge > fx > Formatstil: Feltverdi >
basert på felt: `Farge status`**

## Side 2 — «Utvikling»

Spørsmålet: *går det riktig vei?*

| Element | Innhold |
|---|---|
| Linjediagram, stor | X: `dim_periode[periode_etikett]`, Y: `Valgt måltall`, forklaring: `dim_enhet[enhet_navn]` |
| Konstantlinje | `Målverdi` — **Analyse > Konstantlinje > fx > Målverdi** |
| Slicer | `Analyse[Analyse]` fra beregningsgruppen |
| Tekstboks | statisk merknad: «Tall for Helse Midt-Norge 2022–2024 er beheftet med usikkerhet på grunn av nytt journalsystem. 2020 er ikke sammenlignbart.» |

Sett X-aksen til å sortere etter `dim_periode[sortering]`.

## Side 3 — «Sammenligning»

Spørsmålet: *skiller vi oss fra andre?*

| Element | Innhold |
|---|---|
| Stolpediagram, liggende | Y: `dim_enhet[kortnavn]`, X: `Valgt måltall`, sortert synkende |
| Konstantlinje | `Verdi nasjonalt` |
| Spredningsdiagram | X: `Verdi (riktig aggregert)`, Y: `Endring år over år %`, detalj: `dim_enhet[enhet_navn]` |
| Tekstboks, tydelig | «Forskjeller mellom foretak kan skyldes ulik registreringspraksis, ikke bare ulik tjeneste. Se Metode.» |

Denne siden er den farligste i rapporten. Uten forbeholdet blir den lest som en
rangering av sykehus, og det er ikke det tallene sier.

## Side 4 — «Metode»

Spørsmålet: *kan jeg stole på dette?*

Ren tekstside. Innhold hentet fra `dokumentasjon/forbehold.md`:

- kildeoversikt med lenker og NLOD-merking
- de ni forbeholdene i kort form
- kornnivå og hva som er kumulativt
- hva som er hentet automatisk og hva som er eksportert for hånd
- én matrise: `Antall målinger` og `Antall prikkede` per enhet og indikator

De fleste rapporter legger metode i et vedlegg ingen åpner. Her er den en av
fire sider, og lenket fra et ikon på hver av de andre tre.

**Commit 9:** `git commit -am "Fire rapportsider"`

---

# DEL 10 — Tema

**Vis > Temaer > Tilpass gjeldende tema.**

| Element | Verdi |
|---|---|
| Innenfor mål | `#1B7F5F` |
| Utenfor mål | `#B03A2E` |
| Ikke vurdert | `#7B7B7B` |
| Nøytral 1 | `#2E5A88` |
| Nøytral 2 | `#5B8AA6` |
| Bakgrunn | `#FFFFFF` |
| Tekst | `#1A1A1A` |

Grønn og rød er valgt mørke nok til å ha tilstrekkelig kontrast mot hvit
bakgrunn. Ikke bruk farge som eneste signal — `Status mot mål` står som tekst
ved siden av fargen, fordi omtrent 8 % av menn har en form for fargesynsvekkelse.

Lagre temaet som `powerbi/tema.json` og commit det.

---

# DEL 11 — Ferdigstill

## 11.1 Rydd i modellen

- Alle nøkkelkolonner skjult
- `bro_enhet_rls` skjult
- Alle mål har beskrivelse
- Ingen ubrukte spørringer i Power Query

## 11.2 Skjermbilder

Ta ett skjermbilde per side, legg i `docs/bilder/`, og lenk dem inn i README.

Ingen rekrutterer åpner en .pbip. De ser README-en i 40 sekunder og bestemmer
seg der.

## 11.3 Ikke publiser til web

Ikke bruk **Publiser på nettet** på noe som ser ut som helsedata, selv når det
er åpne data. Skjermbilder holder.

## 11.4 Siste commit

```bash
git add .
git commit -m "Tema, skjermbilder og dokumentasjon"
git log --oneline
```

Du skal ha rundt 12–15 commits med lesbare norske meldinger. Det er halve
poenget med å velge .pbip framfor .pbix.

---

# Feilsøking

| Symptom | Årsak |
|---|---|
| `Sør-Øst` vises som `SÃ¸r-Ãst` | `Encoding = 65001` mangler i `fnLesMart` |
| Perioder sorteres feil | `periode_etikett` mangler «Sorter etter kolonne» = `sortering` |
| Tall er tre ganger for høye | kumulative perioder er summert — sett `periodetype`-sliceren til enkelt valg |
| `Verdi i fjor` er tom overalt | flere perioder er valgt samtidig, så `SELECTEDVALUE` returnerer tomt |
| Beregningsgruppen gir tomt | `Ordinal` er lagret som tekst, eller Tabular Editor er ikke lagret |
| RLS viser ingenting | `bro_enhet_rls` er tom fordi NKI-eksporten ikke er lastet inn |
| RLS viser for mye | kryssfiltrering på RLS-relasjonen står på Begge |
| Fila åpner ikke på annen maskin | `MartMappe` peker på en absolutt bane som ikke finnes der |

---

# Hva du må kunne forklare på intervju

De kommer ikke til å be deg om å bygge noe. De kommer til å spørre hvorfor.
Disse seks er de sannsynlige:

1. **Hvorfor stjerneskjema når datasettet er så lite?** Fordi filterretningen
   blir entydig, og fordi endringer hos kilden rettes ett sted.
2. **Hvorfor ikke `SAMEPERIODLASTYEAR`?** Fordi tertialer ikke er datoer, og
   innebygd tidsintelligens krever en sammenhengende datokolonne.
3. **Hvorfor ligger `retning` i modellen og ikke i DAX?** Fordi ellers må
   fargelogikken skrives på nytt for hver indikator.
4. **Hva er forskjellen på Detalj og Referanse i RLS-brotabellen?** En leder som
   bare ser eget foretak mister sammenligningen som gjør tallet tolkbart.
5. **Hvorfor er prikkede rader beholdt?** Fordi en manglende verdi betyr skjult,
   ikke null, og forskjellen må være synlig i rapporten.
6. **Hvorfor gikk ventetiden ned fra 75 til 64 dager?** Riktig svar er at
   rapporten ikke vet, og at det må undersøkes mot grunndata og fagmiljø. Det er
   det svaret en analytiker skal gi.
