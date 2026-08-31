import QtQuick
import QtQuick.Controls

ListView {
    id: root
    property alias items: model
    signal folderRequested(string itemId, string name)
    clip: true
    delegate: ItemDelegate {
        width: root.width
        text: model.name
        onClicked: if (model.isFolder) root.folderRequested(model.id, model.name)
    }
}