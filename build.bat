@echo off
if "%1"=="" (
	odin build src -out=bin\tm2000.exe
) else if "%1"=="run" (
	odin run src -out=bin\tm2000.exe
) else if "%1"=="debug" (
	odin build src -debug -out=bin\tm2000-debug.exe
) else if "%1"=="release" (
	del build
	mkdir build\res
	copy res build\res
	odin build src -out=build\tm2000.exe
	del release
	mkdir release
	powershell Compress-Archive build\* release\windows-x64.zip
) else (
	echo Invalid parameter :/
)
