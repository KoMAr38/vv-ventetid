# Last ned NKI-eksporten

Dette er dataene på helseforetaksnivå: ventetid, fristbrudd og epikrisetid.
Uten dem har rapporten bare landet og de fire regionene, og radnivåsikkerheten
kan ikke testes.

Regn med 20–30 minutter. Det meste er venting på at nettsiden laster.

---

## Lenken

**https://www.helsedirektoratet.no/statistikk/kvalitetsindikatorer/eksport-av-data-fra-de-nasjonale-kvalitetsindikatorene-nki**

Finner du ikke fram: gå til helsedirektoratet.no → **Statistikk** →
**Nasjonale kvalitetsindikatorer** → **Eksport av data fra de nasjonale
kvalitetsindikatorene (NKI)**.

Bruk Edge eller Chrome. Siden er en innebygd Power BI-rapport og oppfører seg
dårlig i eldre nettlesere.

---

## Slik ser siden ut

Under overskriften ligger en stor grå rapportboks. Den er delt i to:

- **venstre side**: fem nedtrekksmenyer — Sektor, Nivå,
  Helseforetak/Kommune/Sykehus, Tidsperiode, Kvalitetsindikator
- **høyre side**: en forhåndsvisning som viser radene du har valgt

Radantallet i forhåndsvisningen oppdaterer seg mens du velger. Det er den
tellingen du styrer etter.

Klikk **Fullskjerm** over rapporten. Menyene er trange i vanlig visning.

---

## Steg 1 — Sett filtrene

Klikk pila som peker nedover på hver meny for å åpne den.

### Sektor

Velg **Spesialisthelsetjenesten**.

Ikke la denne stå tom. Da får du med kommunehelsetjenesten, og datasettet blir
tre ganger så stort uten at du kan bruke noe av det.

### Nivå

Velg **Helseforetak**.

Dette er hele poenget med nedlastingen. Nasjonalt nivå har du allerede fra
FHI-API-et.

### Helseforetak/Kommune/Sykehus

La den stå **tom**. Tom betyr alle.

Vil du begrense: velg minst disse elleve, som utgjør Helse Sør-Øst.
Sammenligning krever noen å sammenligne med — velger du bare Vestre Viken,
har du et tall uten kontekst.

```
Akershus universitetssykehus HF
Oslo universitetssykehus HF
Sunnaas sykehus HF
Sykehuset Innlandet HF
Sykehuset i Vestfold HF
Sykehuset Telemark HF
Sykehuset Østfold HF
Sørlandet sykehus HF
Vestre Viken HF
Sykehusapotekene HF
Sykehuspartner HF
```

### Tidsperiode

Velg alle tertialer fra **2021** til og med siste tilgjengelige.

Ikke ta med 2020. Plikten til å fastsette frist bortfalt i store deler av det
året, og tallene er ikke sammenlignbare. Det står i `dokumentasjon/forbehold.md`
punkt 6.

### Kvalitetsindikator

Velg disse, og bare disse:

- alt som heter **ventetid**
- alt som heter **fristbrudd**
- alt som heter **epikrisetid**

Er du usikker på om en indikator hører med: ta den heller ikke med. Du kan
laste ned på nytt senere. Et for stort uttrekk sprenger radgrensen og tvinger
deg til å begynne på nytt.

---

## Steg 2 — Sjekk radantallet

Se på forhåndsvisningen til høyre. Radantallet står oppgitt.

**Under 30 000?** Gå videre til steg 3.

**Over 30 000?** Del uttrekket i to. Sett Tidsperiode til 2021–2023 og
eksporter, sett så 2024 til i dag og eksporter en gang til.

Begge filene legges i samme mappe. `stg_nki_indikator.sql` leser alle
CSV-filer i `data/manuell/` og setter dem sammen automatisk — du trenger ikke
slå dem sammen selv.

---

## Steg 3 — Eksporter

