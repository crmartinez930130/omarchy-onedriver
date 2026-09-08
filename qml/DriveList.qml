pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Model.js" as Model
import "../Theme.js" as Theme

ListView {
    id: root
    property string fontFamily: "monospace"
    property string renameLabel: "Rename"
    property string deleteLabel: "Delete"
    property string openInBrowserLabel: "Open in browser"
    property string copyLinkLabel: "Copy link"
    signal folderRequested(string itemId, string name)
    signal fileRequested(string itemId, string name)
    signal renameRequested(string itemId, string name)
    signal deleteRequested(string itemId, string name)
    signal openInBrowserRequested(string webUrl)
    signal copyLinkRequested(string webUrl)

    clip: true
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    delegate: ItemDelegate {
        id: row
        required property string itemId
        required property string name
        required property bool isFolder
        required property real size
        required property string webUrl

        width: root.width
        height: 42
        hoverEnabled: true
        leftPadding: 10
        rightPadding: 6
        onClicked: isFolder ? root.folderRequested(itemId, name) : root.fileRequested(itemId, name)

        background: Rectangle {
            radius: 6
            color: row.down ? Theme.border : (row.hovered ? Theme.surfaceHover : "transparent")
        }

        contentItem: RowLayout {
            spacing: 8

            Text {
                text: row.isFolder ? "󰉋" : "󰈔"
                color: Theme.accent
                font.family: root.fontFamily
                font.pixelSize: 15
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: row.name
                    color: Theme.text
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    visible: !row.isFolder
                    text: Model.formatBytes(row.size)
                    color: Theme.textDim
                    font.pixelSize: 11
                    Layout.fillWidth: true
                }
            }

            ToolButton {
                id: menuButton
                hoverEnabled: true
                implicitWidth: 26
                implicitHeight: 26
                Layout.alignment: Qt.AlignVCenter
                background: Rectangle {
                    radius: 6
                    color: menuButton.down ? Theme.border : (menuButton.hovered ? Theme.surfaceHover : "transparent")
                }
                contentItem: Text {
                    text: "⋮"
                    color: Theme.textMuted
                    font.pixelSize: 15
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: rowMenu.open()

                ActionMenu {
                    id: rowMenu
                    renameLabel: root.renameLabel
                    deleteLabel: root.deleteLabel
                    openInBrowserLabel: root.openInBrowserLabel
                    copyLinkLabel: root.copyLinkLabel
                    hasWebUrl: row.webUrl !== ""
                    onRenameRequested: root.renameRequested(row.itemId, row.name)
                    onDeleteRequested: root.deleteRequested(row.itemId, row.name)
                    onOpenInBrowserRequested: root.openInBrowserRequested(row.webUrl)
                    onCopyLinkRequested: root.copyLinkRequested(row.webUrl)
                }
            }
        }
    }
}
