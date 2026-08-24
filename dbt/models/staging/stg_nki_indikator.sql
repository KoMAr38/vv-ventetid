{{ config(materialized='view') }}

/*
  Manuell eksport fra Helsedirektoratets NKI-eksportvisning.

  Eksporten er mindre forutsigbar enn et API, og denne modellen handterer
  fem ting som varierer mellom uttrekk. Alle fem er reelle og observert:

  1) SKILLETEGN. Eksporten kommer med komma, ikke semikolon, selv om
     Excel-varianten bruker semikolon. Vi lar DuckDB kjenne igjen formatet
     selv i stedet for a lase det. En hardkodet delimiter gir ikke feilmelding
     nar den er feil - den gir en tabell med en eneste kolonne, og radene
     forsvinner stille lenger nede i modellen.

  2) PROSENTTEGN. Verdier kommer som "69,0%" og "95,4%", mens andre er rene
     tall som 227 eller 1,06. Bade prosenttegn, mellomrom og komma ma bort
     for konvertering. Verdien lagres som andel av hundre, ikke som 0-1,
     slik at et snitt av flere prosenttall gir mening.

  3) PERIODEFORMAT. Tidsperiode kan vaere bare ar ("2025") eller ar med
     tertial ("2025T1"), avhengig av indikator. Begge stottes. Ar uten
     tertial far periode_nr = 3, som er hele aret.

  4) ID-KOLONNER. Nyere eksporter har QualityIndicatorID og LocationId.
     Det er stabile nokler som ikke endrer seg nar en indikator skifter navn,
     og de brukes derfor nar de finnes.

  5) UTFASEDE INDIKATORER. Enkelte navn begynner med "Utfaset - ". De maler
     ofte det samme som en gjeldende indikator, men med en annen definisjon.
     De merkes og holdes utenfor rapporten, framfor a blandes inn i en
     tidsserie der bruddet blir usynlig.
*/

with raa as (
    select *
    from read_csv(
        '../data/manuell/*.csv',
        header = true,
        all_varchar = true,
        filename = true,
        union_by_name = true,
        auto_detect = true,
        ignore_errors = true
    )
),

rensket as (
    select
        trim("Tidsperiode")                                     as periode_kode,
        trim("Kvalitetsindikator")                              as indikator_navn,
        trim("Måltall")                                         as maltall_navn,
        trim("Lokasjon")                                        as enhet_navn,
        trim("Sektor")                                          as sektor,
        trim("Nivå")                                            as niva,
        nullif(trim(coalesce("Verdi", '')), '')                 as verdi_tekst,
        try_cast("QualityIndicatorID" as varchar)               as indikator_id_kilde,
        try_cast("LocationId" as varchar)                       as enhet_id_kilde,
        filename                                                as kildefil
    from raa
    where "Tidsperiode" is not null
),

tolket as (
    select
        periode_kode,
        try_cast(regexp_extract(periode_kode, '^(\d{4})', 1) as integer)  as aar,
        -- "2025T1" gir tertial 1. Bare "2025" gir hele aret, altsa 3.
        coalesce(
            try_cast(nullif(regexp_extract(periode_kode, '[Tt](\d)', 1), '') as integer),
            3
        )                                                                  as periode_nr,
        indikator_navn,
        maltall_navn,
        enhet_navn,
        sektor,
        niva,
        indikator_id_kilde,
        enhet_id_kilde,
        verdi_tekst,
        -- Prosenttegn, mellomrom, harde mellomrom og komma bort for casting.
        try_cast(
            replace(replace(replace(replace(verdi_tekst, '%', ''), ' ', ''), chr(160), ''), ',', '.')
            as double
        )                                                                  as verdi,
        case
            when verdi_tekst is null              then true
            when verdi_tekst in (':', '-', '..')  then true
            else false
        end                                                                as er_prikket,
        verdi_tekst like '%\%' escape '\'                                  as er_prosent,
        indikator_navn like 'Utfaset%'                                     as er_utfaset,
        kildefil
    from rensket
)

select
    periode_kode,
    aar,
    periode_nr,
    indikator_navn,
    maltall_navn,
    enhet_navn,
    sektor,
    niva,
    indikator_id_kilde,
    enhet_id_kilde,
    verdi,
    er_prikket,
    er_prosent,
    er_utfaset,
    kildefil,
    'NKI' as datakilde
from tolket
-- Malfila skal aldri havne i modellen. Den finnes bare for a teste roret.
where indikator_navn is not null
  and indikator_navn not like 'MAL %'
  and aar is not null
