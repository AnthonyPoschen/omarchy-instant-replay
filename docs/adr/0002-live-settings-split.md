# Encoder settings Split; match rules do not

GPU Screen Recorder pins monitor, region, duration, and audio at process start. The Match List only chooses the Subject.

Changing mode, Buffer Target, Capture Extent, Replay Window length, or audio while Live flushes a Segment and restarts. Changing Match List, Blacklist, or Pin target does not. Autostart is persistence only.

We rejected showing new settings while the encoder still runs the old ones. We rejected restarting on every regex keystroke.
