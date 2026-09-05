pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../Model.js" as Model

ListView {
    id: root
    signal folderRequested(string itemId, string name)
    signal fileRequested(string itemId, string name)
    clip: true
    spacing: 2

    delegate: ItemDelegate {
        id: delegate
        required property string itemId
        required property string name
        required property bool isFolder
        required property real size

        width: root.width
        text: (isFolder ? "󰉋  " : "󰈔  ") + name + (isFolder ? "" : "  ·  " + Model.formatBytes(size))
        onClicked: isFolder ? root.folderRequested(itemId, name) : root.fileRequested(itemId, name)
    }
}