1. Hold musepekeren over forhåndsvisningen til høyre
2. Øverst i høyre hjørne av den dukker det opp tre prikker — **Flere alternativer**
3. Klikk dem
4. Velg **Eksporter data**
5. Velg **Summerte data**
6. Velg filformat **CSV (.csv)**
7. Klikk **Eksporter**

**De tre prikkene vises bare når musepekeren er over rapportboksen.** Det er
det folk står fast på. Beveg musa inn i forhåndsvisningen først.

**Summerte data**, ikke Underliggende data. Underliggende gir flere kolonner
enn modellen forventer, og kan ikke lastes ned som CSV i det hele tatt.

Fila havner i `Nedlastinger`.

---

## Steg 4 — Legg fila på plass

1. Åpne `Nedlastinger`
2. Gi fila navnet `nki_eksport.csv`
   (har du to filer: `nki_eksport_1.csv` og `nki_eksport_2.csv`)
3. Flytt den til `C:\prosjekt\vv-ventetid\data\manuell\`

La `MAL_nki_eksport.csv` ligge. Den er en strukturmal med tallet 999 i alle
felt, og den filtreres bort automatisk. Den skader ingenting.

---

## Steg 5 — Valider og bygg på nytt

Gå til `C:\prosjekt\vv-ventetid\` og dobbeltklikk **`3_VALIDER_NKI.bat`**.

Skriptet sjekker fire ting før den slipper fila inn:

1. at kolonnene heter det de skal
2. at ingen nøkkelkolonne er tom
3. at det ikke finnes dupliserte rader
4. hvor mange verdier som er skjult av personvernhensyn

Deretter bygger det datamodellen på nytt.

### Hva du skal se

```
Fil        : nki_eksport.csv
Rader      : 14 xxx
Perioder   : ['2021T1', '2021T2', ...]
Lokasjoner : 11
Indikatorer: 6
  ADVARSEL  xxx rader har ingen verdi (trolig prikket av personvernhensyn)

Godkjent.
```

**ADVARSEL er greit.** Prikkede verdier er kilden som skjuler tall der
pasientgrunnlaget er under 5. Det er ikke en feil i fila di — modellen
beholder radene og merker dem, og rapporten viser «skjult av personvernhensyn»
i stedet for et hull i kurven.

**FEIL er ikke greit.** Da er noe galt med eksporten, og skriptet stopper.

Til slutt skal du se:

```
Done. PASS=51 WARN=0 ERROR=0
bro_enhet_rls          xx rader
```

`bro_enhet_rls` er ikke lenger 0. Da virket det.

---

## Hvis noe går galt

| Melding | Hva som er galt | Hva du gjør |
|---|---|---|
| `Mangler kolonner: ['Nivå']` | du valgte Underliggende data | eksporter på nytt med Summerte data |
| `Fant ingen NKI-eksport` | fila ligger feil sted, eller heter `MAL_` noe | flytt til `data\manuell\` og gi den et annet navn |
| `xxx duplikate rader` | du eksporterte to ganger og begge filene ligger der | slett den ene |
| `er_umappet` som advarsel i dbt | et foretak i eksporten står ikke i oppslagstabellen | åpne `dbt\seeds\enhet_mapping.csv`, legg til en linje, kjør `3_VALIDER_NKI.bat` på nytt |
| Fila lar seg ikke åpne i Excel | den er UTF-8, Excel gjetter feil | ikke åpne den i Excel i det hele tatt — skriptet leser den fint |

**Ikke åpne CSV-fila i Excel og lagre den.** Excel skriver den tilbake i et
annet tegnsett, og da blir `Sør-Øst` til `SÃ¸r-Ãst`. Trenger du å se på
innholdet, åpne den i Notisblokk.

---

## Når dette er ferdig

Da har du alt du trenger. Gå til `powerbi/STEG_FOR_STEG.md` og start på **DEL 1**.

Kolonnen `malverdi` står fortsatt tom — den fylles i DEL 0.3, og du trenger den
ikke før du kommer til målene i DEL 5.
