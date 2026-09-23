# Workspace Icons

Bar widget for Omarchy that shows workspace numbers with app icons.
<br/>
<img width="730" height="48" alt="preview" src="https://github.com/user-attachments/assets/3c6a4f62-560f-41cf-ad67-3f28c66d7311" />


## What it shows

* One icon per open window, in tile order
* Active window icon is bright, others are dimmed
* Small accent tick under the focused window
* Dot badge for floating windows
* Scratchpad slot that only shows when used

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

This project is licensed under the [MIT License](LICENSE).
