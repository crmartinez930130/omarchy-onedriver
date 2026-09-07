import QtQuick
import QtQuick.Controls

Menu {
    id: root
    property string renameLabel: "Rename"
    property string deleteLabel: "Delete"
    signal deleteRequested()
    signal renameRequested()
    MenuItem { text: root.renameLabel; onTriggered: root.renameRequested() }
    MenuItem { text: root.deleteLabel; onTriggered: root.deleteRequested() }
}