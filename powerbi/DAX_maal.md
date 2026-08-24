# DAX-mål

Alle mål ligger i én tom tabell som heter `_Mål`. Grunnen er at mål som ligger spredt
i faktatabellen blir usynlige for den som skal overta modellen, og at feltlista i
Power BI da blander tall du kan bruke med kolonner du ikke skal bruke.

Rekkefølgen under er byggerekkefølge. Hvert mål har en `Description` som skal limes
inn i egenskapsfeltet i Power BI — det er de beskrivelsene som gjør modellen
selvbetjent for en kliniker eller forsker som ikke var med da den ble bygget.

---

## 1. Grunnmål

### Verdi

```dax
Verdi =
SUM ( fact_indikator[verdi] )
```

**Description:** Summen av valgt indikator. Merk at «sum» bare gir mening for
antall. For gjennomsnittsindikatorer som ventetid skal `Verdi (vektet)` brukes.

---

### Antall målinger

```dax
Antall målinger =
COUNTROWS ( fact_indikator )
```

**Description:** Hvor mange rader som ligger bak tallet. Brukes til å avsløre at
et snitt er regnet på ett enkelt datapunkt.

---

### Antall prikkede

```dax
Antall prikkede =
CALCULATE (
    COUNTROWS ( fact_indikator ),
    fact_indikator[er_prikket] = TRUE ()
)
```

**Description:** Antall rader der kilden har skjult tallet av personvernhensyn
(pasientgrunnlag under 5). En verdi som mangler er ikke det samme som null, og
dette målet gjør forskjellen synlig i rapporten.

---

### Andel prikket

```dax
Andel prikket =
DIVIDE ( [Antall prikkede], [Antall målinger] )
```

**Description:** Andelen av grunnlaget som er skjult. Over ca. 20 % bør en figur
merkes med forbehold framfor å presenteres som en trend.

---

## 2. Riktig aggregering per indikatortype

Dette er det målet som skiller en modell som ser riktig ut fra en som er riktig.
En ventetid på 62 dager i Vestre Viken og 70 i Sykehuset Østfold gir ikke 132 dager
til sammen. Modellen må vite når den skal summere og når den skal gjøre noe annet.

### Verdi (riktig aggregert)

```dax
Verdi (riktig aggregert) =
VAR _Enhet =
    SELECTEDVALUE ( dim_indikator[enhet], "Blandet" )
RETURN
    SWITCH (
        _Enhet,
        "Antall",  SUM ( fact_indikator[verdi] ),
        "Dager",   AVERAGE ( fact_indikator[verdi] ),
        "Prosent", AVERAGE ( fact_indikator[verdi] ),
        BLANK ()
    )
```

**Description:** Aggregerer etter indikatorens enhet. Antall summeres, dager og
prosent snittes. Returnerer tom verdi når flere indikatortyper er valgt samtidig,
i stedet for å legge sammen tall som ikke skal legges sammen.

> Snitt av snitt er heller ikke korrekt for ventetid — riktig svar krever teller og
> nevner. NKI-eksporten leverer bare den ferdig beregnede verdien, ikke grunnlaget.
> Det står i `dokumentasjon/forbehold.md`, og det er en av tingene som ville vært
> løst annerledes med tilgang til NPR-grunndata.

---

## 3. Tid

Tertialer har ingen datokolonne, så `SAMEPERIODLASTYEAR` og resten av den innebygde
tidsintelligensen er ikke tilgjengelig. Oppslaget gjøres i stedet mot
`dim_periode[sortering_i_fjor]`, som ble beregnet i dbt.

### Verdi i fjor

```dax
Verdi i fjor =
VAR _Sortering =
    SELECTEDVALUE ( dim_periode[sortering_i_fjor] )
RETURN
    CALCULATE (
        [Verdi (riktig aggregert)],
        REMOVEFILTERS ( dim_periode ),
        dim_periode[sortering] = _Sortering
    )
```

