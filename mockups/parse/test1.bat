@echo.
@echo Displaying all lines containing 2 consecutive vowels:
@echo.
@parse -e README.md "(cs: charset {AEIOUaeiou}) to 2 cs"