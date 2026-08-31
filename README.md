# OneDrive Omarchy Plugin

Personal Microsoft OneDrive client for the Omarchy bar. It provides OAuth
login, folder browsing, file management, and background uploads/downloads.

The first release targets personal Microsoft accounts only. The helper keeps
OAuth tokens under `${XDG_STATE_HOME:-~/.local/state}/onedrive-omarchy/` with
restricted permissions; secrets are never placed in QML or `shell.json`.

## Microsoft application setup

1. Register an app in the [Microsoft Entra admin center](https://entra.microsoft.com/).
2. Choose the **Personal Microsoft accounts only** audience.
3. Add the redirect URI `http://127.0.0.1:8765/callback` as a mobile/desktop public client.
4. Grant delegated `Files.ReadWrite` and `offline_access` permissions.
5. Configure the client ID for the helper without committing it:

```bash
export ONEDRIVE_CLIENT_ID="your-application-client-id"
```

## Development

Install the directory as a user plugin while developing:

```bash
mkdir -p ~/.config/omarchy/plugins
ln -sfn "$PWD" ~/.config/omarchy/plugins/crmartinez.onedrive
omarchy plugin validate onedrive-omarchy-plugin
```

The plugin currently contains no credentials or local configuration. OAuth
tokens are stored outside this repository by the helper.

## Validation

```bash
omarchy plugin validate onedrive-omarchy-plugin
qmllint onedrive-omarchy-plugin/*.qml onedrive-omarchy-plugin/qml/*.qml
python3 -m unittest discover -s onedrive-omarchy-plugin/helper -p 'test_*.py'
```

Install the directory as a user plugin and reload the Omarchy shell to test
the widget and service. Transfers continue in the helper after the panel is
closed; progress is exposed as `transferProgress` IPC events.