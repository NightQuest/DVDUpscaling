# SynthSkript.vpy taken from a generated Hybrid file, and modified

# Imports
import vapoursynth as vs
import os
import ctypes
import sys
import math

# Scripts folder
scriptPath = ""

if os.name == 'nt':
	# Loading Support Files
	Dllref = ctypes.windll.LoadLibrary(hybrid_path + "/64bit/vsfilters/Support/libfftw3f-3.dll")
	
	scriptPath = hybrid_path + '/64bit/vsscripts'

elif os.name == 'posix':
	uname = os.uname()
	if uname.sysname == 'Darwin':
		scriptPath = hybrid_path + '/Contents/MacOS/vsscripts'
	else:
		scriptPath = '/vsscripts' # Needs found

# getting Vapoursynth core
core = vs.core
sys.path.insert(0, os.path.abspath(scriptPath))


# Loading Plugins
if os.name == 'nt':
	core.std.LoadPlugin(path=hybrid_path + "/64bit/vsfilters/GrainFilter/RemoveGrain/RemoveGrainVS.dll")
	core.std.LoadPlugin(path=hybrid_path + "/64bit/vsfilters/GrainFilter/AddGrain/AddGrain.dll")
	core.std.LoadPlugin(path=hybrid_path + "/64bit/vsfilters/DenoiseFilter/FFT3DFilter/fft3dfilter.dll")
	core.std.LoadPlugin(path=hybrid_path + "/64bit/vsfilters/DenoiseFilter/DFTTest/DFTTest.dll")
	core.std.LoadPlugin(path=hybrid_path + "/64bit/vsfilters/Support/EEDI3m.dll")
	core.std.LoadPlugin(path=hybrid_path + "/64bit/vsfilters/ResizeFilter/nnedi3/vsznedi3.dll")
	core.std.LoadPlugin(path=hybrid_path + "/64bit/vsfilters/Support/libmvtools.dll")
	core.std.LoadPlugin(path=hybrid_path + "/64bit/vsfilters/Support/scenechange.dll")
	core.std.LoadPlugin(path=hybrid_path + "/64bit/vsfilters/Support/fmtconv.dll")
	core.std.LoadPlugin(path=hybrid_path + "/64bit/vsfilters/MiscFilter/MiscFilters/MiscFilters.dll")
	core.std.LoadPlugin(path=hybrid_path + "/64bit/vsfilters/DeinterlaceFilter/Bwdif/Bwdif.dll")
	core.std.LoadPlugin(path=hybrid_path + "/64bit/vsfilters/SourceFilter/LSmashSource/vslsmashsource.dll")

	core.std.LoadPlugin(path=hybrid_path + "/64bit/vsfilters/DeinterlaceFilter/TIVTC/libtivtc.dll")
	core.std.LoadPlugin(path=d2vsource_path)

# Import scripts
import havsfunc

PixelAspectRatio = float(PixelAspectRatio)
DisplayAspectRatio = float(DisplayAspectRatio)
width = int(width)
height = int(height)
PARWidth = int(width * PixelAspectRatio)
FrameRate_Num = int(FrameRate_Num)
FrameRate_Out_Num = int(FrameRate_Out_Num)
FrameRate_Den = int(FrameRate_Den)
FrameRate_Out_Den = int(FrameRate_Out_Den)
FrameRate = float(FrameRate)
FrameRateNew = float(FrameRateNew)
force_square_pixels = bool(force_square_pixels)

cropLeft = int(cropLeft)
cropRight = int(cropRight)
cropTop = int(cropTop)
cropBottom = int(cropBottom)

# No conversion needed
#input_file = str(input_file)
#resample_kernel = str(resample_kernel)

if PARWidth % 2: # Mod 2
	PARWidth = PARWidth + (PARWidth % 2)

if input_file.lower().endswith('.d2v'):
    clip = core.d2v.Source(input=input_file, nocrop=True, rff=True)
else:
    clip = core.lsmas.LWLibavSource(source=input_file, format="YUV420P8", stream_index=0, cache=0, fpsnum=FrameRate_Num, fpsden=FrameRate_Den, prefer_hw=0)

