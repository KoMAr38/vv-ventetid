{{ config(materialized='table') }}

/*
  Brotabell for radniva-sikkerhet.

  Poenget med denne tabellen er en nyanse som ofte gjores feil: en leder som
  bare far se sitt eget foretak mister samtidig referansen som gjor tallet
  meningsfullt. 62 dagers ventetid sier ingenting alene.

  Losningen er at hver bruker kobles til to slags rader:
    - "Detalj" for egen enhet
    - "Referanse" for nasjonalt niva og egen region

  Rapporten kan da vise eget foretak i detalj og landet som en sammenlignings-
  linje, uten at brukeren kan bore seg ned i et annet foretaks tall.

  Kolonnen brukerprinsipal fylles med e-postadresser i drift. Her star det
  rollenavn, siden dette er et portefoljeprosjekt uten Entra ID bak seg.
*/

with enheter as (
    select enhet_id, enhet_navn, enhet_niva, forelder_navn, referanseregion
    from {{ ref('dim_enhet') }}
),

-- Hver enhet pa helseforetaksniva blir en "rolle"
roller as (
    -- referanseregion, ikke forelder_navn. NPR aggregerer etter pasientens
    -- bostedsregion, ikke etter foretaksgruppe, og det er bostedsregionen
    -- som faktisk finnes som rad i modellen. Se forbehold.md punkt 10.
    select enhet_navn as rolle_enhet, referanseregion as rolle_region
    from enheter
    where enhet_niva = 'Helseforetak'
),

tilgang as (
    -- egen enhet, full detalj
    select r.rolle_enhet, e.enhet_id, 'Detalj' as tilgangstype
    from roller r
    join enheter e on e.enhet_navn = r.rolle_enhet

    union all

    -- egen region, kun som referanse
    select r.rolle_enhet, e.enhet_id, 'Referanse' as tilgangstype
    from roller r
    join enheter e on e.enhet_navn = r.rolle_region

    union all

    -- nasjonalt niva, kun som referanse
    select r.rolle_enhet, e.enhet_id, 'Referanse' as tilgangstype
    from roller r
    join enheter e on e.enhet_niva = 'Nasjonalt'
)

select distinct
    rolle_enhet                             as rolle,
    lower(replace(rolle_enhet, ' ', '.')) || '@eksempel.no' as brukerprinsipal,
    enhet_id,
    tilgangstype
from tilgang
