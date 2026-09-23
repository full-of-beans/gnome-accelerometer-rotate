# gnome-accelerometer-rotate

Automatic screen rotation for GNOME on Wayland using `iio-sensor-proxy`, with support for GNOME's existing rotation lock.

This is a small workaround for convertible laptops where the accelerometer works but GNOME does not enable automatic panel rotation. A common symptom is that `monitor-sensor` reports valid orientation changes while Mutter's `PanelOrientationManaged` property remains `false`.

The service listens for accelerometer orientation changes and applies the corresponding transform to the built-in display with GNOME's `gdctl`. It also watches GNOME's `orientation-lock` setting, so an existing rotation-lock key or button continues to work normally.

## Tested hardware

Developed and tested on a **Lenovo Yoga 2 Pro** running **Fedora Workstation 44**, **GNOME 50.5**, and a Wayland session.

On this machine:

- `iio-sensor-proxy` detects the accelerometer and reports all four orientations.
- GNOME's `orientation-lock` setting is toggled by the laptop's physical rotation-lock button.
- Linux exposes the normal lid switch but no `SW_TABLET_MODE` input switch.
- Mutter reports `PanelOrientationManaged = false`, so GNOME does not automatically rotate the built-in panel despite receiving valid sensor data.

The workaround does not attempt to infer hinge or tablet mode. Rotation follows the accelerometer whenever GNOME's rotation lock is disabled. On hardware without usable tablet-mode detection, keeping rotation locked during ordinary laptop use is recommended.

## Requirements

- GNOME on Wayland
- `iio-sensor-proxy` / `monitor-sensor`
- `gdctl`
- `gsettings`
- systemd user services
- Bash, awk, sed, and coreutils

Before installing, confirm that the sensor reports orientation changes:

```console
$ monitor-sensor
=== Has accelerometer (orientation: normal, tilt: vertical)
    Accelerometer orientation changed: right-up
```

If `monitor-sensor` does not see an accelerometer or does not report orientation changes, this project will not fix the underlying sensor or kernel issue.

## Install

Clone the repository and run the installer from a GNOME session:

```console
git clone https://github.com/full-of-beans/gnome-accelerometer-rotate.git
cd gnome-accelerometer-rotate
./install.sh
```

The installer copies:

- `gnome-accelerometer-rotate` to `~/.local/bin/gnome-accelerometer-rotate`
- `gnome-accelerometer-rotate.service` to `~/.config/systemd/user/gnome-accelerometer-rotate.service`

It then enables and starts the user service.

Check its status with:

```console
systemctl --user status gnome-accelerometer-rotate.service
```

View recent logs with:

```console
journalctl --user -u gnome-accelerometer-rotate.service
```

## Behavior

The orientation mapping is:

| Sensor orientation | Display transform |
| --- | --- |
| `normal` | `normal` |
| `left-up` | `90` |
| `bottom-up` | `180` |
| `right-up` | `270` |

Normal sensor events are handled directly from the persistent `monitor-sensor` process; there is no periodic polling or added debounce delay.

When rotation is locked, orientation events are ignored. When rotation changes from locked to unlocked, the service explicitly queries the current sensor orientation and synchronizes the display even if the laptop has not moved since unlocking.

The service reconstructs the current `gdctl` logical-monitor configuration and changes only the transform of the built-in `eDP-1` display. This allows the current scale, position, primary-display state, and attached external displays to be retained while the internal panel rotates.

## Diagnostics

Check GNOME's rotation lock:

```console
gsettings get org.gnome.settings-daemon.peripherals.touchscreen orientation-lock
```

Check whether Mutter considers panel orientation managed:

```console
gdbus call \
  --session \
  --dest org.gnome.Mutter.DisplayConfig \
  --object-path /org/gnome/Mutter/DisplayConfig \
  --method org.freedesktop.DBus.Properties.Get \
  org.gnome.Mutter.DisplayConfig PanelOrientationManaged
```

Inspect the display configuration:

```console
gdctl show
```

## Limitations

The built-in display connector is currently expected to be named `eDP-1`. Systems using a different connector name need to change `BUILTIN` near the top of `gnome-accelerometer-rotate`.

The `gdctl show` output is parsed to preserve the active logical-monitor configuration. The script therefore targets current GNOME versions that provide `gdctl`; it is not intended as a general Wayland display-rotation utility.

Unlock synchronization starts a short-lived `monitor-sensor` process to obtain the current orientation. This can be slower than ordinary rotation events, which use the orientation already delivered by the persistent sensor watcher.

## Uninstall

Disable the service and remove the installed files:

```console
systemctl --user disable --now gnome-accelerometer-rotate.service
rm -f ~/.config/systemd/user/gnome-accelerometer-rotate.service
rm -f ~/.local/bin/gnome-accelerometer-rotate
systemctl --user daemon-reload
```

## License

MIT
