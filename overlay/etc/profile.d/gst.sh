export GST_GL_API=gles2
export GST_GL_PLATFORM=egl

export GST_DEBUG_NO_COLOR=1
export GST_INSPECT_NO_COLORS=1

# Skip vstride aligning, which is not required when using RKVENC.
# export GST_MPP_ENC_UNALIGNED_VSTRIDE=1

# Convert to NV12(using RGA) when output format is NV12_10.
# export GST_MPP_DEC_DISABLE_NV12_10=1

# Convert to NV12(using RGA) when output format is not NV12.
# export GST_MPP_VIDEODEC_DEFAULT_FORMAT=NV12

# Try to use ARM AFBC to get better performance, but not work for all sinks.
# export GST_MPP_VIDEODEC_DEFAULT_ARM_AFBC=1

# Use below env variables to configure kmssink plane ZPOS.
# export KMSSINK_PLANE_ZPOS=0
# export KMSSINK_PLANE_ON_TOP=1
# export KMSSINK_PLANE_ON_BOTTOM=1

# There's an extra vsync waiting in kmssink, which is only needed for BSP 4.4
# kernel(due to ecac2033831e FROMLIST: drm: skip wait on vblank for set plane).
# Skip it would bring better performance with frame dropping.
# export KMSSINK_DISABLE_VSYNC=1

# The waylandsink is async by default, which allows frame dropping.
# export WAYLANDSINK_SYNC_FRAME=1

# Put video surface above UI window in waylandsink.
# export WAYLANDSINK_PLACE_ABOVE=1

# Preferred formats for V4L2
export GST_V4L2_PREFERRED_FOURCC=NV12:YU12:NV16:YUY2

# Preferred formats for videoconvert
export GST_VIDEO_CONVERT_PREFERRED_FORMAT=NV12:NV16:I420:YUY2

# Using libv4l2 for V4L2
export GST_V4L2_USE_LIBV4L2=1

# Default device for v4l2src
export GST_V4L2SRC_DEFAULT_DEVICE=/dev/video-camera0

# Available RK devices for v4l2src
export GST_V4L2SRC_RK_DEVICES=_mainpath:_selfpath:_bypass:_scale

# Max resolution for v4l2src
export GST_V4L2SRC_MAX_RESOLUTION=3840x2160

# Preferred sinks for playbin3(autoaudiosink/autovideosink) and playbin.
# export AUTOAUDIOSINK_PREFERRED=alsasink
# export AUTOVIDEOSINK_PREFERRED=waylandsink
# export PLAYBIN2_PREFERRED_AUDIOSINK=alsasink
# export PLAYBIN2_PREFERRED_VIDEOSINK=waylandsink

# Try RGA 2D accel in videoconvert, videoscale and videoflip.
# NOTE: Might not success, and might behave different from the official plugin.
# export GST_VIDEO_CONVERT_USE_RGA=1
# export GST_VIDEO_FLIP_USE_RGA=1
export GST_MPP_NO_RGA=1

# Default rotation for camerabin2:
# clockwise(90)|rotate-180|counterclockwise(270)|horizontal-flip|vertical-flip
# export CAMERA_FLIP=clockwise
if [ $CAMERA_FLIP ]; then
	CAMERA_FILTER="videoflip method=$CAMERA_FLIP"
	export CAMERABIN2_PREVIEW_FILTER=$CAMERA_FILTER
	export CAMERABIN2_IMAGE_FILTER=$CAMERA_FILTER
	export CAMERABIN2_VIDEO_FILTER=$CAMERA_FILTER
	export CAMERABIN2_VIEWFINDER_FILTER=$CAMERA_FILTER
fi
