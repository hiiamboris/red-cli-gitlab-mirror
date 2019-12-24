@echo off
pushd tests
echo. >../output.txt
for %%i in (*.bat) do @(
	echo *** %%i ***
	type %%i
	echo.
	%%i
	echo.
) >>../output.txt
popd