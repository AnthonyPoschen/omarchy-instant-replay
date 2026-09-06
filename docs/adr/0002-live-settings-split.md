# Encoder settings Split; match rules do not

GPU Screen Recorder pins monitor, region, duration, and audio at process start. The Match List only chooses the Subject.

Changing mode, Buffer Target, Replay Window length, or audio while Live flushes a Segment and restarts. Follow and Pin always crop Save to the Subject; there is no Extent control. A Follow Subject change on the same monitor dumps the ring as a Segment and clears it without stopping capture. Changing Match List, Blacklist, or Pin target does not Split. Autostart is persistence only.

We rejected showing new settings while the encoder still runs the old ones. We rejected restarting on every regex keystroke.
