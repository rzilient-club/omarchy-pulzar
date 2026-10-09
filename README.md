# Pulzar for Omarchy

The device status of the Pulzar telemetry agent by rzilient, in the
[Omarchy](https://omarchy.org/) bar. A glyph in the bar, tinted by the state
of the agent, opens the latest data it collected on this device.

## Install

The plugin only shows what the Pulzar agent collects: it needs the agent,
which rzilient provides to its clients. On Omarchy you don't need the agent's
tray application, this plugin replaces it.

```sh
omarchy plugin add https://github.com/rzilient-club/omarchy-pulzar.git --enable
```

The widget goes to the right of the bar. Move it with
`omarchy bar move rzilient.pulzar --section left`. Update it with
`omarchy plugin update rzilient.pulzar` and remove it with
`omarchy plugin remove rzilient.pulzar`.

Without the agent, the panel says *Waiting for data*.

## What it shows

- **Summary**: telemetry active, waiting for data, agent not reporting (the
  data is older than the agent's `stale_after`), agent stopped, or snapshot
  unreadable. The bar glyph takes the same tone.
- **Device**: host name and serial number.
- **Usage**: memory and storage, with meters that turn to the warning tone at
  75 % and the error tone at 90 %.
- **Battery**: charge, health and condition (excellent ≥ 90 %, very good ≥ 80
  %, good ≥ 70 %, poor below).
- **Computer**: operating system, processor, graphics, installed memory,
  storage capacity, disk encryption, manufacturing date, agent version.
- **Collected data**: displays, highest temperature and the latest collection
  of every input.
- **Installed programs**, with a search (10 rows, or 50 while searching).
- **Copy support information**: a plain text summary for support requests,
  copied with `wl-copy`.

Languages: English, Spanish, Catalan and French. *Automatic* follows
`LANGUAGE` / `LC_ALL` / `LC_MESSAGES` / `LANG`; the language you pick is saved
in `~/.local/state/rzilient-pulzar/language`. The colors come from the current
Omarchy theme and follow theme switches.

## Usage

- Click the glyph to open the panel, right click to refresh.
- In the panel: `r` refreshes, `c` copies the support information, `/`
  focuses the program search, `Esc` closes.
- IPC:

  ```sh
  omarchy-shell rzilient.pulzar toggle
  omarchy-shell rzilient.pulzar status       # active, stale, stopped, waiting
  omarchy-shell rzilient.pulzar support      # the support text
  omarchy-shell rzilient.pulzar language es  # auto, en, es, ca, fr
  ```

## Settings

Inline in the widget entry of `~/.config/omarchy/shell.json`:

| Key | Default | |
| --- | --- | --- |
| `snapshotPath` | `/var/lib/siot-telemetry/systray/latest.lp` | Snapshot written by the agent |
| `refreshIntervalSec` | `5` | Poll interval. The file watch already catches every rewrite; the poll ages the data (stale) and finds a snapshot created later |

## How it works

The agent's `systray` output writes the latest metric of every input to
`/var/lib/siot-telemetry/systray/latest.lp`, in the InfluxDB line protocol, after a
`systray_snapshot` header line (`running`, `stale_after`). The plugin watches
that file; it never collects anything itself and never reaches the network.

```
Panel.qml       bar glyph + popup (entry point)
Telemetry.qml   snapshot, host name and language
Theme.qml       tones from the Omarchy theme (colors.toml)
Snapshot.js     line protocol parser + status builder
Format.js       sizes, dates, states, support text
Locales.js      labels of the four languages
```

`Snapshot.js`, `Format.js` and `Locales.js` follow the tray application the
agent ships for the other platforms: same states, formats, support text and
labels.

## Development

Link a checkout into the plugin directory:

```sh
ln -s "$PWD" ~/.config/omarchy/plugins/rzilient.pulzar
omarchy-shell shell rescanPlugins
omarchy plugin enable rzilient.pulzar
```

Omarchy hot-reloads plugins with `inotifywait -r`, which does not follow
symlinks: after an edit, recreate the link
(`ln -sfn … rzilient.pulzar.tmp && mv -T … rzilient.pulzar`) or run
`omarchy restart shell`. With several monitors, the IPC handler of the first
bar stays registered after a hot reload, so new IPC functions only appear
after `omarchy restart shell`.

Tests (Node; they drop the `.pragma library` line of the modules), on a
sample snapshot (`tests/latest.lp`):

```sh
node --test tests/*.test.js
```

## License

[MIT](LICENSE)
