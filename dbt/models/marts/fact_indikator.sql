{{ config(materialized='table') }}

/*
  Faktatabell. Kornniva: en enhet, en periode, ett tjenesteomrade, en aktor,
  en indikator -> en verdi.

  Faktatabellen inneholder bare nokler og tall. All tekst ligger i
  dimensjonene. Det er ikke pynt: nar en indikator skifter navn hos kilden
  skal det rettes ett sted, og en faktatabell med tekstkolonner blir tung i
  minnet fordi kolonnelagringen komprimerer gjentatt tekst darligere enn
  heltall.
*/

select
    f.enhet_id,
    f.periode_id,
    f.indikator_id,
    f.tjenesteomrade_id,
    f.aktor_navn,
    f.verdi,
    f.er_prikket,
    f.flagg,
    f.uttrekksdato,
    f.datakilde
from {{ ref('int_indikator_forent') }} f
