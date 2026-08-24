{{ config(materialized='table') }}

/*
  Enhetsdimensjon med tre niva: Nasjonalt > Region > Helseforetak.

  Navnene i kildene mappes mot seed-tabellen enhet_mapping. Enheter som ikke
  finnes i seeden far niva "Ukjent" i stedet for a bli kastet bort. Det er et
  bevisst valg: en rad som forsvinner stille er verre enn en rad som er
  synlig feil, fordi den forste ikke kan oppdages i rapporten.
*/

with fra_data as (
    select distinct enhet_navn
    from {{ ref('int_indikator_forent') }}
),

koblet as (
    select
        d.enhet_navn,
        coalesce(m.enhet_niva,
            case
                when d.enhet_navn ilike '%RHF' or d.enhet_navn ilike 'Region %'  then 'Region'
                when d.enhet_navn ilike '%HF'                                    then 'Helseforetak'
                -- Private ideelle sykehus rapporterer pa samme niva som et
                -- helseforetak selv om de ikke heter HF.
                when d.enhet_navn ilike '%sykehus%'
                  or d.enhet_navn ilike '%sjukehus%'
                  or d.enhet_navn ilike '%klinikk%'
                  or d.enhet_navn ilike '%Hospital%'                             then 'Helseforetak'
                when d.enhet_navn ilike '%legevakt%'                             then 'Legevakt'
                -- Eksport pa kommunenivaet drar inn flere hundre kommuner.
                -- De er ikke feil, men de horer ikke hjemme i et
                -- foretaksdashbord og filtreres bort i rapporten.
                else 'Kommune eller annet'
            end)                                as enhet_niva,
        coalesce(nullif(m.forelder_navn, '-'), 'Ukjent') as forelder_navn,
        coalesce(m.kortnavn, d.enhet_navn)      as kortnavn,
        nullif(m.referanseregion, '-')          as referanseregion,
        case when m.enhet_navn is null then 1 else 0 end as er_umappet
    from fra_data d
    left join {{ ref('enhet_mapping') }} m on m.enhet_navn = d.enhet_navn
)

select
    {{ dbt_utils.generate_surrogate_key(['enhet_navn']) }} as enhet_id,
    enhet_navn,
    kortnavn,
    enhet_niva,
    case enhet_niva
        when 'Nasjonalt'    then 1
        when 'Region'       then 2
        when 'Helseforetak' then 3
        when 'Legevakt'     then 4
        else 9
    end                                                    as niva_nr,
    -- Rapporten viser bare de tre overste nivaene. De ovrige beholdes i
    -- modellen slik at de kan telles, men skjules med et filter pa sidene.
    case when enhet_niva in ('Nasjonalt','Region','Helseforetak') then 1 else 0 end as vis_i_rapport,
    forelder_navn,
    referanseregion,
    er_umappet,
    case when enhet_navn = 'Landet' then 1 else 0 end       as er_referanse,
    case when enhet_navn = 'Vestre Viken HF' then 1 else 0 end as er_eget_foretak
from koblet
