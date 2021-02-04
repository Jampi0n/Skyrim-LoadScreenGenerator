Requires [https://github.com/Jampi0n/xEdit-Script-Transpiler](CLikeToDelphi). Set the environment variable `CLikeToDelphi` to point to CLikeToDelphi.py.

The default build task of VSCode runs `build.cmd`, which places the generated delphi scripts in the edit scripts folder of xEdit. Set the environment variables `TEVSEDIT_PATH` and `SSEEDIT_PATH` to point towards the installation directories of TESVEdit and SSEEdit.

To pack the mod in a .7z archive, run `release.cmd`. Make sure to run `build.cmd` (included in default build task of VSCode) before, so the Delphi scripts are generated.