**Description:** Samme tertial året før. Bygger på en eksplisitt periodenøkkel
fordi spesialisthelsetjenesten rapporterer i tertialer og ikke i datoer.

---

### Endring år over år

```dax
Endring år over år =
VAR _Nå = [Verdi (riktig aggregert)]
VAR _Fjor = [Verdi i fjor]
RETURN
    IF ( NOT ISBLANK ( _Fjor ), _Nå - _Fjor )
```

**Description:** Absolutt endring fra samme tertial i fjor. Tom når det ikke finnes
et sammenlignbart fjorår.

---

### Endring år over år %

```dax
Endring år over år % =
DIVIDE ( [Endring år over år], [Verdi i fjor] )
```

**Description:** Relativ endring fra samme tertial i fjor.

---

## 4. Mål og avvik

### Målverdi

```dax
Målverdi =
SELECTEDVALUE ( dim_indikator[malverdi] )
```

**Description:** Nasjonalt styringsmål for indikatoren, der et slikt er vedtatt.
Tom når indikatoren ikke har et vedtatt mål — rapporten skal da ikke tegne mållinje.

---

### Avvik mot mål

```dax
Avvik mot mål =
VAR _Mål = [Målverdi]
RETURN
    IF ( NOT ISBLANK ( _Mål ), [Verdi (riktig aggregert)] - _Mål )
```

---

### Status mot mål

```dax
Status mot mål =
VAR _Avvik = [Avvik mot mål]
VAR _Retning = SELECTEDVALUE ( dim_indikator[retning] )
RETURN
    SWITCH (
        TRUE (),
        ISBLANK ( _Avvik ), "Ikke vurdert",
        _Retning = "Lavere er bedre" && _Avvik <= 0, "Innenfor mål",
        _Retning = "Høyere er bedre" && _Avvik >= 0, "Innenfor mål",
        _Retning = "Ingen retning", "Ikke vurdert",
        "Utenfor mål"
    )
```

**Description:** Vurderer avviket mot indikatorens egen retning. En ventetid som går
ned og et antall pasienter som går ned betyr ikke det samme, og retningen er derfor
lagt i modellen framfor å skrives på nytt for hver figur.

---

### Farge status

```dax
Farge status =
SWITCH (
    [Status mot mål],
    "Innenfor mål", "#1B7F5F",
    "Utenfor mål",  "#B03A2E",
    "#7B7B7B"
)
```

**Description:** Betinget formatering. Brukes under *Format > Farge > fx > Feltverdi*.
Grå brukes bevisst for «ikke vurdert» slik at fravær av vurdering ikke leses som
et dårlig resultat.

---

## 5. Referanselinje (den som gjør RLS brukbar)

### Verdi nasjonalt

```dax
Verdi nasjonalt =
CALCULATE (
    [Verdi (riktig aggregert)],
    REMOVEFILTERS ( dim_enhet ),
    dim_enhet[enhet_navn] = "Landet"
)
```

**Description:** Nasjonalt nivå uavhengig av hvilken enhet som er valgt. Dette er
sammenligningsgrunnlaget som gjør et enkelt foretakstall tolkbart.

---

### Avvik fra nasjonalt

```dax
Avvik fra nasjonalt =
VAR _Nasjonalt = [Verdi nasjonalt]
RETURN
    IF ( NOT ISBLANK ( _Nasjonalt ), [Verdi (riktig aggregert)] - _Nasjonalt )
```

---

## 6. Åpenhet om datagrunnlaget

### Sist oppdatert

```dax
Sist oppdatert =
"Uttrekk: " & MAX ( fact_indikator[uttrekksdato] )
```

**Description:** Dato for siste uttrekk fra kilden. Står synlig i rapporten fordi
en leder som ser et tall skal vite hvor gammelt det er.

---

### Kildehenvisning

```dax
Kildehenvisning =
"Kilde: Norsk pasientregister (Folkehelseinstituttet) og Nasjonale kvalitetsindikatorer (Helsedirektoratet). Gjengitt under NLOD."
```

