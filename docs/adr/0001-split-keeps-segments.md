# A Split flushes history to a Segment instead of discarding it

Follow Mode and Smart Follow can move the Subject to another monitor. GPU Screen Recorder cannot change `-w` over IPC, and Omarchy can run only one KMS capture at a time, so the live process must stop. We still owe the user the last N seconds of follow time.

On Split we `save-replay` the live buffer to a private Segment, stop, and start on the new Buffer Target. Segments that still overlap the Replay Window are held. Save joins them with the live buffer into one Clip. The user never sees Segments or a stitch UI. A Segment that is entirely older than the Replay Window is discarded.

GSR also cannot move a capture rectangle over IPC. A Follow Subject change on the same monitor is not a Split: we `save-replay` with `restart-replay=true` so the old crop is a Segment, the ring clears, and the same KMS process keeps running. Save still stitches. Sticky chrome does not rotate.

We rejected dropping history on monitor change (the Clip would lie). We rejected running two GSR processes (one KMS capture). We rejected capturing every output in v1 (cost and complexity) just to avoid a Split.
