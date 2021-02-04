@echo off
python %CLikeToDelphi% "src\main.cs" "Edit Scripts\JLoadScreenGenerator.pas"
if errorlevel 1 (
echo Build failed.
) else (
robocopy "%~dp0Custom" "%~dp0Edit Scripts\JLoadScreens\Custom" *.py /s /xx > nul
robocopy "%~dp0Custom" "%~dp0Edit Scripts\JLoadScreens\Custom" *.cmd /s /xx > nul
if defined SSEEDIT_PATH (robocopy "%~dp0Edit Scripts" "%SSEEDIT_PATH%\Edit Scripts" /s /xx > nul)
if defined TESVEDIT_PATH (robocopy "%~dp0Edit Scripts" "%TESVEDIT_PATH%\Edit Scripts" /s /xx > nul)
echo Build successful.
)
