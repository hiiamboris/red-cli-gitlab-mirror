Red []

#include %../../cli.red

x264-mockup: func [
	infile [file!]
	/profile
{Force the limits of an H.264 profile
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
      Support for 4:2:0/4:2:2 chroma subsampling.      
    - high444:                                         
      Support for bit depth 8-10.                      
      Support for 4:2:0/4:2:2/4:4:4 chroma subsampling.}
		string
][
	print ["infile=" infile]
	if profile [print ["profile=" string]]
]

cli/process-into x264-mockup

