## Summary
- 

## What changed
- Apply local kernel patches during `scripts/build-kernel.sh`
- VOP2: raise `VOP2_MAX_DCLK_RATE` for RK3588 4K@120 availability
- VOP2: raise RK3588 VP1/VP2 `dclk_max` to allow 4K@120 modes to pass VOP2 mode validation

## Test plan
- Build kernel packages via `sudo env SUITE=noble ./scripts/build-kernel.sh`
- Install generated `.deb` packages
- Verify `drm_info` lists `3840x2160@120` and that mode can be selected

## Notes
- 4K@120 on HDMI 2.0-class sinks typically requires YCbCr 4:2:0 to fit within TMDS limits; this change targets the VOP2 pixel clock validation so the mode is exposed to userspace.
