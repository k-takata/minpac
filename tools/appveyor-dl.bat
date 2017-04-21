rem @echo off

if not exist downloads\nul mkdir downloads
set DL=no
dir downloads
py tools\dl-kaoriya-vim.py -c > release-info.txt
echo "foobar" > release-info.txt
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
	if not ERRORLEVEL 1 copy /y release-info.txt downloads > nul
)
7z x downloads\vim.zip > nul
