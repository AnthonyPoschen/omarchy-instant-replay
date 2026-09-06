# Neither capture kills the other

Only one KMS capture can run. This plugin launches GPU Screen Recorder as `omarchy-instant-replay-gsr` so stock Omarchy screenrecord does not treat the Replay Buffer as a session recording and stop it.

If the device is busy, going Live fails with a clear error. We do not stop a Session Recording to start the Replay Buffer. We do not pause or stop ourselves when the user starts a stock recording.

We rejected auto-yielding to Alt+Print (Follow would look randomly Armed). We rejected stealing the device from an in-progress take.
