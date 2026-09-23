# gnome-accelerometer-rotate

Automatic screen rotation for GNOME on Wayland using `iio-sensor-proxy`, with support for GNOME's existing rotation lock and on-screen keyboard.

This is a small workaround for convertible laptops where the accelerometer works but GNOME does not enable automatic panel rotation. A common symptom is that `monitor-sensor` reports valid orientation changes while Mutter's `PanelOrientationManaged` property remains `false`.

The service listens for accelerometer orientation changes and applies the corresponding transform to the built-in display with GNOME's `gdctl`. It also watches GNOME's `orientation-lock` setting, so an existing rotation-lock key or button continues to work normally.

Because systems affected by this problem may also lack usable tablet-mode detection, the service can manage GNOME's built-in on-screen keyboard. It enables the keyboard when the built-in display is rotated away from its normal orientation and no external keyboard is present, and disables it otherwise.

## Tested hardware

Developed and tested on a **Lenovo Yoga 2 Pro** running **Fedora Workstation 44**, **GNOME 50.5**, and a Wayland session.

On this machine:

- `iio-sensor-proxy` detects the accelerometer and reports all four orientations.
- GNOME's `orientation-lock` setting is toggled by the laptop's physical rotation-lock button.
- Linux exposes the normal lid switch but no `SW_TABLET_MODE` input switch.
- Mutter reports `PanelOrientationManaged = false`, so GNOME does not automatically rotate the built-in panel despite receiving valid sensor data.
- The built-in keyboard is classified by udev on the `i8042` bus, while tested external USB keyboards are independently classified with `ID_INPUT_KEYBOARD=1`.

The workaround does not attempt to infer hinge or tablet mode. Rotation follows the accelerometer whenever GNOME's rotation lock is disabled. On hardware without usable tablet-mode detection, keeping rotation locked during ordinary laptop use is recommended.

## Requirements

- GNOME on Wayland
- `iio-sensor-proxy` / `monitor-sensor`
- `gdctl`
- `gsettings`
- `udevadm`
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

It then enables and starts the user service. The installer also checks for a keyboard on the default `i8042` internal-keyboard bus. If none is found, installation continues with a warning so the hardware-specific setting can be adjusted manually.

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

### On-screen keyboard

The same service manages GNOME's `org.gnome.desktop.a11y.applications screen-keyboard-enabled` setting according to the current display transform and keyboard state:

| Built-in display | External keyboard | On-screen keyboard |
| --- | --- | --- |
| `normal` | absent or present | disabled |
| `90`, `180`, or `270` | absent | enabled |
| `90`, `180`, or `270` | present | disabled |

External keyboards are discovered from udev input-device properties. A device with `ID_INPUT_KEYBOARD=1` on a bus other than `INTERNAL_KEYBOARD_BUS` is treated as external. The default internal bus is `i8042`. The service listens for udev input add/remove events and reevaluates the setting when devices are connected or disconnected; it does not poll for keyboard state.

The hardware-specific defaults are grouped near the top of `gnome-accelerometer-rotate`:

```bash
BUILTIN='eDP-1'
INTERNAL_KEYBOARD_BUS='i8042'
```

Systems using a different built-in display connector or internal-keyboard bus can change those values directly.

## Diagnostics

Check GNOME's rotation lock:

```console
gsettings get org.gnome.settings-daemon.peripherals.touchscreen orientation-lock
```

Check GNOME's on-screen keyboard setting:

```console
gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled
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

Inspect udev's keyboard classification:

```console
for dev in /dev/input/event*; do
    udevadm info --query=property --name="$dev" 2>/dev/null |
        grep -E '^(ID_INPUT_KEYBOARD|ID_BUS)=' || true
done
```

## Limitations

The built-in display connector defaults to `eDP-1`, and the internal keyboard bus defaults to `i8042`. Systems using different hardware identifiers need to change `BUILTIN` or `INTERNAL_KEYBOARD_BUS` near the top of `gnome-accelerometer-rotate`.

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

The service changes GNOME's on-screen keyboard preference while it runs. After uninstalling, set that preference to whichever state you prefer, for example:

```console
gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled false
```

## License

MIT
