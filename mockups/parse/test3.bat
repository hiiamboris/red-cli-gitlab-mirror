@echo.
@echo Displaying all mixed-case words:
@echo.
@parse -c README.md "any [thru [any { } copy w word!] (w: to string! w) opt [if (not any [w == uppercase copy w  w == lowercase copy w]) keep (transcode/one w)]]"