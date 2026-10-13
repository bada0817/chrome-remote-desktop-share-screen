# chrome-remote-desktop-share-screen

[한국어](README.ko.md)

Make **Chrome Remote Desktop (CRD) on Linux share the screen you already see on the monitor** (X display `:0`), instead of starting a separate virtual desktop.

Tested on Ubuntu 24.04 · GNOME 46 (**Xorg** session) · GDM auto-login · CRD 155.0.8059.19.

## The problem

By default, the Linux CRD host starts its own hidden X server (`:20`) and launches a second desktop session there. In practice that means:

<img src="docs/session-chooser.png" alt="Chrome Remote Desktop session chooser on a black screen" width="480">

- A **"Select a session to launch within your Chrome Remote Desktop environment"** dialog on a black screen (above).
- Picking *Ubuntu* gives a black or broken screen, because GNOME cannot run twice for the same user.
- Picking *Xfce* works, but it is a different desktop, not the one on your monitor.

A widely shared workaround patches the CRD script to use `:0` and skip launching the X server. **That workaround no longer works on recent CRD versions.** The main loop now starts the remote host only when a display server process exists:

```python
if desktop.server_proc is not None and desktop.host_proc is None:
  desktop.launch_host(extra_start_host_args, backoff_time)
```

With the X server launch removed, `server_proc` stays `None` and the host never starts.

## What this patch does

`patch-crd.py` edits `/opt/google/chrome-remote-desktop/chrome-remote-desktop` so that:

1. The display number is always `:0`.
2. `launch_session()` attaches to the existing display. It sets `DISPLAY`/`XAUTHORITY` and waits for the auto-login session. A placeholder `sleep infinity` process stands in for the X server, so the host starts.

Stopping or restarting CRD only kills the placeholder. Your real Xorg session is never touched.

## Install

```bash
git clone https://github.com/bada0817/chrome-remote-desktop-share-screen.git
cd chrome-remote-desktop-share-screen
sudo bash install.sh
```

`install.sh` does four things:

- Installs or updates CRD.
- Applies the patch. The original script is backed up as `chrome-remote-desktop.orig`.
- Adds an apt hook that re-applies the patch after package updates.
- Restarts the host if one is already registered.

**First-time registration:** open <https://remotedesktop.google.com/headless> in any browser and copy the *Debian Linux* command. Then run it on the Linux machine **without sudo**.

Patch only (if CRD is already installed):

```bash
sudo python3 patch-crd.py
sudo systemctl restart chrome-remote-desktop@$USER
```

## Check

```bash
# Expect "sleep infinity" and no "Xorg :20"
ps aux | grep -E "sleep infinity|Xorg :20" | grep -v grep
journalctl -u chrome-remote-desktop@$USER -n 50
```

## Notes

- **Requires an Xorg session.** This patch does not work on Wayland. Newer CRD has a "GDM-managed" mode, but it supports only GNOME 49+ on Wayland.
- **Turn off "Resize desktop to fit"** in the CRD client. Otherwise it may change your physical monitor's resolution.
- **People near your computer can see what you do.** The monitor shows everything you do remotely.
- **No audio.** Desktop apps output to your normal audio device, not to CRD's audio pipe.
- **Monitor changes are fine.** `:0` is the X display, not a monitor port. Switching HDMI ↔ DP or adding monitors keeps working.
- **Works alongside Sunshine/Moonlight.** Both just capture `:0`.
- **After a CRD update,** the apt hook re-applies the patch. If you still see the session chooser, run `sudo systemctl restart chrome-remote-desktop@$USER`.

## Uninstall

```bash
sudo bash uninstall.sh
```

This restores the original script and removes the apt hook. CRD itself stays installed.

## License

[MIT](LICENSE). This is an unofficial patch to Google's Chrome Remote Desktop host script. It is not affiliated with Google. Use it at your own risk.
