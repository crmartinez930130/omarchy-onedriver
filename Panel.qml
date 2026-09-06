pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "qml" as Components
import "Theme.js" as Theme

Item {
    id: root

    property string moduleName: "crmartinez.onedrive"
    property var service: null
    readonly property string fontFamily: service ? service.fontFamily : "monospace"

    implicitWidth: 380
    implicitHeight: 480

    ListModel { id: itemsModel }
    ListModel { id: transfersModel }

    function _syncItems() {
        itemsModel.clear()
        var list = service ? service.items : []
        for (var i = 0; i < list.length; i++) {
            var entry = list[i]
            itemsModel.append({
                itemId: entry.id,
                name: entry.name,
                isFolder: entry.isFolder,
                size: entry.size
            })
        }
    }

    function _syncTransfers() {
        transfersModel.clear()
        var list = service ? service.transfers : []
        for (var i = 0; i < list.length; i++) {
            var transfer = list[i]
            transfersModel.append({
                transferId: transfer.id,
                name: transfer.name,
                transferState: transfer.state,
                bytesCompleted: transfer.bytesCompleted,
                bytesTotal: transfer.bytesTotal
            })
        }
    }

    function _urlToPath(fileUrl) {
        var text = String(fileUrl)
        if (text.indexOf("file://") === 0) text = text.substring(7)
        return decodeURIComponent(text)
    }

    onServiceChanged: { _syncItems(); _syncTransfers() }

    Connections {
        target: root.service
        function onItemsChanged() { root._syncItems() }
        function onTransfersChanged() { root._syncTransfers() }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        radius: 12
        border.color: Theme.border

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    text: "OneDrive"
                    color: Theme.text
                    font.bold: true
                    font.pixelSize: 20
                    Layout.fillWidth: true
                }

                BusyIndicator {
                    running: root.service ? root.service.busy : false
                    implicitWidth: 18
                    implicitHeight: 18
                }

                GhostButton {
                    text: "Sign out"
                    visible: root.service && root.service.signedIn
                    Layout.rightMargin: 4
                    onClicked: root.service.logout()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: root.service && root.service.lastError !== ""
                radius: 6
                color: Qt.rgba(0.95, 0.55, 0.66, 0.12)
                implicitHeight: errorLabel.implicitHeight + 12

                Label {
                    id: errorLabel
                    anchors.fill: parent
                    anchors.margins: 6
                    text: root.service ? root.service.lastError : ""
                    color: Theme.error
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !(root.service && root.service.signedIn)

                Components.AuthView {
                    anchors.centerIn: parent
                    fontFamily: root.fontFamily
                    onLoginRequested: if (root.service) root.service.login()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.service && root.service.signedIn
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    GhostButton {
                        text: "‹"
                        enabled: root.service && root.service.folderStack.length > 0
                        onClicked: root.service.goBack()
                    }

                    Label {
                        text: root.service ? root.service.currentFolderName : ""
                        color: Theme.textMuted
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }

                    GhostButton {
                        text: "󰉗"
                        toolTip: "New folder"
                        onClicked: {
                            newFolderDialog.initialValue = ""
                            newFolderDialog.open()
                        }
                    }

                    GhostButton {
                        text: "󰕒"
                        toolTip: "Upload"
                        onClicked: uploadDialog.open()
                    }

                    GhostButton {
                        text: "⟳"
                        toolTip: "Refresh"
                        onClicked: if (root.service) root.service.refresh()
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Components.DriveList {
                        anchors.fill: parent
                        fontFamily: root.fontFamily
                        model: itemsModel
                        onFolderRequested: function (itemId, name) { root.service.openFolder(itemId, name) }
                        onFileRequested: function (itemId, name) { root.service.startDownload(itemId, name) }
                        onRenameRequested: function (itemId, name) {
                            renameDialog.targetId = itemId
                            renameDialog.initialValue = name
                            renameDialog.open()
                        }
                        onDeleteRequested: function (itemId, name) {
                            deleteConfirm.targetId = itemId
                            deleteConfirm.message = "Delete “" + name + "”? This can't be undone."
                            deleteConfirm.open()
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: itemsModel.count === 0 && !(root.service && root.service.busy)
                        text: "This folder is empty."
                        color: Theme.textDim
                        font.pixelSize: 12
                    }

                    DropArea {
                        id: uploadDropArea
                        anchors.fill: parent
                        onEntered: function (drag) { drag.accepted = drag.hasUrls }
                        onDropped: function (drop) {
                            for (var i = 0; i < drop.urls.length; i++) {
                                var path = root._urlToPath(drop.urls[i])
                                var name = path.substring(path.lastIndexOf("/") + 1)
                                if (name !== "" && root.service) root.service.startUpload(path, name)
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: uploadDropArea.containsDrag
                            radius: 8
                            color: Qt.rgba(0.537, 0.706, 0.980, 0.14)
                            border.color: Theme.accent
                            border.width: 2

                            Label {
                                anchors.centerIn: parent
                                text: "Drop to upload"
                                color: Theme.accent
                                font.pixelSize: 13
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    visible: transfersModel.count > 0
                    color: Theme.border
                }

                Label {
                    visible: transfersModel.count > 0
                    text: "Transfers"
                    color: Theme.textDim
                    font.pixelSize: 11
                }

                Components.TransferList {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(140, transfersModel.count * 44)
                    visible: transfersModel.count > 0
                    model: transfersModel
                    onCancelRequested: function (transferId) { root.service.cancelTransfer(transferId) }
                }
            }
        }
    }

    component GhostButton: Button {
        id: ghostButton
        property string toolTip: ""
        implicitHeight: 26
        leftPadding: 8
        rightPadding: 8
        contentItem: Text {
            text: ghostButton.text
            color: ghostButton.enabled ? Theme.textMuted : Theme.textDim
            font.family: root.fontFamily
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 6
            color: ghostButton.down ? Theme.surfaceHover : "transparent"
        }
    }

    component DialogButton: Button {
        id: dialogButton
        property bool primary: false
        property color accentColor: Theme.accent
        implicitWidth: 76
        implicitHeight: 28
        contentItem: Text {
            text: dialogButton.text
            color: dialogButton.primary ? Theme.background : Theme.text
            font.pixelSize: 12
            font.bold: dialogButton.primary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 6
            border.width: dialogButton.primary ? 0 : 1
            border.color: Theme.border
            color: dialogButton.primary
                ? (dialogButton.down ? Qt.darker(dialogButton.accentColor, 1.15) : dialogButton.accentColor)
                : (dialogButton.down ? Theme.surfaceHover : "transparent")
        }
    }

    component DialogFooter: Item {
        id: footer
        signal cancelClicked()
        signal confirmClicked()
        property string confirmLabel: "OK"
        property color confirmColor: Theme.accent

        implicitHeight: 50

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            Item { Layout.fillWidth: true }
            DialogButton { text: "Cancel"; onClicked: footer.cancelClicked() }
            DialogButton { text: footer.confirmLabel; primary: true; accentColor: footer.confirmColor; onClicked: footer.confirmClicked() }
        }
    }

    component NamePromptDialog: Dialog {
        id: dialog
        property string initialValue: ""
        property string confirmLabel: "OK"
        signal confirmed(string value)

        x: Math.round(((parent ? parent.width : 0) - width) / 2)
        y: Math.round(((parent ? parent.height : 0) - height) / 2)
        modal: true
        standardButtons: Dialog.NoButton
        onOpened: { field.text = initialValue; field.selectAll(); field.forceActiveFocus() }
        onAccepted: if (field.text.trim() !== "") dialog.confirmed(field.text.trim())

        background: Rectangle {
            implicitWidth: 260
            color: Theme.surface
            border.color: Theme.border
            radius: 10
        }

        header: Label {
            text: dialog.title
            color: Theme.text
            font.bold: true
            padding: 14
        }

        contentItem: TextField {
            id: field
            color: Theme.text
            placeholderTextColor: Theme.textDim
            selectByMouse: true
            background: Rectangle {
                color: Theme.background
                border.color: Theme.border
                radius: 6
            }
            Keys.onReturnPressed: dialog.accept()
        }

        footer: DialogFooter {
            confirmLabel: dialog.confirmLabel
            onCancelClicked: dialog.reject()
            onConfirmClicked: dialog.accept()
        }
    }

    component ConfirmDialog: Dialog {
        id: dialog
        property string message: ""
        property string confirmLabel: "OK"
        property color confirmColor: Theme.accent
        signal confirmed()

        x: Math.round(((parent ? parent.width : 0) - width) / 2)
        y: Math.round(((parent ? parent.height : 0) - height) / 2)
        modal: true
        standardButtons: Dialog.NoButton
        onAccepted: dialog.confirmed()

        background: Rectangle {
            implicitWidth: 260
            color: Theme.surface
            border.color: Theme.border
            radius: 10
        }

        header: Label {
            text: dialog.title
            color: Theme.text
            font.bold: true
            padding: 14
        }

        contentItem: Label {
            text: dialog.message
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }

        footer: DialogFooter {
            confirmLabel: dialog.confirmLabel
            confirmColor: dialog.confirmColor
            onCancelClicked: dialog.reject()
            onConfirmClicked: dialog.accept()
        }
    }

    NamePromptDialog {
        id: newFolderDialog
        title: "New folder"
        confirmLabel: "Create"
        onConfirmed: function (value) { if (root.service) root.service.createFolder(value) }
    }

    NamePromptDialog {
        id: renameDialog
        title: "Rename"
        confirmLabel: "Rename"
        property string targetId: ""
        onConfirmed: function (value) { if (root.service) root.service.renameItem(targetId, value) }
    }

    ConfirmDialog {
        id: deleteConfirm
        title: "Delete item"
        confirmLabel: "Delete"
        confirmColor: Theme.error
        property string targetId: ""
        onConfirmed: if (root.service) root.service.deleteItem(targetId)
    }

    FileDialog {
        id: uploadDialog
        title: "Upload to " + (root.service ? root.service.currentFolderName : "OneDrive")
        fileMode: FileDialog.OpenFile
        onAccepted: {
            var path = root._urlToPath(selectedFile)
            var name = path.substring(path.lastIndexOf("/") + 1)
            if (root.service) root.service.startUpload(path, name)
        }
    }
}
