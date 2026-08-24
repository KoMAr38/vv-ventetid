# Datamodell

## Kornnivå

`fact_indikator` har ett kornnivå:

> én enhet, én periode, ett tjenesteområde, én aktør, én indikator → én verdi

Alt annet i modellen følger av det. Kornnivået er testet i dbt med
`unique_combination_of_columns` på nettopp de fem nøklene, slik at en endring
i kilden som ville brutt det stopper bygget i stedet for å dukke opp som
dobbelte tall i rapporten.

---

## Hvorfor stjerneskjema og ikke én flat tabell

En flat tabell hadde vært raskere å lage og fungert helt fint på 5 320 rader.
Valget er likevel stjerneskjema, av tre grunner som gjelder uavhengig av
datamengde:

**Ett sted å rette.** Når en indikator skifter navn hos kilden, rettes det i
`dim_indikator` og ikke i hver eneste rad i fakta.

**Filtrering går én vei.** I en stjerne vet man alltid hvilken retning et filter
forplanter seg. I en flat tabell eller et snøfnugg med toveisrelasjoner må man
resonnere om det hver gang man skriver et mål, og det er der de fleste feilene i
DAX oppstår.

**Kolonnelagring komprimerer heltall bedre enn tekst.** Faktatabellen inneholder
derfor bare nøkler og tall. Det spiller ingen rolle her, men det er den vanen
som gjelder når modellen vokser.

---

## Tabellene

### `fact_indikator`

| Kolonne | Type | Merknad |
|---|---|---|
| `enhet_id` | tekst | nøkkel til `dim_enhet` |
| `periode_id` | tekst | nøkkel til `dim_periode` |
| `indikator_id` | tekst | nøkkel til `dim_indikator` |
| `tjenesteomrade_id` | tekst | nøkkel til `dim_tjenesteomrade` |
| `aktor_navn` | tekst | degenerert dimensjon — bare tre verdier, egen tabell hadde ikke lønt seg |
| `verdi` | desimal | kan være null når raden er prikket |
| `er_prikket` | boolsk | true når kilden har skjult tallet |
| `flagg` | tekst | kvalitetsflagg fra NPR |
| `uttrekksdato` | tekst | hvilket uttrekk raden stammer fra |
| `datakilde` | tekst | NPR eller NKI — hindrer at kildene blandes i samme figur |

Nøklene er surrogatnøkler laget med `generate_surrogate_key` i dbt. Naturlige
nøkler er ikke brukt fordi enhetsnavn og indikatornavn endrer seg hos kilden
uten varsel, og en nøkkel som endrer seg er ikke en nøkkel.

### `dim_enhet`

Tre nivåer: Nasjonalt > Region > Helseforetak. Mappingen ligger i seed-tabellen
`enhet_mapping.csv`, ikke i SQL. Enheter som dukker opp i en eksport uten å stå
i seeden får `er_umappet = 1` og fanges av en dbt-test.

Kolonnen `er_referanse` merker «Landet» og brukes av målet `Verdi nasjonalt`.

### `dim_periode`

Nøkkelen er `aar * 10 + periode_nr`. Det gir en sorterbar heltallsnøkkel uten å
måtte lage datoer som ikke finnes.

`sortering_i_fjor` er forhåndsberegnet i dbt framfor å regnes i DAX. Det er et
bevisst valg: beregninger som ikke avhenger av brukerens filtervalg hører hjemme
i transformasjonslaget, ikke i målene.

`er_kumulativ` skiller NPRs kumulative perioder fra NKIs frittstående tertialer.
Se `forbehold.md` punkt 8.

### `dim_indikator`

Bærer `enhet` (Antall / Dager / Prosent), `retning` (Lavere er bedre / Høyere er
bedre / Ingen retning) og `malverdi`.

Retningen ligger her og ikke i DAX. Uten det måtte fargelegging av avvik skrives
på nytt for hver indikator — en ventetid som går ned er grønt, et antall
pasienter som går ned er ikke det.

### `bro_enhet_rls`

Brotabell for radnivåsikkerhet. Hver rolle får:

- `tilgangstype = 'Detalj'` for egen enhet
- `tilgangstype = 'Referanse'` for egen region og for landet

Relasjonen til `dim_enhet` er **enveis** på `enhet_id`, og tabellen er skjult i
rapportvisning.

---

## Relasjoner

| Fra | Til | Kardinalitet | Retning |
|---|---|---|---|
| `dim_enhet[enhet_id]` | `fact_indikator[enhet_id]` | én til mange | enkel |
| `dim_periode[periode_id]` | `fact_indikator[periode_id]` | én til mange | enkel |
| `dim_indikator[indikator_id]` | `fact_indikator[indikator_id]` | én til mange | enkel |
| `dim_tjenesteomrade[tjenesteomrade_id]` | `fact_indikator[tjenesteomrade_id]` | én til mange | enkel |
| `bro_enhet_rls[enhet_id]` | `dim_enhet[enhet_id]` | mange til én | **enkel, filtrerer dim_enhet** |

Ingen toveisrelasjoner. Ingen mange-til-mange.

---

## Lagringsmodus

Import. Datamengden er 5 320 rader og vokser med noen hundre i året. DirectQuery
ville gitt dårligere ytelse og fjernet muligheten for beregningsgrupper uten å gi
noe tilbake.

Valget er tatt bevisst og ikke som standardinnstilling. I en løsning mot et
datavarehus med sensitive helsedata i lokal infrastruktur ville avveiningen vært
en annen, fordi da handler det om hvor dataene får ligge, ikke bare om ytelse.

---

## Hva som ville vært annerledes i produksjon

- Mart-laget ville vært tabeller i et datavarehus, ikke CSV-filer
- Surrogatnøklene ville vært heltall fra en sekvens, ikke hashverdier
- `bro_enhet_rls[brukerprinsipal]` ville vært fylt fra Entra ID, ikke fra en
  konstruert e-postadresse
- Inkrementell oppdatering på faktatabellen ville vært satt opp mot
  `uttrekksdato`
- dbt ville kjørt i CI ved hver commit, ikke lokalt
