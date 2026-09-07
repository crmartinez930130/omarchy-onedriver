# OneDrive Omarchy Plugin

Personal Microsoft OneDrive client for the Omarchy bar. It provides OAuth
login, folder browsing, file management, and background uploads/downloads.

The first release targets personal Microsoft accounts only. The helper keeps
OAuth tokens under `${XDG_STATE_HOME:-~/.local/state}/onedrive-omarchy/` with
restricted permissions; secrets are never placed in QML or `shell.json`.

## Requirements

- Omarchy (Hyprland + Quickshell + UWSM).
- Python 3 (used to run the background helper; no extra packages needed).
- A personal Microsoft account (outlook.com, hotmail.com, live.com, or a
  Microsoft account tied to your own email).

## Setup

Each install talks to its own Microsoft Entra app registration — nothing is
shared between users, and no secret ever leaves your machine.

### 1. Register an Azure app

1. Go to the [Microsoft Entra admin center](https://entra.microsoft.com/) →
   **App registrations** → **New registration**.
2. Any name works (e.g. "OneDrive Omarchy Plugin").
3. Under **Supported account types**, choose **Personal Microsoft accounts
   only**.
4. Under **Redirect URI**, pick platform **Mobile and desktop applications**
   and add `http://127.0.0.1:8765/callback`.
5. Click **Register**, then copy the **Application (client) ID** shown on the
   app's overview page — you'll need it in the next step.
6. Under **API permissions**, add the delegated Microsoft Graph permissions
   `Files.ReadWrite`, `User.Read`, and `offline_access` (`User.Read` and
   `offline_access` are usually already present by default).

No client secret is needed — this is a public client (native/desktop app),
and the OAuth exchange never leaves your machine.

### 2. Configure the client ID

The helper reads the client ID from the `ONEDRIVE_CLIENT_ID` environment
variable. It has to be set in the session Omarchy's shell process actually
inherits, not just a terminal you happen to have open — the standard place
for that is UWSM's env file:

```bash
mkdir -p ~/.config/uwsm
cat >> ~/.config/uwsm/env <<'EOF'

# OneDrive Omarchy plugin (Microsoft Entra app client ID)
export ONEDRIVE_CLIENT_ID="your-application-client-id"
EOF
```

This only takes effect on the next full session start (log out and back in,
or reboot) — `omarchy restart shell` alone won't pick up a new UWSM env file.

### 3. Install the plugin

```bash
mkdir -p ~/.config/omarchy/plugins
git clone <this-repo-url> ~/.config/omarchy/plugins/crmartinez.onedrive
```

If the plugin is published to a git host, `omarchy plugin add <git-url>
--enable` does the clone-and-enable in one step instead.

### 4. Enable it

```bash
omarchy plugin enable crmartinez.onedrive --section right
```

(`--section left` or `--section center` also work — this only sets where it
first appears; it can be moved later, including from its own Settings
screen.)

### 5. First sign-in

Click the OneDrive icon in the bar and press **Sign in**. This opens your
default browser to Microsoft's login page; after you approve, the tab says
you can close it and the panel signs itself in.

If the browser opens but the panel seems stuck waiting after you approve,
your browser's tracking-prevention setting may be blocking a third-party
cookie Microsoft's personal-account login redirect relies on (seen with
Edge's "Strict" Tracking Prevention). Lowering that site's tracking
prevention (or allowing cookies for `login.live.com`/`account.live.com`)
resolves it; this is a browser setting, not something the plugin can work
around.

## Settings

Click the ⚙ button in the panel to open Settings:

- **Download folder** — where files land when you click one to download.
  Defaults to `~/Downloads`.
- **Upload start folder** — which local folder the upload file browser opens
  to. Defaults to your home folder.
- **Bar position** — left, center, or right section of the bar.
- **Language** — English or Español.
- **Tracked folder** + **Auto-upload** — pick a local folder and turn the
  toggle on to have new or changed files inside it uploaded automatically to
  a same-named folder at the root of your OneDrive (subfolders included).
  This is one-way: it never downloads anything back, and deleting a file
  locally does not delete it from OneDrive. Files are picked up on a scan
  that runs roughly every 30 seconds while the plugin is running, and show
  up in the normal Transfers list like any other upload.

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
