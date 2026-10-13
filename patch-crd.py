#!/usr/bin/env python3
"""Patch Chrome Remote Desktop so it shares the existing physical X display
(:0, the desktop session already shown on the monitor) instead of starting a
new virtual Xorg session.

Usage: sudo python3 patch-crd.py [path-to-chrome-remote-desktop-script]
Safe to run repeatedly; re-run after every chrome-remote-desktop update.
"""
import shutil
import sys

PATH = (sys.argv[1] if len(sys.argv) > 1
        else "/opt/google/chrome-remote-desktop/chrome-remote-desktop")
MARKER = "# CRD-SHARE-SCREEN-PATCH"

src = open(PATH).read()
if MARKER in src:
  print("Already patched:", PATH)
  sys.exit(0)

shutil.copy2(PATH, PATH + ".orig")


def replace_once(old, new):
  global src
  if src.count(old) != 1:
    sys.exit("Patch target not found (CRD script changed?):\n" + old)
  src = src.replace(old, new)


# 1. Use display :0.
replace_once("FIRST_X_DISPLAY_NUMBER = 20\n",
             "FIRST_X_DISPLAY_NUMBER = 0  " + MARKER + "\n")

# 2. Always return :0 even though its X socket exists.
replace_once(
    "    display = FIRST_X_DISPLAY_NUMBER\n"
    "    while os.path.exists(X_SOCKET_FILE_TEMPLATE % display):\n"
    "      display += 1\n"
    "    return display\n",
    "    return FIRST_X_DISPLAY_NUMBER  " + MARKER + "\n")

# 3. Attach to the existing display instead of launching Xorg + a session.
#    The main loop only starts the host when server_proc is set, so a
#    placeholder process stands in for the X server.
replace_once(
    "  def launch_session(self, *args, **kwargs):\n"
    "    logging.info(\"Launching X server and X session.\")\n"
    "    super(XDesktop, self).launch_session(*args, **kwargs)\n",
    "  def launch_session(self, *args, **kwargs):  " + MARKER + "\n"
    "    display = self.get_unused_display_number()\n"
    "    self.child_env[\"DISPLAY\"] = \":%d\" % display\n"
    "    gdm_xauth = \"/run/user/%d/gdm/Xauthority\" % os.getuid()\n"
    "    if os.path.exists(gdm_xauth):\n"
    "      self.child_env[\"XAUTHORITY\"] = gdm_xauth\n"
    "    logging.info(\"Attaching to existing X display :%d\" % display)\n"
    "    # Wait up to 5 minutes for the auto-login session to come up.\n"
    "    for _ in range(300):\n"
    "      if self.check_server_responding():\n"
    "        break\n"
    "      time.sleep(1)\n"
    "    else:\n"
    "      logging.error(\"X display :%d is not responding\" % display)\n"
    "    self.server_proc = subprocess.Popen([\"sleep\", \"infinity\"])\n")

open(PATH, "w").write(src)
print("Patched:", PATH, "(backup:", PATH + ".orig)")
