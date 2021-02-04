The xEdit script is released on [NexusMods](https://www.nexusmods.com/skyrimspecialedition/mods/36556). Unless you want to modify the script, you should get it from there.

# Building

Requires [CLikeToDelphi](https://github.com/Jampi0n/Skyrim-CLikeToDelphi). Set the environment variable `CLikeToDelphi` to point to CLikeToDelphi.py.

The default build task of VSCode runs `build.cmd`, which places the generated delphi script and its sub directory in the edit scripts folder of xEdit. Set the environment variables `TEVSEDIT_PATH` and `SSEEDIT_PATH` to point towards the installation directories of TESVEdit and SSEEdit. If the environment variables are not defined, you have to manually place the generated delphi script and sub directory in the edit scripts folder in order to run it in xEdit.

To pack the mod in a .7z archive, run `release.cmd`. Make sure to run `build.cmd` (included in default build task of VSCode) before, so the Delphi script is generated.
