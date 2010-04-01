@echo off
if not exist "%USERPROFILE%\vimfiles\plugin" mkdir "%USERPROFILE%\vimfiles\plugin"
if not exist "%USERPROFILE%\vimfiles\ftplugin\perl" mkdir "%USERPROFILE%\vimfiles\ftplugin\perl"
copy /Y .\ftplugin\perl\perlomni.vim "%USERPROFILE%\vimfiles\ftplugin\perl\." > NUL
copy /Y .\plugin\perlomni-data.vim "%USERPROFILE%\vimfiles\plugin\." > NUL
copy /Y .\plugin\perlomni-util.vim "%USERPROFILE%\vimfiles\plugin\." > NUL
echo install done.
