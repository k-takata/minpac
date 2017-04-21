rem @echo off

if not exist downloads\nul mkdir downloads
set DL=no
dir downloads
py tools\dl-kaoriya-vim.py -c > release-info.txt
echo "foobar" > downloads\release-info.txt
if exist downloads\release-info.txt (
	echo "old info:"
	type downloads\release-info.txt
	echo "new info:"
	type release-info.txt
	\cygwin64\bin\diff downloads\release-info.txt release-info.txt
	if ERRORLEVEL 1 set DL=yes
) else (
	set DL=yes
)
if "%DL%"=="yes" (
	py tools\dl-kaoriya-vim.py --arch win64 --filename downloads\vim.zip --force
	if not ERRORLEVEL 1 (
		copy /y release-info.txt downloads > nul
		curl -X DELETE -H "Authorization: Bearer %API_TOKEN%" %APPVEYOR_API_URL%api/projects/%APPVEYOR_ACCOUNT_NAME%/%APPVEYOR_PROJECT_SLUG%/buildcache
		echo %APPVEYOR_API_URL%api/projects/%APPVEYOR_ACCOUNT_NAME%/%APPVEYOR_PROJECT_SLUG%/buildcache
	)
)
7z x downloads\vim.zip > nul
rem set APPVEYOR_CACHE_ENTRY_ZIP_ARGS=-tzip -mx=1 -ux2z2
