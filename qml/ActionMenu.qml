import QtQuick
import QtQuick.Controls

Menu {
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
    MenuItem { text: root.openInBrowserLabel; enabled: root.hasWebUrl; onTriggered: root.openInBrowserRequested() }
    MenuItem { text: root.copyLinkLabel; enabled: root.hasWebUrl; onTriggered: root.copyLinkRequested() }
    MenuItem { text: root.renameLabel; onTriggered: root.renameRequested() }
    MenuItem { text: root.deleteLabel; onTriggered: root.deleteRequested() }
}