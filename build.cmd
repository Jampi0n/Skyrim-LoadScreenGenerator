python %DELPHI_TRANSPILER% "src\main.cs" "Edit Scripts\JLoadScreenGenerator.pas"
robocopy "%~dp0Custom" "%~dp0Edit Scripts\JLoadScreens\Custom" *.py /s /xx
robocopy "%~dp0Custom" "%~dp0Edit Scripts\JLoadScreens\Custom" *.cmd /s /xx
robocopy "%~dp0Edit Scripts" "%SSEEDIT_PATH%\Edit Scripts" /s /xx
robocopy "%~dp0Edit Scripts" "%TESVEDIT_PATH%\Edit Scripts" /s /xx
