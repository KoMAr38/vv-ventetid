# Forbehold

Denne fila er ikke pynt. Den er grunnen til at rapporten kan brukes i et
ledermøte uten at noen tar en beslutning på et tall som ikke tåler den.

Alle forbehold under er hentet fra kildene selv, ikke vurdert av meg.
Forbeholdene som gjelder det aktive utvalget vises i rapporten via målet
`Forbehold aktiv periode` og på siden **Metode**.

---

## 1. Registreringspraksis varierer mellom helseforetak

Helsedirektoratet skriver selv at veilederen for registrering av ventelister og
frister har et tolkningsrom, at journalsystemene ikke har god nok funksjonalitet
for oppfølging av frister, og at det er forskjeller mellom helseforetakene i
rutiner ved mottak og registrering av henvisninger. Ulik opplæring i kodepraksis
gir varierende datakvalitet.

**Konsekvens for rapporten:** forskjeller mellom foretak kan like gjerne være
forskjeller i registrering som forskjeller i tjenesten. Sammenligning mellom
foretak er derfor lagt på en egen side med eksplisitt forbehold, ikke på
forsiden.

---

## 2. Ikke-reelle fristbrudd

Et gjennomgående problem er fristbrudd som oppstår fordi «ventetid slutt» ikke
er registrert, ikke fordi pasienten faktisk ventet for lenge. Etterslep etter
pandemien økte omfanget.

**Konsekvens:** andel fristbrudd er en indikator på både tjeneste og
registreringskvalitet samtidig. Den kan ikke leses som ren tjenestekvalitet.

Dette er den direkte koblingen til Prosjekt 2 i porteføljen, som viser hva
slike registreringshull gjør med et styringstall.

---

## 3. Helse Midt-Norge 2022–2024

Innføring av nytt pasientjournalsystem ved helseforetakene i Helse Midt-Norge i
perioden november 2022 til november 2024 førte til mangler og feil i
datagrunnlaget innrapportert til NPR. Innføringen påvirket også aktiviteten.

**Konsekvens:** tall for Helse Midt-Norge og for landet i denne perioden er
usikre. Rapporten merker perioden på siden **Utvikling**.

---

## 4. Prikking av lave tall

Kilden skjuler tall der pasientgrunnlaget er lavt. Hvis nevneren er under 5,
vises ikke enheten. Enkelte indikatorer skjules også når telleren er mellom 1 og 4.

**Konsekvens:** en manglende verdi betyr «skjult», ikke «null». Modellen beholder
raden med `verdi = null` og `er_prikket = true`, og rapporten viser
«skjult av personvernhensyn» framfor å tegne et hull i kurven. Målet
`Andel prikket` sier hvor mye av grunnlaget som er borte.

---

## 5. Helsedirektoratet og FHI publiserer ulike tall for fristbrudd

Andelen fristbrudd publisert av de to etatene kan avvike fra hverandre.
Årsaken er at Helsedirektoratet kun inkluderer pasienter med en gyldig frist i
nevneren.

**Konsekvens:** de to kildene må aldri blandes i samme figur. Kolonnen
`datakilde` i faktatabellen finnes nettopp for å hindre det, og rapporten
oppgir hvilken kilde hver figur bruker.

---

## 6. Covid-19 i 2020

Plikten til å fastsette frist og varsle Helfo ved fristbrudd bortfalt i store
deler av 2020. Datagrunnlaget tar ikke høyde for dette.

**Konsekvens:** 2020 viser ikke en reell andel fristbrudd og er utelatt fra
trendberegninger. Året er beholdt i modellen, men merket.

---

## 7. Foreløpige mot endelige tall

NPR-nøkkeltallene oppdateres tre ganger i året:

| Periode | Publiseres | Status |
|---|---|---|
| januar–april | juni | foreløpig |
| januar–august | oktober | foreløpig |
| hele året | mars året etter | endelig |

Ved publisering i oktober oppdateres også tallene for januar–april.

**Konsekvens:** et tall kan endre seg uten at det er en feil i pipelinen.
Derfor skriver `hent_npr.py` et manifest med sha256 og uttrekksdato for hver
råfil, og `fact_indikator` bærer kolonnen `uttrekksdato`. Uten det kan man ikke
i ettertid skille «kilden republiserte» fra «vi innførte en feil».

---

## 8. Kumulative perioder

NPR publiserer «januar–april» og «januar–august» kumulativt fra årets start,
ikke som frittstående tertialer. «januar–august» er tertial 1 pluss tertial 2.

**Konsekvens:** summerer man de tre periodene, telles samme pasient tre ganger.
Kolonnen `er_kumulativ` skiller dem, og rapporten filtrerer alltid på én
periodetype om gangen.

---

## 9. Ventetidsløftet — det åpne spørsmålet

Fra 1. tertial 2025 til 1. tertial 2026 falt gjennomsnittlig ventetid i somatikk
fra 75 til 64 dager. Tilsvarende fall skjedde i psykisk helsevern for voksne
(51 til 43), for barn og unge (46 til 41) og i rusbehandling (28 til 27).
I samme periode falt antall pasienter i somatikk fra 1 654 620 til 1 614 030.

Dette er den største enkeltendringen i datasettet, og rapporten viser den uten
å tolke den. Spørsmålet som må stilles før tallet brukes som resultat:

- er nedgangen reell tjenesteforbedring
- eller er den delvis en effekt av endret registreringspraksis under
  Ventetidsløftet
- og hva betyr det at ventetiden faller samtidig som antall pasienter faller

Rapporten svarer ikke på dette. Det er en analysejobb som krever grunndata og
dialog med fagmiljøet, ikke et dashboard. Men den viser begge kurvene sammen,
slik at spørsmålet er umulig å overse.

---

## Kilder for forbeholdene

- Helsedirektoratet, Nasjonale kvalitetsindikatorer — forbeholdstekster i den
  enkelte indikators artikkel
- Helsedirektoratet, «Eksport av data fra de nasjonale kvalitetsindikatorene»
- Folkehelseinstituttet, Norsk pasientregister — «Om statistikken» i
  tabellmetadata, hentes automatisk av `hent_npr.py`
- Folkehelseinstituttet, «Ventetider og aktivitet i spesialisthelsetjenesten
  1. tertial 2026», publisert 23.06.2026

---

## 10. Regional referanse er bostedsregion, ikke foretaksgruppe

Vestre Viken HF er et datterselskap av Helse Sør-Øst RHF. Men NPR aggregerer
etter **pasientens bostedsregion**, ikke etter hvilken foretaksgruppe sykehuset
tilhører. Den eneste regionale raden som faktisk finnes i modellen er derfor
«Region Sør-Øst», ikke «Helse Sør-Øst RHF».

Kolonnen `forelder_navn` i `dim_enhet` er organisatorisk korrekt og oppgir
foretaksgruppen. Kolonnen `referanseregion` peker på den regionale enheten som
finnes i dataene, og det er den brotabellen for radnivåsikkerhet bruker.

**Konsekvens:** en pasient bosatt i Buskerud som behandles ved Oslo
universitetssykehus teller i Region Sør-Øst uansett. Regional referanselinje
er derfor et geografisk sammenligningsgrunnlag, ikke summen av foretakene i
gruppen. De to tallene er nær hverandre, men ikke like.

Feilen ble oppdaget da radnivåsikkerheten ble testet: rollen for Vestre Viken
fikk detaljtilgang til eget foretak og referanse til landet, men ingen regional
referanse i det hele tatt. Joinen mot `forelder_navn` traff ingenting og feilet
stille — ingen feilmelding, bare en manglende rad.
