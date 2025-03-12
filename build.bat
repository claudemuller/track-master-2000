@echo off
if "%1"=="" (
	odin build src -out=bin\tm2000.exe
) else if "%1"=="run" (
	odin run src -out=bin\tm2000.exe
) else if "%1"=="debug" (
	odin build src -debug -out=bin\tm2000-debug.exe
) else (
	echo Invalid parameter :/
)
