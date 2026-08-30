# Byggelogg for rapporten

**Dette er ikke nødvendig for å bruke prosjektet.** Rapporten ligger ferdig i
`Fjordhelse_Datakvalitet.pbip` — fire sider, alle mål, relasjoner og visualer er
versjonert som TMDL og JSON. Åpne fila, og alt er der.

Dokumentet er en logg: hva som ble gjort, i hvilken rekkefølge, og hvorfor hvert
valg som ikke var åpenbart ble tatt. Kontrollpunktene underveis er de faktiske
tallene modellen skal gi, og kan brukes til å verifisere at et nytt bygg gir
samme resultat.

Menynavn står på engelsk, fordi Power BI Desktop er installert på engelsk.

Bygging fra bunnen tar rundt to timer. Forutsetning: `2_BYGG.bat` har kjørt
ferdig med `PASS=41 ERROR=0`, og `data\mart\` inneholder én `.parquet` og fire
`.csv`.

Merk at loggen beskriver tre rapportsider. Siden `Oversikt` — KPI-fliser,
sparklines og what-if-simulering — kom til etterpå, og er dokumentert i README
under «Rapporten» og i commit-historikken.

---

# DEL 0 — Før du starter

**File → Options and settings → Options → Preview features**

Huk av:

- `Power BI Project (.pbip) save format`
- `Store semantic model using TMDL format`

Start Power BI Desktop på nytt.

Uten dette havner alt i en binær `.pbix`, og Git ser bare at fila er endret,
ikke hva som er endret. Det er hele grunnen til at prosjektet ligger i Git.

---

# DEL 1 — Lagre som prosjekt

**File → Save as → Browse**

| Felt | Verdi |
|---|---|
| Save as type | `Power BI project files (*.pbip)` |
| Path | `C:\prosjekt\fjordhelse-kvalitet\powerbi\` |
| File name | `Fjordhelse_Datakvalitet` |

Kontroll: i `powerbi\` skal det nå ligge tre ting — én `.pbip`-fil og to mapper
som slutter på `.Report` og `.SemanticModel`.

**Commit 1:** `git add . && git commit -m "Tomt Power BI-prosjekt som pbip"`

---

# DEL 2 — Hent data

## 2.1 Parameter for stien

**Home → Transform data → Manage Parameters → New Parameter**

| Felt | Verdi |
|---|---|
| Name | `MartMappe` |
| Type | `Text` |
| Suggested Values | `Any value` |
| Current Value | `C:\prosjekt\fjordhelse-kvalitet\data\mart\` |

**Skråstreken på slutten er obligatorisk.** Uten den limes filnavnet rett på
mappenavnet, og Power Query sier at fila ikke finnes.

## 2.2 Funksjon som leser CSV

**Home → New Source → Blank Query**, høyreklikk spørringen → **Advanced Editor**.
Lim inn:

```
let
    fnLesCsv = (Filnavn as text) as table =>
        let
            Kilde = Csv.Document(
                File.Contents(MartMappe & Filnavn),
                [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
            ),
            Overskrifter = Table.PromoteHeaders(Kilde, [PromoteAllScalars = true])
        in
            Overskrifter
in
    fnLesCsv
```

Rename til `fnLesCsv`. Ikonet skal bli `fx`.

`Encoding = 65001` er UTF-8. Uten den blir `Sør-Øst` til `SÃ¸r-Ãst`.

## 2.3 De fire dimensjonstabellene

For hver av dem: **Home → New Source → Blank Query → Advanced Editor**.

`dim_enhet`:
```
let Kilde = fnLesCsv("dim_enhet.csv") in Kilde
```

`dim_periode`:
```
let Kilde = fnLesCsv("dim_periode.csv") in Kilde
```

`dim_diagnose`:
```
let Kilde = fnLesCsv("dim_diagnose.csv") in Kilde
```

`fact_datakvalitet`:
```
let Kilde = fnLesCsv("fact_datakvalitet.csv") in Kilde
```

Gi hver spørring samme navn som fila.

## 2.4 Faktatabellen fra Parquet

**Home → New Source → Blank Query → Advanced Editor**, navn `fact_henvisning`:

```
let
    Kilde = Parquet.Document(
        File.Contents(MartMappe & "fact_henvisning.parquet")
    )
in
    Kilde
```

Parquet er allerede typet. Du slipper å sette datatyper manuelt, og
innlastingen går fortere enn med CSV.

## 2.5 Datatyper på CSV-tabellene

CSV har ingen typer. Sett dem på hver av de fire:

| Tabell | Kolonne | Type |
|---|---|---|
| `dim_enhet` | `er_psykisk_helse` | `True/False` |
| `dim_periode` | `maned` | `Date` |
| `dim_periode` | `aar`, `maned_nr`, `sortering`, `tertial` | `Whole Number` |
| `dim_diagnose` | `gyldig_fra`, `gyldig_til` | `Date` |
| `fact_datakvalitet` | `maned` | `Date` |
| `fact_datakvalitet` | `antall_avvik`, `antall_rader` | `Whole Number` |
| `fact_datakvalitet` | `andel_avvik_pst` | `Decimal Number` |

**Close & Apply.**

**Commit 2:** `git commit -am "Power Query: parameter, funksjon og fem tabeller"`

---

# DEL 3 — Modellen

## 3.1 Relasjoner

**Model view → Manage relationships.** Slett alt Power BI har gjettet, og lag
disse fire manuelt:

| Fra | Til | Kardinalitet | Kryssfilter |
|---|---|---|---|
| `dim_enhet[enhet_kode]` | `fact_henvisning[enhet_kode]` | Én til mange | Enkel |
| `dim_periode[maned]` | `fact_henvisning[maned]` | Én til mange | Enkel |
| `dim_enhet[enhet_kode]` | `fact_datakvalitet[enhet_kode]` | Én til mange | Enkel |
| `dim_periode[maned]` | `fact_datakvalitet[maned]` | Én til mange | Enkel |

**Ingen toveisrelasjoner.**

`dim_diagnose` kobles bevisst **ikke**. Koden alene er ikke unik — R51 finnes
to ganger med ulik gyldighetsperiode. Koblingen er allerede gjort i dbt, på
kode og dato. Å koble den på nytt her ville gitt en tvetydig relasjon.
Det er verdt å kunne forklare på intervju.

## 3.2 Sortering og skjuling

- `dim_periode[maned_etikett]` → **Sort by column** → `sortering`
- Skjul: `fact_henvisning[pasient_pseudonym]`, `dim_periode[sortering]`

## 3.3 Beskrivelser

Skriv `Description` på minst disse:

| Kolonne | Beskrivelse |
|---|---|
| `fact_henvisning[fristbrudd_rapportert]` | Slik fagsystemet rapporterer. Henvisning uten registrert sluttdato regnes som ventende. |
| `fact_henvisning[fristbrudd_kvalitetssikret]` | Duplikater fjernet. Behandlede forløp uten sluttdato regnes ikke som fristbrudd. |
| `fact_henvisning[ventetid_dager]` | Tom der sluttdato mangler. Tom er ikke null. |
| `fact_henvisning[flagg_manglende_slutt]` | 1 når «ventetid slutt» ikke er registrert. |
| `dim_diagnose[gyldig_fra]` | Kodeverk revideres. Samme kode kan bety ulike ting i ulike perioder. |

**Commit 3:** `git commit -am "Relasjoner, sortering og beskrivelser"`

---

# DEL 4 — Målene

Lag først en tom tabell for målene: **Home → Enter data**, navn `_Mål`, én
kolonne `Kolonne`, **Load**. Skjul kolonnen etterpå.

Marker `_Mål` i feltlista før hvert nytt mål, ellers havner de i faktatabellen.

**Home → New measure**, ett om gangen:

```
Antall henvisninger = COUNTROWS ( fact_henvisning )
```

```
Antall i nevner = SUM ( fact_henvisning[teller_i_nevner] )
```

```
Fristbrudd rapportert = SUM ( fact_henvisning[fristbrudd_rapportert] )
```

```
Fristbrudd kvalitetssikret = SUM ( fact_henvisning[fristbrudd_kvalitetssikret] )
```

```
Andel fristbrudd rapportert =
DIVIDE ( [Fristbrudd rapportert], [Antall henvisninger] )
```

```
Andel fristbrudd kvalitetssikret =
DIVIDE ( [Fristbrudd kvalitetssikret], [Antall i nevner] )
```

```
Differanse prosentpoeng =
[Andel fristbrudd rapportert] - [Andel fristbrudd kvalitetssikret]
```

```
Andel manglende sluttdato =
DIVIDE ( SUM ( fact_henvisning[flagg_manglende_slutt] ), [Antall henvisninger] )
```

```
Andel prioritet ikke vurdert =
DIVIDE ( SUM ( fact_henvisning[flagg_prioritet_default] ), [Antall henvisninger] )
```

Sett format på de fem andelsmålene: **Measure tools → Format → Percentage**,
én desimal.

Kontroll før du går videre: sett `Andel fristbrudd rapportert` i et Card.
Det skal vise **24,1 %**. Viser det noe annet, stemmer ikke innlastingen.

**Commit 4:** `git commit -am "Ni maal"`

---

# DEL 5 — Side 1: «Fristbrudd før og etter»

Dette er siden hele prosjektet handler om. Bygg den først og bruk mest tid her.

| Element | Innhold |
|---|---|
| To kort øverst | `Andel fristbrudd rapportert` og `Andel fristbrudd kvalitetssikret`, side ved side |
| Kort til høyre | `Differanse prosentpoeng` |
| Stolpediagram, liggende | Y: `dim_enhet[kortnavn]`, X: begge fristbruddmålene som to serier |
| Tekstboks under | Se under |

Stolpediagrammet med begge målene ved siden av hverandre er hele poenget:
leseren ser rangeringen snu.

Sorter på `Andel fristbrudd rapportert` synkende, slik at TSB står øverst.

Tekstboks, skriftstørrelse 9, farge `#7B7B7B`:

> Forskjellen mellom de to søylene er registreringspraksis, ikke ventetid.
> Etter kvalitetssikring ligger alle enheter mellom 14,2 og 14,5 prosent.

**Tittel:** `Fristbrudd før og etter kvalitetssikring`
**Undertittel:** `Fjordhelse HF 2022–2025. Syntetiske data.`

---

# DEL 6 — Side 2: «Datakvalitet»

| Element | Innhold |
|---|---|
| Matrise | Rader: `dim_enhet[kortnavn]`, Kolonner: `fact_datakvalitet[dimensjon]`, Verdi: `andel_avvik_pst` |
| Linjediagram | X: `dim_periode[maned_etikett]`, Y: `Andel manglende sluttdato`, Forklaring: `dim_enhet[kortnavn]` |
| Slicer | `fact_datakvalitet[dimensjon]` |

Betinget formatering på matrisen: **Format → Cell elements → Background color
→ fx → Gradient**, lav verdi hvit, høy verdi `#B03A2E`.

Her er farge riktig virkemiddel, i motsetning til på en kategoriakse: verdien
er en andel avvik, og mer er entydig verre.

---

# DEL 7 — Side 3: «Metode og forbehold»

Ren tekstside. Innhold hentes fra `dokumentasjon/funn_og_anbefalinger.md`,
avsnittet «Metode», pluss:

- at dataene er syntetiske og generert med fast seed
- at fasiten ligger i `data/raw/fasit.json`
- hvordan kvalitetssikret fristbrudd er definert, ordrett
- at definisjonen er konservativ og ikke fanger forløp der all registrering uteble

Legg inn én matrise: `fact_datakvalitet` med `antall_rader` per enhet, slik at
leseren ser hvor stort grunnlaget bak hver prosent er.

**Commit 5:** `git commit -am "Tre rapportsider"`

---

# DEL 8 — Tema

**View → Themes → Customize current theme → Colors**

| Sted | Felt | Verdi |
|---|---|---|
| Data | Color 1 | `2E5A88` |
| Data | Color 2 | `8A6A3B` |
| Data | Color 3 | `5B8AA6` |
| Data | Color 4 | `3D7A5A` |
| Data | Color 5 | `7B7B7B` |
| Sentiment | Positive | `1B7F5F` |
| Sentiment | Neutral | `7B7B7B` |
| Sentiment | Negative | `B03A2E` |
| Structural | First-level elements | `1A1A1A` |
| Structural | Background | `FFFFFF` |

Grønt og rødt ligger bare under **Sentiment**, ikke blant seriefargene. En
kategoriakse skal ikke fargelegges med farger som betyr bra og dårlig — da
leser folk en vurdering inn i noe som bare er en gruppering.

**View → Themes → Download current theme** → lagre som `powerbi\tema.json`.

**Commit 6:** `git commit -am "Tema"`

---

# DEL 9 — Ferdigstill

- Skjermbilde per side i `docs\bilder\`, lenket inn i README
- `git status` skal være ren
- Ikke bruk **Publish to web**

For skjermbilder: **File → Export → Export to PDF**, og klipp sidene derfra.
Det gir full oppløsning. Skjermklipp fra Power BI-vinduet blir uleselig fordi
lerretet er skalert ned til å passe i vinduet.

---

# Feilsøking

| Symptom | Årsak |
|---|---|
| `Sør` vises som `SÃ¸r` | `Encoding = 65001` mangler i `fnLesCsv` |
| Fila finnes ikke | `MartMappe` mangler skråstrek på slutten |
| Andel fristbrudd viser 0 % | CSV-kolonnene er tekst, ikke tall — sett datatype |
| Måneder sorteres alfabetisk | `maned_etikett` mangler Sort by column |
| Alle enheter har lik andel | relasjonen mellom `dim_enhet` og fakta mangler |
| Parquet-spørringen feiler | stien peker på `.csv` i stedet for `.parquet` |

---

# Spørsmål du bør kunne svare på

1. **Hvorfor to kolonner for fristbrudd i stedet for å rette tallet?**
   Fordi det rapporterte tallet er det foretaket faktisk sender fra seg.
   Differansen er selv et styringstall — den måler registreringskvalitet.

2. **Hvorfor er `dim_diagnose` ikke koblet i modellen?**
   Fordi diagnosekoden alene ikke er unik. Koblingen krever både kode og dato,
   og den er derfor gjort i dbt.

3. **Hvorfor syntetiske data?**
   Fordi feilratene må være kjent for at metoden skal kunne kontrolleres, og
   fordi ekte pasientdata ikke hører hjemme i et porteføljeprosjekt.

4. **Hvordan vet du at kvalitetssikringen ikke bare pynter på tallet?**
   Definisjonen er konservativ og står ordrett i rapporten. Den krever bevis
   for kontakt før fristen, ikke fravær av bevis for det motsatte.

5. **Hva ville du gjort annerledes med ekte data?**
   Ikke stolt på `registrert_tidspunkt` alene. I et ekte fagsystem finnes det
   flere spor etter kontakt — kontaktregistreringer, notater, prosedyrekoder —
   og de bør brukes sammen.
