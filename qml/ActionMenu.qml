import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme.js" as Theme

Popup {
    id: root
    property string renameLabel: "Rename"
    property string deleteLabel: "Delete"
    property string openInBrowserLabel: "Open in browser"
    property string copyLinkLabel: "Copy link"
    property bool hasWebUrl: true
    signal deleteRequested()
    signal renameRequested()
    signal openInBrowserRequested()
    signal copyLinkRequested()

    y: parent ? parent.height + 4 : 0
    x: parent ? parent.width - width : 0
    implicitWidth: 200
    padding: 4
    modal: false
    focus: true
    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

    background: Rectangle {
        color: Theme.surface
        border.color: Theme.border
        radius: 8
    }

    contentItem: ColumnLayout {
        spacing: 0

        ActionMenuRow {
            text: root.openInBrowserLabel
            enabled: root.hasWebUrl
            onClicked: { root.close(); root.openInBrowserRequested() }
        }
        ActionMenuRow {
            text: root.copyLinkLabel
            enabled: root.hasWebUrl
            onClicked: { root.close(); root.copyLinkRequested() }
        }
        ActionMenuRow {
            text: root.renameLabel
            onClicked: { root.close(); root.renameRequested() }
        }
        ActionMenuRow {
            text: root.deleteLabel
            destructive: true
            onClicked: { root.close(); root.deleteRequested() }
        }
    }

    component ActionMenuRow: Button {
        id: rowButton
        property bool destructive: false
        Layout.fillWidth: true
        hoverEnabled: true
        implicitHeight: 32
        leftPadding: 10
        rightPadding: 10
        contentItem: Text {
            text: rowButton.text
            color: !rowButton.enabled ? Theme.textDim : (rowButton.destructive ? Theme.error : Theme.text)
            font.pixelSize: 12
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 5
            color: rowButton.down ? Theme.border : (rowButton.hovered ? Theme.surfaceHover : "transparent")
        }
    }
}
