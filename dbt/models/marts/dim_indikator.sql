{{ config(materialized='table') }}

/*
  Indikatordimensjon med retning, enhet og malverdi.

  For NKI er det Maltall som er den presise indikatoren, mens
  Kvalitetsindikator er en gruppe som samler flere maltall. Eksempel:
  gruppen "Gjennomsnittlig og median ventetid i somatisk helse" inneholder
  bade gjennomsnitt, median og totalt antall pabegynt helsehjelp. De tre kan
  ikke behandles likt, og modellen skiller dem derfor.

  Retningen ligger her og ikke i DAX. Uten det matte fargelegging av avvik
  skrives pa nytt for hver indikator: en ventetid som gar ned er gront, en
  epikrisetid som gar ned er ikke det.

  Malverdier er nasjonale styringsmal og skal ikke gjettes. Der en indikator
  ikke har et vedtatt mal, star malverdien som null og rapporten viser ingen
  mallinje. Kildehenvisning per malverdi ligger i dokumentasjon/maaltall.md.
*/

with grunnlag as (
    select
        indikator_kode,
        datakilde,
        indikatorgruppe_navn,
        max(case when er_prosent then 1 else 0 end) = 1     as er_prosent,
        max(case when er_utfaset then 1 else 0 end) = 1     as er_utfaset
    from {{ ref('int_indikator_forent') }}
    group by indikator_kode, datakilde, indikatorgruppe_navn
),

beriket as (
    select
        indikator_kode,
        datakilde,
        indikatorgruppe_navn,
        er_utfaset,
        case indikator_kode
            when 'ANT_PAS'      then 'Antall pasienter'
            when 'ANT_PAS_DOGN' then 'Antall pasienter i døgnbehandling'
            when 'ANT_OPP_DOGN' then 'Antall oppholdsdøgn'
            when 'ANT_DOGNOPP'  then 'Antall døgnopphold'
            when 'ANT_KONT_POL' then 'Antall kontakter i poliklinikk'
            when 'ANT_DAGBEH'   then 'Antall dagbehandlinger'
            else indikator_kode
        end                                     as indikator_navn,
        case
            when er_prosent                                     then 'Prosent'
            when lower(indikator_kode) like '%antall dager%'    then 'Dager'
            when lower(indikator_kode) like '%ventetid%'        then 'Dager'
            when lower(indikator_kode) like '%andel%'           then 'Prosent'
            when indikator_kode like 'ANT\_%' escape '\'        then 'Antall'
            when lower(indikator_kode) like '%antall%'          then 'Antall'
            else 'Ukjent'
        end                                     as enhet,
        case
            -- lav verdi er onsket
            when lower(indikator_kode) like '%ventetid%'      then 'Lavere er bedre'
            when lower(indikator_kode) like '%fristbrudd%'    then 'Lavere er bedre'
            when lower(indikator_kode) like '%korridor%'      then 'Lavere er bedre'
            when lower(indikator_kode) like '%reinnleggelse%' then 'Lavere er bedre'
            when lower(indikator_kode) like '%avbrudd%'       then 'Lavere er bedre'
            -- hoy verdi er onsket
            when lower(indikator_kode) like '%epikrise%'      then 'Høyere er bedre'
            when lower(indikator_kode) like '%overlevelse%'   then 'Høyere er bedre'
            when lower(indikator_kode) like '%oppdaterte%'    then 'Høyere er bedre'
            when lower(indikator_kode) like '%gjennomført%'   then 'Høyere er bedre'
            -- rene tellinger har ingen onsket retning
            else 'Ingen retning'
        end                                     as retning,
        /*
          Nasjonale styringsmal, hentet fra Oppdragsdokument 2025 til de fire
          regionale helseforetakene (Helse- og omsorgsdepartementet). Samme
          formulering star i alle fire dokumentene:

            "Malsettingen pa sikt er gjennomsnittlig ventetid lavere enn
             50 dager for somatikk, 40 dager for psykisk helsevern voksne,
             35 dager for psykisk helsevern barn og unge og 30 dager for
             tverrfaglig spesialisert rusbehandling (TSB)."

          Malet for PHBU er ogsa slatt fast i Nasjonal helse- og
          samhandlingsplan 2024-2027. Malet for epikrisetid folger av kravet
          om at minst 70 prosent av epikrisene skal sendes innen en dag.

          To ting er bevisst utelatt:

          Median far ikke malverdi. Malet er formulert for gjennomsnitt.
          Legges det pa medianen ogsa, sammenlignes et tall med et mal som
          ikke gjelder for det, og figuren blir stille feil.

          Aktivitetsindikatorer far ikke malverdi. Et synkende antall
          pasienter er verken bra eller darlig i seg selv - det avhenger av
          hvorfor. Derfor har de retning "Ingen retning" og fargelegges ikke.
        */
        case
            when lower(indikator_kode) like 'gjennomsnittlig ventetid i somatikk%' then 50.0
            when lower(indikator_kode) like 'gjennomsnittlig ventetid i phv%'      then 40.0
            when lower(indikator_kode) like 'gjennomsnittlig ventetid i phbu%'     then 35.0
            when lower(indikator_kode) like 'gjennomsnittlig ventetid i tsb%'      then 30.0
            -- Malet gjelder KUN andelen sendt innen en dag. Det traff
            -- opprinnelig ogsa rene tellinger og "innen 7 dager", som er et
            -- annet maltall med et annet mal. Et mal pa feil indikator er
            -- verre enn ingen mal, fordi figuren da ser vurdert ut.
            when lower(indikator_kode) like 'andel%epikris%innen 1 dag%'           then 70.0
            else cast(null as double)
        end                                     as malverdi
    from grunnlag
)

select
    {{ dbt_utils.generate_surrogate_key(['indikatorgruppe_navn','indikator_kode','datakilde']) }} as indikator_id,
    indikator_kode,
    indikator_navn,
    coalesce(indikatorgruppe_navn,
             case when datakilde = 'NPR' then 'Aktivitet i spesialisthelsetjenesten' end
    )                                                                      as indikatorgruppe,
    datakilde,
    enhet,
    retning,
    malverdi,
    er_utfaset,
    case when datakilde = 'NPR' then 'Aktivitet' else 'Kvalitet' end        as kildetype
from beriket
