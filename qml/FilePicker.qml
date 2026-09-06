pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import "../Model.js" as Model
import "../Theme.js" as Theme

ListView {
    id: root
    property string fontFamily: "monospace"
    property string startPath: ""
    // Browsing to pick a destination folder, not one or more files: files
    // still show for context but aren't clickable, and there's no checkbox
    // selection state to track — the caller reads currentPath instead.
    property bool selectFolders: false
    property var selectedPaths: []

    readonly property string currentPath: String(folderModel.folder).replace("file://", "")
    readonly property bool canGoUp: String(folderModel.parentFolder) !== ""

    clip: true
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds
    model: folderModel

    Component.onCompleted: resetToStart()

    function resetToStart() {
        folderModel.folder = "file://" + (root.startPath !== "" ? root.startPath : Quickshell.env("HOME"))
    }

    function goUp() {
        if (canGoUp) folderModel.folder = folderModel.parentFolder
    }

    function navigateTo(path) {
        folderModel.folder = "file://" + path
    }

    function isSelected(path) {
        return root.selectedPaths.indexOf(path) !== -1
    }

    function toggleSelected(path) {
        var index = root.selectedPaths.indexOf(path)
        var next = root.selectedPaths.slice()
        if (index === -1) next.push(path)
        else next.splice(index, 1)
        root.selectedPaths = next
    }

    FolderListModel {
        id: folderModel
        showDirsFirst: true
        showDotAndDotDot: false
        sortField: FolderListModel.Name
    }

    delegate: ItemDelegate {
        id: delegate
        required property string fileName
        required property string filePath
        required property bool fileIsDir
        required property real fileSize

        readonly property bool selected: !fileIsDir && root.isSelected(filePath)
        readonly property bool interactive: fileIsDir || !root.selectFolders

        width: root.width
        height: 36
        hoverEnabled: delegate.interactive
        leftPadding: 10
        rightPadding: 6
        opacity: delegate.interactive ? 1.0 : 0.4
        onClicked: {
            if (fileIsDir) { root.navigateTo(filePath); return }
            if (!root.selectFolders) root.toggleSelected(filePath)
        }

        background: Rectangle {
            radius: 6
            color: delegate.down ? Theme.border : (delegate.hovered ? Theme.surfaceHover : "transparent")
        }

        contentItem: RowLayout {
            spacing: 8

            Text {
                text: delegate.fileIsDir ? "󰉋" : (root.selectFolders ? "󰈔" : (delegate.selected ? "󰄲" : "󰄱"))
                color: delegate.fileIsDir ? Theme.accent : (!root.selectFolders && delegate.selected ? Theme.accent : Theme.textDim)
                font.family: root.fontFamily
                font.pixelSize: 15
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: delegate.fileName
                color: Theme.text
                font.pixelSize: 13
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: !delegate.fileIsDir
                text: Model.formatBytes(delegate.fileSize)
                color: Theme.textDim
                font.pixelSize: 11
            }
        }
    }
}
