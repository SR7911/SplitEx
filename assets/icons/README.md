# Launcher icon

app_icon.png is the unchanged original 3D icon used for the splash and legacy
launcher. app_icon_android.png is the Android adaptive version: the teal
background extends to every edge with no rounded tile or outline inside the
phone launcher mask. Its receipt and badge include the previous scale padding,
so the launcher configuration must use zero additional inset.

Regenerate:

    dart run flutter_launcher_icons

The Android version was edited with the built-in image generation tool.
Prompt: Preserve the original 3D receipt, rupee, group badge, gradients, lighting
and shadows. Extend the teal gradient to every edge of an opaque square, with
no rounded tile boundary or outline. Scale the combined receipt and badge to
68% of its original size and center it to compensate for removal of the old
16% launcher inset. No flattening or redesign.
