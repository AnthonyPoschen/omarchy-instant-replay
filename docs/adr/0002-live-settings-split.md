# Encoder settings Split; match rules do not

GPU Screen Recorder pins monitor, region, duration, and audio at process start. The Filter only chooses the Subject.

Changing mode, Buffer Target, Replay Window length, or audio while Live flushes a Segment and restarts. Follow and Pin always crop Save to the Subject; there is no Extent control. A Follow Subject change on the same monitor dumps the ring as a Segment and clears it without stopping capture. Changing Blacklist or Pin target does not Split. The last session is restored when the shell loads; there is no Autostart toggle.

We rejected showing new settings while the encoder still runs the old ones. We rejected restarting on every regex keystroke.
