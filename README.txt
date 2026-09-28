SCP:RP VANGUARD FACILITY IMPORT PACKAGE

Generated from SCPRP_DIRECT.rbxmx.

Export counts:
- Objects: 178082
- CREATE modules: 1252
- REFS modules: 23
- RENAME modules: 104
- Skipped by original exporter: 1 UnionOperation, 18 TouchTransmitters

FILES
- create_001.txt through create_023.txt
- refs_001.txt
- rename_001.txt through rename_002.txt
- SCPRP_Vanguard_Loader.lua
- manifest.json

USE
1. Put all TXT files in one public/raw HTTP folder.
2. In SCPRP_Vanguard_Loader.lua, change BASE_URL to that folder's raw URL.
3. Add the loader as a normal enabled SCP:RP Server Addon.
4. Do not use Run Once for the full import.
5. Keep the server running until the addon prints SCPRP VANGUARD IMPORT COMPLETE.
6. After completion, disable the importer addon so it cannot be started again.

The loader creates objects in the order produced by the exporter, restores references,
then restores original names.

The loader does NOT use loadstring/load.
