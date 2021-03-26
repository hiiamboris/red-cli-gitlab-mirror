@if "" == "%~2" echo Syntax: pfind ^<file^> ^<string^> & goto :eof
@parse -l %1 "to {%~2}"