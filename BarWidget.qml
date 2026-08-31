import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property string moduleName: "crmartinez.onedrive"
    property bool signedIn: false
    property bool transferActive: false

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: root.transferActive ? "󰇚" : "󰕳"
            color: root.signedIn ? "#a6e3a1" : "#bac2de"
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
        onClicked: panelLoader.active = true
    }

    Loader {
        id: panelLoader
        active: false
        source: "Panel.qml"
    }
}