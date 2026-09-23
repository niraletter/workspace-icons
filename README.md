# Workspace Icons

Bar widget for Omarchy that shows workspace numbers with app icons.

Cloned from the built in workspaces widget and extended to show what is open.

## What it shows

* Workspace numbers 1 to 5, plus 6 to 10 when used
* One icon per open window, in tile order
* Active window icon is bright, others are dimmed
* Small accent tick under the focused window
* Dot badge for floating windows
* Scratchpad slot that only shows when used
* Tooltips with app names

## Install

```bash
omarchy plugin add https://github.com/niraletter/workspace-icons --enable
```

Then place Workspace Icons in your bar layout. It replaces the built in workspaces widget.

## Remove

```bash
omarchy plugin remove nira.workspace-icons --yes
```

Disabling or removing it restores the built in widget.

## Files

* `manifest.json` - plugin contract
* `BarWidget.qml` - bar widget

## Validate

```bash
omarchy plugin validate ~/Projects/workspace-icons
```

## License

MIT. See LICENSE.