# Setting detected color matrix (470bg).
clip = core.std.SetFrameProps(clip, _Matrix=5)
# Setting color transfer info (470bg), when it is not set
clip = clip if not core.text.FrameProps(clip,'_Transfer') else core.std.SetFrameProps(clip, _Transfer=5)
# Setting color primaries info (BT.601 NTSC), when it is not set
clip = clip if not core.text.FrameProps(clip,'_Primaries') else core.std.SetFrameProps(clip, _Primaries=5)
# Setting color range to TV (limited) range.
clip = core.std.SetFrameProp(clip=clip, prop="_ColorRange", intval=1)

# making sure frame rate is set to 29.97
clip = core.std.AssumeFPS(clip=clip, fpsnum=FrameRate_Num, fpsden=FrameRate_Den)
clip = core.std.SetFrameProp(clip=clip, prop="_FieldBased", intval=2) # tff

# Detelecine if not the same
#if FrameRate_Num == FrameRate_Out_Num:
	#clip = havsfunc.QTGMC(Input=clip, Preset="Placebo") # new fps 2x
#else:
#clip2clip = havsfunc.srestore(source=clip2clip, frate=FrameRateNew, omode=6, speed=-9, thresh=16, mode=2)


	#clip = core.tivtc.TFM(clip=clip, mode=3, PP=7, slow=2, clip2=clip2clip)
	#clip = core.tivtc.TDecimate(clip=clip, mode=7, rate=FrameRateNew, dupThresh=0.04, vidThresh=3.50, sceneThresh=15.00)# new fps: 19.3112
if input_file.lower().endswith('.d2v'):
    clip = core.tivtc.TFM(clip=clip, mode=3, PP=7, slow=2, d2v=input_file)
else:
    clip = core.tivtc.TFM(clip=clip, mode=3, PP=7, slow=2)
#clip = havsfunc.QTGMC(Input=clip, Preset="Placebo")
#if FrameRate_Out_Num <= FrameRate_Num:
#    clip = core.tivtc.TDecimate(clip=clip)
clip = havsfunc.QTGMC(Input=clip, Preset="Draft", InputType=2)

#clip = core.vivtc.VDecimate(clip)

# Making sure content is preceived as frame based
clip = core.std.SetFrameProp(clip=clip, prop="_FieldBased", intval=0) # progressive
# MacOS: clip = core.std.SetFieldBased(clip, 0)

# Decimate 29.970 -> 23.976
#clip = core.std.SelectEvery(clip=clip, cycle=5, offsets=[0, 1, 3, 4])
#clip = core.std.SelectEvery(clip=clip, cycle=5, offsets=[0, 1, 2, 3])

# adjusting frame count and rate with sRestore
#clip = havsfunc.srestore(source=clip, frate=FrameRateNew, omode=6, speed=9, thresh=16, mode=2)

# ColorMatrix: adjusting color matrix from 470bg to 709
# adjusting luma range to 'limited' due to post clipping
clip = core.resize.Bicubic(clip=clip, matrix_in_s="470bg", matrix_s="709", range_in=0, range=0)
# cropping the video to 720x478
if cropLeft or cropBottom or cropRight or cropTop:
	clip = core.std.CropRel(clip=clip, left=cropLeft, right=cropRight, top=cropTop, bottom=cropBottom)

# Resizing using 10 - bicubic spline
if force_square_pixels:
	clip = core.fmtc.resample(clip=clip, kernel=resample_kernel, w=PARWidth, h=height, interlaced=False, interlacedd=False) # resolution 720x540# before YUV420P8 after YUV420P16
else:
	clip = core.fmtc.resample(clip=clip, kernel=resample_kernel, w=width, h=height, interlaced=False, interlacedd=False) # resolution 720x540# before YUV420P8 after YUV420P16

# adjusting output color from: YUV420P16 to YUV422P10 for ProResModel
clip = core.resize.Bicubic(clip=clip, format=vs.YUV422P10, range_s="limited", dither_type="error_diffusion")

# set output frame rate to 23.976fps (progressive)
#clip = core.std.AssumeFPS(clip=clip, fpsnum=FrameRate_Num * 2, fpsden=FrameRate_Den)
clip = core.std.AssumeFPS(clip=clip, fpsnum=FrameRate_Out_Num, fpsden=FrameRate_Out_Den)

# Output
clip.set_output()