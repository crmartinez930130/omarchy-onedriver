import QtQuick
import QtQuick.Controls

Menu {
    signal deleteRequested()
    signal renameRequested()
    MenuItem { text: "Rename"; onTriggered: renameRequested() }
    MenuItem { text: "Delete"; onTriggered: deleteRequested() }
}