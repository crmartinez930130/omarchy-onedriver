import QtQuick
import Quickshell
import Quickshell.Widgets
// Namespaced so qs.Ui's own Panel type doesn't shadow our local Panel.qml.
import qs.Ui as Ui

// Extends the shell's BarWidget base, which declares the `bar`, `settings`,
// `vertical` and `barSize` properties the bar host injects into each slot.
Ui.BarWidget {
    id: root

    moduleName: "crmartinez.onedrive"

    readonly property var service: bar && bar.shell ? bar.shell.serviceFor(root.moduleName) : null
    readonly property bool signedIn: service ? service.signedIn : false
    readonly property bool transferActive: service ? service.transferActive : false

    // Settings are injected onto the bar-widget instance, not the service,
    // so forward the ones the service actually needs across to it.
    onServiceChanged: _syncSettings()
    onSettingsChanged: _syncSettings()
    function _syncSettings() {
        if (!service) return
        service.downloadPath = (settings && settings.downloadPath) || ""
        service.uploadStartPath = (settings && settings.uploadStartPath) || ""
        service.barSection = (settings && settings.position) || "right"
        service.language = (settings && settings.language) || "en"
        service.trackedFolders = _parseTrackedFolders(settings && settings.trackedFolders)
    }

    function _parseTrackedFolders(raw) {
        if (!raw) return []
        try {
            var parsed = JSON.parse(raw)
            return Array.isArray(parsed) ? parsed : []
        } catch (error) {
            return []
        }
    }

    // Size to the bar's thickness, never to the window: since Omarchy 4.5 the
    // bar's PanelWindow spans the whole screen, so its height (1080px on a
    // 1080p monitor) blew this slot up and pushed every widget after it off
    // the bar.
    implicitWidth: root.vertical ? root.barSize : content.implicitWidth + 8
    implicitHeight: root.vertical ? content.implicitHeight + 8 : root.barSize

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: root.transferActive ? "󰇚" : "󰏊"
            color: root.signedIn ? "#a6e3a1" : "#bac2de"
            font.family: root.service ? root.service.fontFamily : "monospace"
            font.pixelSize: 16
        }

        Text {
            visible: root.transferActive
            text: "…"
            color: "#bac2de"
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: panelWindow.visible = !panelWindow.visible
    }

    PopupWindow {
        id: panelWindow
        implicitWidth: 380
        implicitHeight: 480
        visible: false
        color: "transparent"
        grabFocus: true

        anchor {
            id: popupAnchor
            window: root.QsWindow.window
            adjustment: PopupAdjustment.Slide
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            rect.width: 1
            rect.height: 1

            onAnchoring: {
                var win = root.QsWindow.window
                if (!win) return

                var margin = 6
                var popupWidth = panelWindow.implicitWidth
                var popupHeight = panelWindow.implicitHeight
                var position = root.bar ? root.bar.position : "top"

                var localX = root.width / 2 - popupWidth / 2
                var localY = root.height + margin
                if (position === "bottom") {
                    localY = -popupHeight - margin
                } else if (position === "left") {
                    localX = root.width + margin
                    localY = root.height / 2 - popupHeight / 2
                } else if (position === "right") {
                    localX = -popupWidth - margin
                    localY = root.height / 2 - popupHeight / 2
                }

                var point = win.contentItem.mapFromItem(root, localX, localY)
                if (position === "top" || position === "bottom") {
                    point.x = Math.max(margin, Math.min(point.x, win.width - popupWidth - margin))
                } else {
                    point.y = Math.max(margin, Math.min(point.y, win.height - popupHeight - margin))
                }

                popupAnchor.rect.x = Math.round(point.x)
                popupAnchor.rect.y = Math.round(point.y)
            }
        }

        Panel {
            anchors.fill: parent
            service: root.service
        }

        Shortcut {
            sequence: "Escape"
            onActivated: panelWindow.visible = false
        }
    }
}