# Start her

Følg de tre delene i rekkefølge. Ikke hopp over noe.

Hele veien: hvis noe feiler, kopier den **første** linjen som sier `ERROR` eller
`FEIL`. Det er den som forteller hva som er galt — resten er følgefeil.

---

## DEL A — Legg mappa på riktig sted

1. Pakk ut zip-fila
2. Flytt mappa `vv-ventetid` til `C:\prosjekt\`

Sluttresultatet skal være: `C:\prosjekt\vv-ventetid\`

**Banen må være kort, uten mellomrom og uten æ, ø eller å.**
Ikke legg den i «Mine dokumenter», ikke i OneDrive, ikke på skrivebordet.
DuckDB og dbt feiler på baner med norske tegn, og OneDrive låser filer
midt under et bygg.

---

## DEL B — Installer det du trenger

### B1. Python

python.org har lagt om. Du får nå **Python Install Manager**, ikke det gamle
installasjonsvinduet. Avkryssingsfeltet «Add python.exe to PATH» finnes ikke
lenger — det er normalt, og PATH settes automatisk.

1. Gå til https://www.python.org/downloads/
2. Klikk den store gule knappen og kjør fila
3. Det åpner et vindu som heter **«Install Python Install Manager?»**
   Klikk **Install Python**. La «Launch when ready» stå avkrysset.

Dette installerer *manageren*, ikke Python selv. Neste steg gjør resten:

4. Trykk `Windows-tast + R`, skriv `cmd`, trykk Enter
5. Skriv dette og trykk Enter:

```
py install 3.13
```

Velg 3.13, ikke 3.14. dbt og duckdb har ikke alltid ferdige pakker for den
aller nyeste Python-versjonen, og da stopper installasjonen i DEL C.

6. Lukk vinduet, åpne et **nytt** `cmd`, og kontroller:

```
python --version
```

Du skal få `Python 3.13.x`.

**Får du «not recognized»:** prøv `py --version` i stedet. Virker den, er alt
i orden — kommandoen heter bare noe annet på din maskin, og `.bat`-filene
finner ut av det selv.

**Virker ingen av dem:** åpne Microsoft Store, søk «Python 3.13», installer
derfra. Den varianten legger seg alltid på PATH.

### B2. Power BI Desktop

Microsoft Store → søk «Power BI Desktop» → Installer.

Butikkversjonen oppdaterer seg selv. Det er den du vil ha.

### B3. Git

1. https://git-scm.com/download/win
2. Kjør fila og trykk Neste på alt

### B4. Tabular Editor 2

1. https://github.com/TabularEditor/TabularEditor/releases/latest
2. Last ned fila som heter `TabularEditor.Installer.msi`
3. Kjør den

Gratisversjonen holder. Trengs bare til DEL 7 i steg-for-steg-guiden.

---

## DEL C — Kjør datagrunnlaget

Åpne `C:\prosjekt\vv-ventetid\` i Utforsker.

### C1. Dobbeltklikk `1_INSTALLER.bat`

Tar 1–3 minutter. Et svart vindu åpner seg og skriver mye tekst.
Når det står **«Ferdig»**, trykk en tast for å lukke.

Sier den at Python ikke er installert: gå tilbake til B1 og se om du
krysset av «Add python.exe to PATH».

### C2. Dobbeltklikk `2_HENT_DATA.bat`

Tar under ett minutt. Denne henter ekte data fra Folkehelseinstituttet
over internett, bygger datamodellen og kjører 51 tester.

Du skal se dette til slutt:

```
Done. PASS=51 WARN=0 ERROR=0 SKIP=0
```

Alle 51 skal være grønne. Er de ikke det, ikke gå videre.

### C3. Sjekk at det ble filer

Åpne `data\mart\`. Der skal det ligge seks CSV-filer:

| Fil | Rader |
|---|---|
| `dim_enhet.csv` | 5 |
| `dim_periode.csv` | 28 |
| `dim_indikator.csv` | 6 |
| `dim_tjenesteomrade.csv` | 4 |
| `fact_indikator.csv` | 5 320 |
| `bro_enhet_rls.csv` | **0 — dette er riktig nå** |

`bro_enhet_rls.csv` er tom fordi den trenger data på helseforetaksnivå,
og det kommer først i neste del. Det er ikke en feil.

---

---

## DEL D — Hent NKI-eksporten

Etter DEL C har du region- og landsnivå. For helseforetak, ventetid og
fristbrudd trenger du eksporten fra Helsedirektoratet. Den har ikke API og må
lastes ned manuelt.

Klikk for klikk med lenke: **`powerbi/NKI_EKSPORT.md`**.

Kort versjon: last ned fra Helsedirektoratets eksportvisning med filtrene
Sektor = Spesialisthelsetjenesten og Nivå = Helseforetak, legg CSV-fila i
`data\manuell\`, og dobbeltklikk `3_VALIDER_NKI.bat`.

Etter dette har `data\mart\` vokst kraftig — `fact_indikator.csv` går fra
rundt 5 000 til rundt 20 000 rader, og `bro_enhet_rls.csv` er ikke lenger tom.

---

## DEL E — Åpne rapporten

Åpne `powerbi\VV_Styringsdashboard.pbip`.

Rapporten er ferdig — fire sider, alle mål, relasjoner, beregningsgruppe og
radnivåsikkerhet ligger i repoet som TMDL og JSON.

Krever at `.pbip`-formatet er slått på: **File** → **Options and settings** →
**Options** → **Preview features** → `Power BI Project (.pbip) save format` og
`Store semantic model using TMDL format`. Omstart av Power BI kreves.

Ligger prosjektet et annet sted enn `C:\prosjekt\vv-ventetid\`: **Home** →
**Transform data** → **Manage Parameters**, sett stiparameteren til din sti til
`data\mart\`. Skråstreken på slutten er obligatorisk.

`powerbi\STEG_FOR_STEG.md` trengs ikke for å bruke rapporten. Den er en logg
over hvordan den ble bygget, og hvorfor hvert valg som ikke var åpenbart ble
tatt.
