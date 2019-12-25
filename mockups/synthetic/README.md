There's some tiny examples here, to prove the concept and showcase the features.
With just 1-2 of the hardest to get right options and how they can be expressed:

`<HOST+PORT>` was originally `<HOST:PORT>` but `:` in Red words isn't allowed, so I replaced it and left a note in argument description:
```
>curl-mockup -h
```
```
curl mockup 25-Dec-2019                                                       
                                                                       
Syntax: curl-mockup [options] <url>                                    
                                                                       
Options:                                                               
      --socks5      <HOST+PORT>   SOCKS5 proxy on given host + port; as
                                  HOST[:PORT]                          
  -t, --telnet-option <OPT=VAL>   Set telnet option                    
      --version                   Display program version and exit     
  -h, --help                      Display this help text and exit      
```

Huge option description formatting with word wrapping:
```
>x264-mockup -h                                  
```
```
x264 mockup 25-Dec-2019                                                             
                                                                             
Syntax: x264-mockup [options] <infile>                                       
                                                                             
Options:                                                                     
      --profile     <string>      Force the limits of an H.264 profile       
                                      Overrides all settings.                
                                      - baseline:                            
                                        --no-8x8dct --bframes 0 --no-cabac   
                                        --cqm flat --weightp 0               
                                        No interlaced.                       
                                        No lossless.                         
                                      - main:                                
                                        --no-8x8dct --cqm flat               
                                        No lossless.                         
                                      - high:                                
                                        No lossless.                         
                                      - high10:                              
                                        No lossless.                         
                                        Support for bit depth 8-10.          
                                      - high422:                             
                                        No lossless.                         
                                        Support for bit depth 8-10.          
                                        Support for 4:2:0/4:2:2 chroma       
                                  subsampling.                               
                                      - high444:                             
                                        Support for bit depth 8-10.          
                                        Support for 4:2:0/4:2:2/4:4:4 chroma 
                                  subsampling.                               
      --version                   Display program version and exit           
  -h, --help                      Display this help text and exit            
```

Note *replacement*:
```
>x264-mockup --profile prof1 --profile prof2 --profile prof3 input
```
```
infile= input
profile= prof3
```

Note *collection*:
```
>curl-mockup -t c=3 ftp://site --socks5=site:80 -t a=1 -t b=2
```
```
url= ftp://site
using host= site:80
telnet opts= c=3 a=1 b=2
```

This will automatically add `author` and `rights` strings from the header once Red supports it:
```
>curl-mockup --version
```
```
curl mockup 25-Dec-2019
Built with Red 0.6.4 (#544a6e1) for Windows
Build timestamp: 25-Dec-2019/20:48:21+03:00
```

Errors:
```
>curl-mockup 1000
```
```
1000 should be a value of url type
```

```
>curl-mockup
```
```
Not enough operands given
```
