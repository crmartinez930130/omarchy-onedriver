import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property string moduleName: "crmartinez.onedrive"
    property var bar: null

    readonly property var service: bar && bar.shell ? bar.shell.serviceFor(root.moduleName) : null
    readonly property bool signedIn: service ? service.signedIn : false
    readonly property bool transferActive: service ? service.transferActive : false

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

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
    }
}