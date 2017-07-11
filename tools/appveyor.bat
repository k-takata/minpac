@echo off

cd %APPVEYOR_BUILD_FOLDER%

if "%1"=="" (
  exit 1
)
set target=%1

for %%i in (win64 cygwin64) do if "%env%"=="%%i" goto %env%_%target%

echo Unknown build target.
exit 1

:win64_build
:: ----------------------------------------------------------------------
:: 64-bit Win32
call "C:\Program Files\Microsoft SDKs\Windows\v7.1\Bin\SetEnv.cmd" /x64
call tools\appveyor-dl.bat
@echo on
%VIMPROG% -u NONE -c "redir @a | ver | 0put a | wq" ver.txt
type ver.txt

@echo off
goto :eof

:win64_test
@echo on
cd test
nmake -f Make_win.mak VIMPROG=%VIMPROG%

@echo off
goto :eof


:cygwin64_build
:: ----------------------------------------------------------------------
:: 64-bit Cygwin
@echo on
c:\cygwin64\setup-x86_64.exe -qnNdO -P vim,make
PATH c:\cygwin64\bin;%PATH%
set CHERE_INVOKING=yes
bash -lc "$VIMPROG --version"

@echo off
goto :eof

:cygwin64_test
@echo on
cd test
bash -lc "which make"
rem bash -lc "make VIMPROG=$VIMPROG --trace"
make VIMPROG=%VIMPROG% test_minpac.res --trace -p

@echo off
goto :eof
