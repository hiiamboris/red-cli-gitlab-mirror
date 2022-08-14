inline redbuild.red redbuild-full.red
call redc -r -e -o redbuild.exe redbuild-full.red
call redc -r -e -o redbuild -t linux redbuild-full.red
call redc -r -e -o redbuild-mac -t darwin redbuild-full.red
call mpress -s redbuild.exe
call upx --best redbuild
call upx --best redbuild-mac