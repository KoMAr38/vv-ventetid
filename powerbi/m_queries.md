# Power Query (M)

Alle spørringer bruker én felles parameter for mappebane. Uten den må banen
rettes seks steder når prosjektet flyttes, og det er den vanligste grunnen til
at en delt .pbip ikke lar seg åpne på en annen maskin.

---

## Parameter: `MartMappe`

Lages under **Hjem > Behandle parametere > Ny parameter**.

- Navn: `MartMappe`
- Type: Tekst
- Foreslått verdi: Enhver verdi
- Gjeldende verdi: `C:\prosjekt\vv-ventetid\data\mart\`

Avslutt banen med bakstrek.

---

## Felles funksjon: `fnLesMart`

**Hjem > Ny spørring > Tom spørring**, deretter **Avansert redigering**.
Navngi spørringen `fnLesMart`.

```m
let
    fnLesMart = (Filnavn as text) as table =>
        let
            Kilde = Csv.Document(
                File.Contents(MartMappe & Filnavn),
                [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
            ),
            Overskrifter = Table.PromoteHeaders(Kilde, [PromoteAllScalars = true])
        in
            Overskrifter
in
    fnLesMart
```

`Encoding = 65001` er UTF-8. Det er ikke standard i Power Query, og uten det blir
`Sør-Øst` til `SÃ¸r-Ãst`. Samme feilklasse som ble rettet i `hent_npr.py` —
tegnsett må settes eksplisitt i hvert ledd, ellers gjetter leddet feil.

---

## `dim_enhet`

```m
let
    Kilde = fnLesMart("dim_enhet.csv"),
    Typer = Table.TransformColumnTypes(
        Kilde,
        {
            {"enhet_id", type text},
            {"enhet_navn", type text},
            {"kortnavn", type text},
            {"enhet_niva", type text},
            {"niva_nr", Int64.Type},
            {"forelder_navn", type text},
            {"er_umappet", Int64.Type},
            {"er_referanse", Int64.Type},
            {"er_eget_foretak", Int64.Type}
        }
    )
in
    Typer
```

---

## `dim_periode`

```m
let
    Kilde = fnLesMart("dim_periode.csv"),
    Typer = Table.TransformColumnTypes(
        Kilde,
        {
            {"periode_id", type text},
            {"aar", Int64.Type},
            {"periode_nr", Int64.Type},
            {"er_kumulativ", type logical},
            {"periode_navn", type text},
            {"periode_etikett", type text},
            {"sortering", Int64.Type},
            {"periodetype", type text},
            {"sortering_i_fjor", Int64.Type}
        }
    )
in
    Typer
```

---

## `dim_indikator`

```m
let
    Kilde = fnLesMart("dim_indikator.csv"),
    Typer = Table.TransformColumnTypes(
        Kilde,
        {
            {"indikator_id", type text},
            {"indikator_kode", type text},
            {"indikator_navn", type text},
            {"datakilde", type text},
            {"enhet", type text},
            {"retning", type text},
            {"malverdi", type number},
            {"indikatorgruppe", type text}
        }
    )
in
    Typer
```

---

## `dim_tjenesteomrade`

```m
let
    Kilde = fnLesMart("dim_tjenesteomrade.csv"),
    Typer = Table.TransformColumnTypes(
        Kilde,
        {
            {"tjenesteomrade_id", type text},
            {"tjenesteomrade_navn", type text},
            {"tjenesteomrade_kode", type text}
        }
    )
in
    Typer
```

---

## `fact_indikator`

```m
let
    Kilde = fnLesMart("fact_indikator.csv"),
    Typer = Table.TransformColumnTypes(
        Kilde,
        {
            {"enhet_id", type text},
            {"periode_id", type text},
            {"indikator_id", type text},
            {"tjenesteomrade_id", type text},
            {"aktor_navn", type text},
            {"verdi", type number},
            {"er_prikket", type logical},
            {"flagg", type text},
            {"uttrekksdato", type text},
            {"datakilde", type text}
        }
    )
in
    Typer
```

`verdi` settes til `type number` og ikke `Int64.Type`. Grunnen er at NKI leverer
desimaler for andeler og gjennomsnitt, og en heltallskonvertering ville rundet
7,7 % fristbrudd til 8 uten å si fra.

---

## `bro_enhet_rls`

```m
let
    Kilde = fnLesMart("bro_enhet_rls.csv"),
    Typer = Table.TransformColumnTypes(
        Kilde,
        {
            {"rolle", type text},
            {"brukerprinsipal", type text},
            {"enhet_id", type text},
            {"tilgangstype", type text}
        }
    )
in
    Typer
```

Denne tabellen skal **ikke** lastes inn før NKI-eksporten ligger på plass —
uten helseforetaksnivå i dataene er den tom, og en tom tabell i en RLS-relasjon
filtrerer bort alt for rollen `HF-leder`.

---

## `_Mål`

Tom tabell som bare skal holde målene.

```m
let
    Kilde = Table.FromRows({}, type table [Kolonne = text])
in
    Kilde
```

Etter innlasting: høyreklikk kolonnen `Kolonne` i feltlista og velg **Skjul**.
Tabellen får da måleikonet og legger seg øverst i feltlista.
