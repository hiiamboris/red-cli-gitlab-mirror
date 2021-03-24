@echo off
echo.
echo What datatypes a file contains?
echo.
set file=README.md

for %%i in (integer! float! tuple! string! file!) do (
	parse %file% "to %%i to end"
	if not errorlevel 1 echo Contains %%i
)	
