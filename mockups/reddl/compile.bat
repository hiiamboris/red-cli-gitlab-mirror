inline reddl.red reddl-full.red
call redc -r -e -o reddl.exe reddl-full.red
call redc -r -e -o reddl -t linux reddl-full.red
call redc -r -e -o reddl-mac -t darwin reddl-full.red
call mpress -s reddl.exe
call upx --best reddl
call upx --best reddl-mac