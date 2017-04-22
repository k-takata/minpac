@echo off

set CACHED=yes
set DL=yes
py tools\dl-kaoriya-vim.py -c > release-info.txt
if ERRORLEVEL 1 (
	set DL=no
) else if exist downloads\release-info.txt (
	\cygwin64\bin\diff downloads\release-info.txt release-info.txt > nul
	if not ERRORLEVEL 1 set DL=no
) else (
	mkdir downloads
	set CACHED=no
)
if "%DL%"=="yes" (
	echo Download the latest Vim.
	py tools\dl-kaoriya-vim.py --arch win64 --filename vim.zip --force
	if not ERRORLEVEL 1 (
		move /y vim.zip downloads > nul
		copy /y release-info.txt downloads > nul
		if "%CACHED%"=="yes" (
			rem Invalidate the cache
			curl -X DELETE -i -H "Authorization: Bearer %API_TOKEN%" https://ci.appveyor.com/api/projects/%APPVEYOR_ACCOUNT_NAME%/%APPVEYOR_PROJECT_SLUG%/buildcache > nul
		)
	)
) else (
	echo Use cached version of Vim.
)
7z x downloads\vim.zip > nul
