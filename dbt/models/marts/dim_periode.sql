{{ config(materialized='table') }}

/*
  Periodedimensjon.

  Spesialisthelsetjenesten rapporterer i tertialer, ikke maneder. Power BI sin
  innebygde tidsintelligens forutsetter en sammenhengende datokolonne og
  fungerer derfor ikke her. Losningen er en eksplisitt periodetabell med en
  sorteringsnokkel, og egne mal for endring over tid som slar opp forrige ar
  pa samme tertial.

  Kolonnen er_kumulativ er viktig: NPR publiserer "januar-april" og
  "januar-august" som kumulative perioder, ikke som frittstaende tertialer.
  Summerer man dem sammen med "hele aret" teller man samme pasient tre ganger.
  Derfor skiller modellen dem, og rapporten filtrerer alltid pa en av delene.
*/

with grunnlag as (
    select distinct aar, periode_nr, er_kumulativ
    from {{ ref('int_indikator_forent') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['aar','periode_nr','er_kumulativ']) }} as periode_id,
    aar,
    periode_nr,
    er_kumulativ,
    case
        when er_kumulativ and periode_nr = 1 then 'januar-april'
        when er_kumulativ and periode_nr = 2 then 'januar-august'
        when er_kumulativ and periode_nr = 3 then 'hele året'
        else 'T' || periode_nr
    end                                                    as periode_navn,
    cast(aar as varchar) || ' ' ||
    case
        when er_kumulativ and periode_nr = 1 then 'jan-apr'
        when er_kumulativ and periode_nr = 2 then 'jan-aug'
        when er_kumulativ and periode_nr = 3 then 'hele året'
        else 'T' || periode_nr
    end                                                    as periode_etikett,
    aar * 10 + periode_nr                                  as sortering,
    case when er_kumulativ then 'Kumulativ' else 'Tertial' end as periodetype,
    -- Foregaende ar, samme periode. Brukes av malet for endring ar over ar.
    (aar - 1) * 10 + periode_nr                            as sortering_i_fjor
from grunnlag
