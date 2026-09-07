import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
    id: root

    property string moduleName: "crmartinez.onedrive"
    property var manifest: null
    readonly property string pluginDir: manifest && manifest.__sourceDir
        ? String(manifest.__sourceDir)
        : Qt.resolvedUrl(".").toString().replace("file://", "")

    property bool signedIn: false
    property bool busy: false
    property string lastError: ""
    property string fontFamily: "monospace"
    property string downloadPath: ""
    property string uploadStartPath: ""
    property string barSection: "right"
    property string accountName: ""
    property string accountEmail: ""
    property string language: "en"
    property string trackedFolder: ""
    property bool trackedFolderEnabled: false

    onTrackedFolderChanged: _pushSyncConfig()
    onTrackedFolderEnabledChanged: _pushSyncConfig()

    property string currentFolderId: ""
    property string currentFolderName: "OneDrive"
    property var folderStack: []
    property var items: []
    property var transfers: []

    readonly property bool transferActive: transfers.some(function (transfer) {
        return transfer.state === "running" || transfer.state === "queued"
    })

    property int _nextId: 1
    property var _pending: ({})

    function start() {
        if (helperProcess.running) return
        helperProcess.workingDirectory = root.pluginDir
        helperProcess.command = ["python3", "-u", "-m", "helper.main"]
        helperProcess.running = true
    }

    Component.onCompleted: {
        start()
        refreshStatus()
        fontMatchProcess.running = true
    }

    // Icon glyphs are Nerd Font codepoints; resolve the same fontconfig
    // alias the shell itself uses so they render on whatever Nerd Font the
    // user has picked via `omarchy font set` instead of the app default.
    Process {
        id: fontMatchProcess
        command: ["fc-match", "-f", "%{family[0]}", "monospace"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var name = String(text || "").trim()
                if (name.length > 0) root.fontFamily = name
            }
        }
    }

    // Applies immediately for this session, and persists to shell.json via
    // the same CLI the settings schema is meant to be edited through, so it
    // survives a restart and stays visible to `omarchy bar set`/list.
    function setDownloadPath(path) {
        root.downloadPath = path
        _persistSetting("downloadPath", path)
    }

    function setUploadStartPath(path) {
        root.uploadStartPath = path
        _persistSetting("uploadStartPath", path)
    }

    // Stored both as our own schema value (so it shows back as "current" the
    // next time Settings opens) and as an actual `bar move`, which is what
    // relocates the icon — the schema field alone wouldn't move anything.
    function setBarSection(section) {
        root.barSection = section
        _persistSetting("position", section)
        if (moveProcess.running) return
        moveProcess.command = ["omarchy", "bar", "move", root.moduleName, "--section", section]
        moveProcess.running = true
    }

    function setLanguage(lang) {
        root.language = lang
        _persistSetting("language", lang)
    }

    function setTrackedFolder(path) {
        root.trackedFolder = path
        _persistSetting("trackedFolder", path)
    }

    function setTrackedFolderEnabled(enabled) {
        root.trackedFolderEnabled = enabled
        _persistSetting("trackedFolderEnabled", enabled ? "true" : "false", true)
    }

    // Tells the helper's background FolderSync what to watch. Fires whenever
    // either half of the config changes, including the settings-injection
    // pass on shell/plugin restart (see BarWidget._syncSettings) — not just
    // user-initiated changes — since the helper is a fresh process each time
    // and starts out not watching anything.
    function _pushSyncConfig() {
        _call("sync.configure", {localPath: root.trackedFolder, enabled: root.trackedFolderEnabled}, null, true)
    }

    function _persistSetting(key, value, asJson) {
        if (settingsProcess.running) return
        var command = ["omarchy", "bar", "set", root.moduleName, key, value]
        if (asJson) command.push("--json")
        settingsProcess.command = command
        settingsProcess.running = true
    }

    Process {
        id: settingsProcess
        command: []
        onExited: function (exitCode) {
            if (exitCode !== 0) root.lastError = "Couldn't save the setting"
        }
    }

    Process {
        id: moveProcess
        command: []
        onExited: function (exitCode) {
            if (exitCode !== 0) root.lastError = "Couldn't move the widget"
        }
    }

    property var _silentIds: ({})

    // `silent` is for calls whose failure shouldn't blank the panel with an
    // error banner over a merely decorative feature (e.g. the account label)
    // — a real session expiry still resyncs signedIn either way.
    function _call(method, params, onResult, silent) {
        if (!helperProcess.running) start()
        var id = String(root._nextId++)
        root._pending[id] = onResult || null
        if (silent) root._silentIds[id] = true
        helperProcess.write(JSON.stringify({id: id, method: method, params: params || {}}) + "\n")
    }

    function _handleLine(line) {
        var text = String(line || "").trim()
        if (text === "") return
        var message
        try {
            message = JSON.parse(text)
        } catch (error) {
            return
        }
        var id = message.id !== undefined && message.id !== null ? String(message.id) : ""
        var callback = root._pending[id]
        if (callback !== undefined) delete root._pending[id]
        var silent = !!root._silentIds[id]
        if (silent) delete root._silentIds[id]
        if (!message.ok) {
            var errorMessage = (message.error && message.error.message) || "Request failed"
            if (!silent) root.lastError = errorMessage
            if (errorMessage === root._sessionExpiredMessage) root.refreshStatus()
            if (callback) callback(null, errorMessage)
            return
        }
        if (callback) callback(message.result, null)
    }

    // Must match the RuntimeError message main.py raises when a 401 survives
    // its own refresh-and-retry — the signal to resync signedIn instead of
    // just surfacing a stale-looking error.
    readonly property string _sessionExpiredMessage: "Session expired — please sign in again"

    function _clearSessionState() {
        root.items = []
        root.transfers = []
        root.folderStack = []
        root.currentFolderId = ""
        root.currentFolderName = "OneDrive"
        root.accountName = ""
        root.accountEmail = ""
    }

    function refreshStatus() {
        root.busy = true
        _call("auth.status", {}, function (result, error) {
            root.busy = false
            if (error) return
            var wasSignedIn = root.signedIn
            root.signedIn = !!(result && result.signedIn)
            if (root.signedIn) _resetToRoot()
            else if (wasSignedIn) _clearSessionState()
        })
    }

    function login() {
        root.busy = true
        root.lastError = ""
        _call("auth.login", {}, function (result, error) {
            root.busy = false
            if (error) return
            root.signedIn = !!(result && result.signedIn)
            if (root.signedIn) _resetToRoot()
        })
    }

    function logout() {
        _call("auth.logout", {}, function () {
            root.signedIn = false
            root._clearSessionState()
        })
    }

    function _resetToRoot() {
        root.folderStack = []
        _load("", "OneDrive")
        _loadAccount()
    }

    function _loadAccount() {
        _call("auth.me", {}, function (result, error) {
            if (error) return
            root.accountName = (result && result.displayName) || ""
            root.accountEmail = (result && result.email) || ""
        }, true)
    }

    function openFolder(itemId, name) {
        root.folderStack = root.folderStack.concat([{id: root.currentFolderId, name: root.currentFolderName}])
        _load(itemId, name)
    }

    function goBack() {
        if (root.folderStack.length === 0) return
        var previous = root.folderStack[root.folderStack.length - 1]
        root.folderStack = root.folderStack.slice(0, -1)
        _load(previous.id, previous.name)
    }

    function refresh() {
        _load(root.currentFolderId, root.currentFolderName)
        _pollTransfers()
    }

    function _load(itemId, name) {
        root.busy = true
        _call("drive.list", {itemId: itemId || ""}, function (result, error) {
            root.busy = false
            if (error) return
            root.currentFolderId = itemId || ""
            root.currentFolderName = name || "OneDrive"
            root.items = Model.items(result || {})
        })
    }

    function startDownload(itemId, name) {
        var baseDir = root.downloadPath !== "" ? root.downloadPath : Quickshell.env("HOME") + "/Downloads"
        var destination = baseDir + "/" + name
        _call("transfer.download", {itemId: itemId, destination: destination, name: name}, function (result, error) {
            if (!error) _pollTransfers()
        })
    }

    function startUpload(sourcePath, name) {
        _call("transfer.upload", {parentId: root.currentFolderId, source: sourcePath, name: name}, function (result, error) {
            if (!error) _pollTransfers()
        })
    }

    function cancelTransfer(transferId) {
        _call("transfer.cancel", {transferId: transferId}, function () { _pollTransfers() })
    }

    function dismissTransfer(transferId) {
        _call("transfer.dismiss", {transferId: transferId}, function () { _pollTransfers() })
    }

    function createFolder(name) {
        _call("drive.mkdir", {parentId: root.currentFolderId, name: name}, function (result, error) {
            if (!error) refresh()
        })
    }

    function renameItem(itemId, name) {
        _call("drive.rename", {itemId: itemId, name: name}, function (result, error) {
            if (!error) refresh()
        })
    }

    function deleteItem(itemId) {
        _call("drive.delete", {itemId: itemId}, function (result, error) {
            if (!error) refresh()
        })
    }

    function _pollTransfers() {
        if (!root.signedIn) return
        var previous = root.transfers
        _call("transfer.list", {}, function (result, error) {
            if (error) return
            var next = Array.isArray(result) ? result : []
            root.transfers = next
            if (root._hasNewlyCompletedUpload(previous, next)) _load(root.currentFolderId, root.currentFolderName)
        })
    }

    // Uploads mutate the folder we're looking at, but only once the transfer
    // actually finishes — refreshing when it merely starts would just reload
    // the listing before the file exists. Fires once per transfer, the poll
    // tick its state first reads back as "completed".
    function _hasNewlyCompletedUpload(previous, next) {
        for (var i = 0; i < next.length; i++) {
            var transfer = next[i]
            if (transfer.direction !== "upload" || transfer.state !== "completed") continue
            var alreadyDone = previous.some(function (item) { return item.id === transfer.id && item.state === "completed" })
            if (!alreadyDone) return true
        }
        return false
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.signedIn
        onTriggered: root._pollTransfers()
    }

    Process {
        id: helperProcess
        running: false
        command: []
        stdinEnabled: true
        stdout: SplitParser { splitMarker: "\n"; onRead: function (data) { root._handleLine(data) } }
        stderr: SplitParser { splitMarker: "\n"; onRead: function (data) { console.warn("[onedrive helper]", data) } }
        onExited: function (exitCode) {
            if (exitCode !== 0) root.lastError = "OneDrive helper exited unexpectedly"
        }
    }
}
