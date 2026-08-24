{{ config(materialized='view') }}

/*
  Forener to kilder med ulik form til ett felles kornniva:
      en enhet, en periode, ett maltall, en verdi.

  Dette er det egentlige modelleringsarbeidet. NPR gir aktivitet pa regionniva
  i kumulative perioder ("januar-april"). NKI gir kvalitetsindikatorer pa
  RHF- eller helseforetaksniva, arlig eller per tertial. De to snakker ikke
  samme sprak om verken tid, sted eller maltall, og maten de bringes sammen pa
  avgjor hva rapporten i det hele tatt kan svare pa.

  Valg som er tatt her, og som star i dokumentasjon/forbehold.md:
    - NPR-perioder merkes som kumulative. "januar-august" er ikke tertial 2,
      det er tertial 1 + 2. Blander man dette, dobbelteller man aret.
    - NKI-rader uten tertial regnes som hele aret, og er ikke kumulative i
      samme forstand - de er endelige arstall.
    - Utfasede indikatorer folger med i modellen, men er merket, slik at de
      kan holdes utenfor en tidsserie framfor a lage et usynlig brudd i den.
*/

with npr as (
    select
        enhet_navn,
        aar,
        case periode_navn
            when 'januar-april'  then 1
            when 'januar-august' then 2
            when 'hele året'     then 3
        end                                     as periode_nr,
        true                                    as er_kumulativ,
        maltall_kode                            as indikator_kode,
        cast(null as varchar)                   as indikatorgruppe_navn,
        tjenesteomrade_navn,
        aktor_navn,
        verdi,
        false                                   as er_prikket,
        false                                   as er_prosent,
        false                                   as er_utfaset,
        flagg,
        datakilde,
        uttrekksdato
    from {{ ref('stg_npr_nokkeltall') }}
),

nki as (
    select
        enhet_navn,
        aar,
        periode_nr,
        false                                   as er_kumulativ,
        maltall_navn                            as indikator_kode,
        indikator_navn                          as indikatorgruppe_navn,
        sektor                                  as tjenesteomrade_navn,
        'Alle aktører'                          as aktor_navn,
        verdi,
        er_prikket,
        er_prosent,
        er_utfaset,
        cast(null as varchar)                   as flagg,
        datakilde,
        cast(null as varchar)                   as uttrekksdato
    from {{ ref('stg_nki_indikator') }}
),

forent as (
    select * from npr
    union all by name
    select * from nki
)

select
    {{ dbt_utils.generate_surrogate_key(['enhet_navn']) }}                      as enhet_id,
    {{ dbt_utils.generate_surrogate_key(['aar','periode_nr','er_kumulativ']) }} as periode_id,
    {{ dbt_utils.generate_surrogate_key(['indikatorgruppe_navn','indikator_kode','datakilde']) }} as indikator_id,
    {{ dbt_utils.generate_surrogate_key(['tjenesteomrade_navn']) }}             as tjenesteomrade_id,
    enhet_navn,
    aar,
    periode_nr,
    er_kumulativ,
    indikator_kode,
    indikatorgruppe_navn,
    tjenesteomrade_navn,
    aktor_navn,
    verdi,
    er_prikket,
    er_prosent,
    er_utfaset,
    flagg,
    datakilde,
    uttrekksdato
from forent
where periode_nr is not null
