{{ config(materialized='view') }}

/*
  Leser alle daterte NPR-uttrekk i data/raw/ og setter dem sammen.
  Filnavnet baerer bade tjenesteomrade og uttrekksdato, og begge deler
  tas vare pa som kolonner. Da kan man i ettertid se hvilket uttrekk
  et tall stammer fra - noe man trenger nar kilden republiserer
  forelopige tall som endelige.

  Kilden leverer maltall som kolonner (bred form). Vi snur til lang form
  slik at fakta far ett tall per rad. Det er det formatet en stjerneskjema-
  modell vil ha, og det gjor at nye maltall hos FHI ikke krever ny kolonne
  i modellen.
*/

with raa as (
    select
        "År"                                  as aar,
        "Periode"                             as periode_navn,
        "Tjenesteområde"                      as tjenesteomrade_navn,
        "Aktører"                             as aktor_navn,
        "Bostedsregion"                       as enhet_navn,
        "Antall pasienter"                    as ant_pas,
        "Antall pasienter i døgnbehandling"   as ant_pas_dogn,
        "Antall oppholdsdøgn"                 as ant_opp_dogn,
        try_cast(null as varchar)             as ant_dognopp,
        "Antall kontakter i poliklinikk"      as ant_kont_pol,
        try_cast(null as varchar)             as ant_dagbeh,
        "FLAGG"                               as flagg,
        filename                              as kildefil
    from read_csv(
        '../data/raw/npr_ph*.csv',
        delim = ';', header = true, filename = true, all_varchar = true, union_by_name = true
    )

    union all by name

    select
        "År"                                  as aar,
        "Periode"                             as periode_navn,
        "Tjenesteområde"                      as tjenesteomrade_navn,
        "Aktører"                             as aktor_navn,
        "Bostedsregion"                       as enhet_navn,
        "Antall pasienter"                    as ant_pas,
        "Antall pasienter i døgnbehandling"   as ant_pas_dogn,
        "Antall oppholdsdøgn"                 as ant_opp_dogn,
        try_cast(null as varchar)             as ant_dognopp,
        "Antall kontakter i poliklinikk"      as ant_kont_pol,
        try_cast(null as varchar)             as ant_dagbeh,
        "FLAGG"                               as flagg,
        filename                              as kildefil
    from read_csv(
        '../data/raw/npr_tsb*.csv',
        delim = ';', header = true, filename = true, all_varchar = true, union_by_name = true
    )

    union all by name

    select
        "År"                                  as aar,
        "Periode"                             as periode_navn,
        "Tjenesteområde"                      as tjenesteomrade_navn,
        "Aktører"                             as aktor_navn,
        "Bostedsregion"                       as enhet_navn,
        "Antall pasienter"                    as ant_pas,
        "Antall pasienter i døgnbehandling"   as ant_pas_dogn,
        "Antall oppholdsdøgn"                 as ant_opp_dogn,
        "Antall døgnopphold"                  as ant_dognopp,
        "Antall kontakter i poliklinikk"      as ant_kont_pol,
        "Antall dagbehandlinger"              as ant_dagbeh,
        "FLAGG"                               as flagg,
        filename                              as kildefil
    from read_csv(
        '../data/raw/npr_som*.csv',
        delim = ';', header = true, filename = true, all_varchar = true, union_by_name = true
    )
),

lang as (
    select aar, periode_navn, tjenesteomrade_navn, aktor_navn, enhet_navn,
           flagg, kildefil, 'ANT_PAS'      as maltall_kode, ant_pas      as verdi_tekst from raa
    union all
    select aar, periode_navn, tjenesteomrade_navn, aktor_navn, enhet_navn,
           flagg, kildefil, 'ANT_PAS_DOGN' as maltall_kode, ant_pas_dogn as verdi_tekst from raa
    union all
    select aar, periode_navn, tjenesteomrade_navn, aktor_navn, enhet_navn,
           flagg, kildefil, 'ANT_OPP_DOGN' as maltall_kode, ant_opp_dogn as verdi_tekst from raa
    union all
    select aar, periode_navn, tjenesteomrade_navn, aktor_navn, enhet_navn,
           flagg, kildefil, 'ANT_DOGNOPP'  as maltall_kode, ant_dognopp  as verdi_tekst from raa
    union all
    select aar, periode_navn, tjenesteomrade_navn, aktor_navn, enhet_navn,
           flagg, kildefil, 'ANT_KONT_POL' as maltall_kode, ant_kont_pol as verdi_tekst from raa
    union all
    select aar, periode_navn, tjenesteomrade_navn, aktor_navn, enhet_navn,
           flagg, kildefil, 'ANT_DAGBEH'   as maltall_kode, ant_dagbeh   as verdi_tekst from raa
)

select
    cast(aar as integer)                                    as aar,
    periode_navn,
    tjenesteomrade_navn,
    aktor_navn,
    trim(enhet_navn)                                        as enhet_navn,
    maltall_kode,
    try_cast(replace(verdi_tekst, ' ', '') as double)       as verdi,
    nullif(trim(coalesce(flagg, '')), '')                   as flagg,
    regexp_extract(kildefil, '(\d{4}-\d{2}-\d{2})', 1)      as uttrekksdato,
    'NPR'                                                   as datakilde
from lang
where verdi_tekst is not null
  and trim(verdi_tekst) <> ''
