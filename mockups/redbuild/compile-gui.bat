inline redbuildgui.red redbuildgui-full.red
call redc -r -e -o redbuildgui.exe redbuildgui-full.red
call redc -r -e -o redbuildgui -t linux redbuildgui-full.red
call redc -r -e -o redbuildgui-mac -t darwin redbuildgui-full.red
call mpress -s redbuildgui.exe
call upx --best redbuildgui
call upx --best redbuildgui-mac