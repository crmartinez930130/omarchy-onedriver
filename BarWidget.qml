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
        onClicked: panelLoader.active = !panelLoader.active
    }

    Loader {
        id: panelLoader
        active: false
        source: "Panel.qml"
        onLoaded: if (item) item.service = root.service
    }
}