**Description:** NLOD krever at kilde oppgis. Målet plasseres i en kortvisning
nederst på hver side.

---

### Forbehold aktiv periode

```dax
Forbehold aktiv periode =
VAR _Type = SELECTEDVALUE ( dim_periode[periodetype], "Blandet" )
VAR _Prikket = [Andel prikket]
VAR _Kumulativ =
    IF (
        _Type = "Kumulativ",
        "Perioden er kumulativ fra januar og kan ikke summeres med andre perioder. ",
        ""
    )
VAR _Skjult =
    IF (
        _Prikket > 0.2,
        "Over 20 % av grunnlaget er skjult av personvernhensyn. ",
        ""
    )
VAR _Blandet =
    IF (
        _Type = "Blandet",
        "Utvalget blander kumulative perioder og tertialer. ",
        ""
    )
VAR _Tekst = _Kumulativ & _Skjult & _Blandet
RETURN
    IF ( _Tekst <> "", "Forbehold: " & TRIM ( _Tekst ) )
```

**Description:** Viser forbehold som gjelder akkurat det utvalget brukeren har gjort.
Et forbehold som står i et vedlegg blir ikke lest; et forbehold som dukker opp når
det gjelder, blir det.

---

## 7. Beregningsgruppe: `Analyse`

Lages i Tabular Editor (`Model > Calculation Groups > New`). Kolonnen heter `Analyse`.
Beregningsgrupper gjør at ett og samme mål kan vises som verdi, endring eller avvik
uten at det må lages tre versjoner av hver figur.

| Beregningselement | Ordinal | Uttrykk |
|---|---|---|
| Verdi | 0 | `SELECTEDMEASURE ()` |
| I fjor | 1 | `CALCULATE ( SELECTEDMEASURE (), REMOVEFILTERS ( dim_periode ), dim_periode[sortering] = SELECTEDVALUE ( dim_periode[sortering_i_fjor] ) )` |
| Endring | 2 | `SELECTEDMEASURE () - CALCULATE ( SELECTEDMEASURE (), REMOVEFILTERS ( dim_periode ), dim_periode[sortering] = SELECTEDVALUE ( dim_periode[sortering_i_fjor] ) )` |
| Endring % | 3 | `VAR _F = CALCULATE ( SELECTEDMEASURE (), REMOVEFILTERS ( dim_periode ), dim_periode[sortering] = SELECTEDVALUE ( dim_periode[sortering_i_fjor] ) ) RETURN DIVIDE ( SELECTEDMEASURE () - _F, _F )` |
| Mot landet | 4 | `SELECTEDMEASURE () - CALCULATE ( SELECTEDMEASURE (), REMOVEFILTERS ( dim_enhet ), dim_enhet[enhet_navn] = "Landet" )` |

Sett `FormatString`-uttrykk på elementet «Endring %» til `"0.0 %"`, ellers arver det
formatet fra grunnmålet og viser 0,0 for alt.

---

## 8. Radnivåsikkerhet

To roller. Begge defineres under *Modellering > Håndter roller*.

**Rolle `HF-leder`** — filter på `bro_enhet_rls`:

```dax
[brukerprinsipal] = USERPRINCIPALNAME ()
```

`bro_enhet_rls` filtrerer `dim_enhet` gjennom en enveis relasjon på `enhet_id`.
Brukeren ser dermed eget foretak med `tilgangstype = "Detalj"` og landet og egen
region med `tilgangstype = "Referanse"`.

**Rolle `Analytiker`** — ingen filtre. Ser alt.

Testes med *Modellering > Vis som* og en av e-postadressene i `bro_enhet_rls`.

> Selve poenget med å skille `Detalj` fra `Referanse`: en leder som bare får se
> sitt eget foretak mister sammenligningen som gjør tallet tolkbart, mens en leder
> som får se alt kan bore seg ned i et annet foretaks tall. Brotabellen løser
> begge deler samtidig.
