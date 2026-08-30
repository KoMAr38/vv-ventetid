# Start her

1. Legg mappa på `C:\prosjekt\fjordhelse-kvalitet\`
   Kort sti, ingen mellomrom, ingen æ ø å. Ikke OneDrive, ikke Skrivebord.

2. Dobbeltklikk `1_INSTALLER.bat`   (1–3 minutter)

3. Dobbeltklikk `2_BYGG.bat`        (2–4 minutter)

   Forventet til slutt:
   ```
   Done. PASS=41 WARN=0 ERROR=0 SKIP=0
   ```

4. Åpne `powerbi\Fjordhelse_Datakvalitet.pbip`

   Rapporten er ferdig — fire sider, alle mål og relasjoner ligger i repoet.
   Krever Power BI Desktop med `.pbip`-format aktivert under **File** →
   **Options and settings** → **Options** → **Preview features**.

   Ligger prosjektet et annet sted enn `C:\prosjekt\fjordhelse-kvalitet\`:
   **Home** → **Transform data** → **Manage Parameters**, sett `MartMappe` til
   din sti til `data\mart\`. Skråstreken på slutten er obligatorisk.

Går noe galt: skroll opp til FØRSTE linje som sier ERROR. Alt under den er
følgefeil.

`powerbi\STEG_FOR_STEG.md` trengs ikke for å bruke rapporten. Den er en logg
over hvordan den ble bygget.
