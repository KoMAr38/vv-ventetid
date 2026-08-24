# Måltall og kildehenvisning

Regelen i dette prosjektet: **ingen målverdi uten kildehenvisning.** Et tall som
står i en rapport uten at man kan peke på hvor det kommer fra, er et tall noen
har husket feil.

Der en indikator ikke har et vedtatt nasjonalt mål, står målverdien som null og
rapporten tegner ingen mållinje.

---

## Vedtatte mål

| Indikator | Målverdi | Enhet | Retning |
|---|---|---|---|
| Gjennomsnittlig ventetid, somatikk | 50 | dager | Lavere er bedre |
| Gjennomsnittlig ventetid, psykisk helsevern voksne (PHV) | 40 | dager | Lavere er bedre |
| Gjennomsnittlig ventetid, psykisk helsevern barn og unge (PHBU) | 35 | dager | Lavere er bedre |
| Gjennomsnittlig ventetid, tverrfaglig spesialisert rusbehandling (TSB) | 30 | dager | Lavere er bedre |
| Andel epikriser sendt innen 1 dag etter utskrivning | 70 | prosent | Høyere er bedre |

---

## Kilder

**Ventetidsmålene** står ordrett likt i Oppdragsdokument 2025 til alle fire
regionale helseforetak fra Helse- og omsorgsdepartementet:

> Målsettingen på sikt er gjennomsnittlig ventetid lavere enn 50 dager for
> somatikk, 40 dager for psykisk helsevern voksne, 35 dager for psykisk
> helsevern barn og unge og 30 dager for tverrfaglig spesialisert
> rusbehandling (TSB).

Målet for PHBU er i tillegg slått fast i Nasjonal helse- og samhandlingsplan
2024–2027, gjengitt i Helsedirektoratets artikkel om kvalitetsindikatoren for
ventetid i psykisk helsevern for barn og unge.

Målet for somatikk er gjengitt i Helsedirektoratets artikkel om
kvalitetsindikatoren for ventetid i somatisk helsetjeneste.

**Epikrisetidsmålet** følger av kravet i oppdrag og bestilling til
helseforetakene om at minst 70 prosent av epikrisene skal være sendt innen én
dag etter utskrivning.

Hentet 24. august 2026.

---

## To ting som bevisst ikke har målverdi

**Median får ikke målverdi.** Målet er formulert for gjennomsnitt. Legges det på
medianen også, sammenlignes et tall med et mål som ikke gjelder for det, og
figuren blir stille feil.

**Aktivitetsindikatorer får ikke målverdi.** Antall pasienter, oppholdsdøgn og
poliklinikkontakter har ingen ønsket retning. Et synkende antall pasienter er
verken bra eller dårlig i seg selv — det avhenger av hvorfor. De har derfor
`retning = 'Ingen retning'`, og målet `Status mot mål` returnerer
«Ikke vurdert» for dem.

---

## En avgrensning som er verdt å merke seg

Epikrisetidsmålet ble først satt til 70 prosent for indikatoren «andel sendt
innen **én** dag». Kilden publiserer også «andel sendt innen **sju** dager»,
som er et annet måltall med et annet mål, samt rene tellinger av antall
epikriser.

Første versjon av mønstermatchingen i `dim_indikator.sql` traff alle tre. Det
ga målverdi 70 på en telling av epikriser, hvor tallet er i tusener, og på en
sjudagersandel som ikke måles mot 70 prosent.

Et mål på feil indikator er verre enn ingen mål, fordi figuren da ser vurdert ut.
Matchingen er derfor strammet inn til `andel%epikris%innen 1 dag%`.

---

## Slik endres de

I `dbt/models/marts/dim_indikator.sql`, i `case`-blokken for `malverdi`.
Kjør deretter `3_VALIDER_NKI.bat` og trykk **Refresh** i Power BI.
