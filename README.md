# Styringsdashboard for spesialisthelsetjenesten

Porteføljeprosjekt. Bygger et komplett datagrunnlag fra åpne kilder til ferdig
Power BI-rapport: uttrekk, transformasjon, datamodell, mål og rapport.

Dette er **ikke** en produksjonsløsning, og det inneholder **ingen** pasientdata.
Alt er offentlig publisert statistikk på aggregert nivå.

---

## Hva rapporten svarer på

Målgruppen er en klinikk- eller avdelingsleder som skal svare på tre ting i et
ledermøte:

1. Hvordan ligger vi an mot nasjonale styringsmål?
2. Går utviklingen riktig vei sammenlignet med samme tertial i fjor?
3. Skiller vi oss fra landet, og i så fall hvor?

Rapporten er bygget rundt de spørsmålene, ikke rundt hvilke tall som tilfeldigvis
finnes i kilden.

---

## Arkitektur

```
  FHI åpne API                    Helsedirektoratet
  (Norsk pasientregister)         (Nasjonale kvalitetsindikatorer)
  automatisk uttrekk              manuell eksport
         │                                │
         │  src/hent_npr.py               │  src/valider_nki.py
         │  + manifest (sha256)           │  + skjemakontroll
         ▼                                ▼
  data/raw/npr_*.csv              data/manuell/nki_*.csv
         │                                │
         └────────────┬───────────────────┘
                      ▼
              dbt + DuckDB
      staging  →  intermediate  →  marts
      (typing,    (forener to      (stjerneskjema)
       rensing,    kilder til ett
       tester)     kornnivå)
                      │
                      ▼
              data/mart/*.csv
                      │
                      ▼
              Power BI (.pbip)
       semantisk modell + mål + RLS + rapport
```

Kilden er bevisst hybrid. NPR har åpent API og hentes programmatisk. NKI på
helseforetaksnivå har ikke API og må eksporteres for hånd. Det er den vanligste
situasjonen i praksis, og hele poenget med `valider_nki.py` er at et manuelt ledd
skal ha samme kontroll som et automatisk.

---

## Datakilder

| Kilde | Nivå | Innhold | Tilgang | Lisens |
|---|---|---|---|---|
| Norsk pasientregister via FHIs åpne API | Nasjonalt, region | Aktivitet 2017– (pasienter, døgn, poliklinikk, dagbehandling) | `statistikk-data.fhi.no/api/open/v1` | NLOD |
| Nasjonale kvalitetsindikatorer, Helsedirektoratet | Nasjonalt, RHF, HF | Ventetid, fristbrudd, epikrisetid | Manuell eksport fra NKI-eksportvisningen | NLOD |

Begge kilder krever at kilde oppgis ved gjenbruk. Det gjøres i rapportens bunntekst
og i målet `Kildehenvisning`.

---

## Kjør prosjektet

```bash
pip install -r requirements.txt

# 1. Hent NPR-data (går mot live API)
python src/hent_npr.py

# 2. Legg NKI-eksporten i data/manuell/ og valider den
python src/valider_nki.py data/manuell/nki_eksport.csv

# 3. Bygg modellen og kjør alle tester
cd dbt && dbt deps && dbt build && cd ..

# 4. Eksporter til Power BI
python src/eksporter_mart.py
```

`dbt build` kjører 51 tester. Bygget stopper hvis en av dem feiler.

Fila `data/manuell/MAL_nki_eksport.csv` er en **strukturmal**, ikke data. Den finnes
for å kunne teste røret før man har lastet ned noe, og filtreres eksplisitt bort i
`stg_nki_indikator.sql`. Den inneholder verdien 999 i alle tallfelt nettopp for at
den aldri skal kunne forveksles med et resultat.

---

## Datamodell

Stjerneskjema med én faktatabell og fire dimensjoner, pluss en brotabell for
radnivåsikkerhet.

