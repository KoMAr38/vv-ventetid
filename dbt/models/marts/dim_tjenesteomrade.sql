{{ config(materialized='table') }}

select
    {{ dbt_utils.generate_surrogate_key(['tjenesteomrade_navn']) }} as tjenesteomrade_id,
    tjenesteomrade_navn,
    case
        when tjenesteomrade_navn ilike '%Somatikk%' then 'SOM'
        when tjenesteomrade_navn ilike '%voksne%'   then 'PHV'
        when tjenesteomrade_navn ilike '%barn%'     then 'PHBU'
        when tjenesteomrade_navn ilike '%rus%'      then 'TSB'
        -- NKI oppgir Sektor, ikke tjenesteomrade. "Spesialisthelsetjenesten"
        -- spenner over alle fire omradene og er derfor ikke sammenlignbar
        -- med SOM/PHV/PHBU/TSB. Den far egen kode slik at den ikke
        -- havner i samme figur som et enkelt tjenesteomrade.
        when tjenesteomrade_navn ilike '%Spesialisthelsetjenesten%' then 'ALLE'
        else 'ANNET'
    end as tjenesteomrade_kode
from (select distinct tjenesteomrade_navn from {{ ref('int_indikator_forent') }})