```
                 dim_periode
                      │
  dim_enhet ── fact_indikator ── dim_indikator
       │              │
  bro_enhet_rls  dim_tjenesteomrade
```

**Kornnivå i `fact_indikator`:** én enhet, én periode, ett tjenesteområde, én aktør,
én indikator → én verdi.

Faktatabellen inneholder bare nøkler og tall. All tekst ligger i dimensjonene.
Begrunnelse i `dokumentasjon/datamodell.md`.

---

## Tre valg som er verdt å se på

**Tertialer, ikke datoer.** Spesialisthelsetjenesten rapporterer i tertialer.
Power BIs innebygde tidsintelligens forutsetter en sammenhengende datokolonne og
kan derfor ikke brukes. `dim_periode` har en eksplisitt sorteringsnøkkel og en
forhåndsberegnet `sortering_i_fjor` som målene slår opp mot.

**Kumulative perioder er merket.** NPR publiserer «januar–april» og «januar–august»
kumulativt, ikke som frittstående tertialer. Summerer man dem sammen med «hele året»,
telles samme pasient tre ganger. Kolonnen `er_kumulativ` gjør skillet eksplisitt,
og målet `Forbehold aktiv periode` varsler brukeren når utvalget blander de to.

**Radnivåsikkerhet med referansetilgang.** En leder som bare får se eget foretak
mister sammenligningen som gjør tallet tolkbart — 62 dagers ventetid sier ingenting
alene. `bro_enhet_rls` gir hver rolle detaljtilgang til egen enhet og
referansetilgang til region og land, slik at mållinjen og landssnittet er synlig
uten at man kan bore seg ned i et annet foretaks tall.

---

## Kontroll mot publiserte tall

Pipelinen er kontrollert mot Folkehelseinstituttets egen publisering for
1. tertial 2026 (somatikk, alle aktører, landet):

| Periode | Modellen gir | FHI publiserer |
|---|---|---|
| 1. tertial 2025 | 1 654 620 | 1 654 620 |
| 1. tertial 2026 | 1 614 030 | 1 614 030 |

En pipeline som ikke er kontrollert mot kildens egen publisering er ikke ferdig,
uansett hvor pen rapporten er.

---

## Kjente svakheter

Listet fordi de er reelle, og fordi en modell uten dokumenterte svakheter som regel
bare har udokumenterte svakheter.

- **Snitt av snitt.** NKI-eksporten gir ferdig beregnede gjennomsnitt, ikke teller
  og nevner. Et vektet snitt på tvers av foretak lar seg derfor ikke regne korrekt.
  Med tilgang til NPR-grunndata ville dette vært løst i faktatabellen.
- **Fildump som mart-lag.** CSV er valgt for at prosjektet skal kunne åpnes av andre
  uten driverinstallasjon. I drift hører dette laget hjemme i et datavarehus.
- **NPR har ikke helseforetaksnivå.** Nøkkeltallene publiseres på nasjonalt og
  regionalt nivå. Foretaksnivå kommer bare fra NKI-eksporten.
- **Import mode.** Datamengden er liten nok til at det ikke koster noe her, men
  valget er tatt bevisst og ikke som standard.

Full liste med forbehold fra kildene selv: `dokumentasjon/forbehold.md`.

---

## Mappestruktur

```
src/                 uttrekk, validering, eksport
data/raw/            daterte råfiler + manifest (sha256, radantall, dimensjoner)
data/manuell/        NKI-eksport legges her
data/mart/           ferdige tabeller til Power BI
dbt/                 transformasjon og tester
dokumentasjon/       datamodell, forbehold, måltall
powerbi/             DAX-mål, Power Query, .pbip
```

---

## Lisens og kildekrav

Data er hentet fra Folkehelseinstituttet og Helsedirektoratet under
Norsk lisens for offentlige data (NLOD). Kilde skal oppgis ved gjenbruk.
Ingen av kildene er gjengitt på en måte som gir inntrykk av å komme fra dem.
