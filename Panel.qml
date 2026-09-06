pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "qml" as Components
import "Theme.js" as Theme

Item {
    id: root

    property string moduleName: "crmartinez.onedrive"
    property var service: null
    property bool showSettings: false
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
                bytesTotal: transfer.bytesTotal,
                error: transfer.error || ""
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

                GhostButton {
                    text: "‹"
                    visible: root.showSettings
                    onClicked: root.showSettings = false
                }

                Label {
                    text: root.showSettings ? "Settings" : "OneDrive"
                    color: Theme.text
                    font.bold: true
                    font.pixelSize: 20
                    Layout.fillWidth: true
                }

                BusyIndicator {
                    visible: !root.showSettings
                    running: root.service ? root.service.busy : false
                    implicitWidth: 28
                    implicitHeight: 28
                }

                GhostButton {
                    text: "⚙"
                    toolTip: "Settings"
                    visible: !root.showSettings
                    onClicked: root.showSettings = true
                }

                GhostButton {
                    text: "Sign out"
                    visible: !root.showSettings && root.service && root.service.signedIn
                    Layout.rightMargin: 4
                    onClicked: root.service.logout()
                }
            }

            ColumnLayout {
                id: mainScreen
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.showSettings
                spacing: 10

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
                            onClicked: uploadPickerDialog.open()
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

            ColumnLayout {
                id: settingsScreen
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.showSettings
                spacing: 4

                SettingsRow {
                    text: "Download folder"
                    value: (root.service && root.service.downloadPath) ? root.service.downloadPath : "~/Downloads (default)"
                    onClicked: {
                        downloadFolderDialog.startPath = root.service ? root.service.downloadPath : ""
                        downloadFolderDialog.open()
                    }
                }

                SettingsRow {
                    text: "Upload start folder"
                    value: (root.service && root.service.uploadStartPath) ? root.service.uploadStartPath : "Home folder (default)"
                    onClicked: {
                        uploadStartFolderDialog.startPath = root.service ? root.service.uploadStartPath : ""
                        uploadStartFolderDialog.open()
                    }
                }

                Label {
                    text: "Bar position"
                    color: Theme.textDim
                    font.pixelSize: 11
                    Layout.topMargin: 10
                }

                RowLayout {
                    id: positionRow
                    Layout.fillWidth: true
                    spacing: 6
                    readonly property string current: (root.service && root.service.barSection) ? root.service.barSection : "right"

                    PositionOption {
                        text: "Left"
                        selected: positionRow.current === "left"
                        onClicked: if (root.service) root.service.setBarSection("left")
                    }
                    PositionOption {
                        text: "Center"
                        selected: positionRow.current === "center"
                        onClicked: if (root.service) root.service.setBarSection("center")
                    }
                    PositionOption {
                        text: "Right"
                        selected: positionRow.current === "right"
                        onClicked: if (root.service) root.service.setBarSection("right")
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    component GhostButton: Button {
        id: ghostButton
        property string toolTip: ""
        hoverEnabled: true
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
            color: ghostButton.down ? Theme.border : (ghostButton.hovered ? Theme.surfaceHover : "transparent")
        }
    }

    component DialogButton: Button {
        id: dialogButton
        property bool primary: false
        property color accentColor: Theme.accent
        hoverEnabled: true
        implicitHeight: 28
        leftPadding: 14
        rightPadding: 14
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
                ? (dialogButton.down ? Qt.darker(dialogButton.accentColor, 1.3) : (dialogButton.hovered ? Qt.darker(dialogButton.accentColor, 1.15) : dialogButton.accentColor))
                : (dialogButton.down ? Theme.border : (dialogButton.hovered ? Theme.surfaceHover : "transparent"))
        }
    }

    component SettingsRow: Button {
        id: settingsRow
        property string value: ""
        hoverEnabled: true
        Layout.fillWidth: true
        implicitHeight: 44
        leftPadding: 12
        rightPadding: 12
        contentItem: RowLayout {
            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true

                Label {
                    text: settingsRow.text
                    color: Theme.text
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }

                Label {
                    text: settingsRow.value
                    visible: settingsRow.value !== ""
                    color: Theme.textDim
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
            Label {
                text: "›"
                color: Theme.textDim
                font.pixelSize: 13
            }
        }
        background: Rectangle {
            radius: 6
            color: settingsRow.down ? Theme.border : (settingsRow.hovered ? Theme.surfaceHover : "transparent")
        }
    }

    component PositionOption: Button {
        id: option
        property bool selected: false
        hoverEnabled: true
        Layout.fillWidth: true
        implicitHeight: 30
        contentItem: Text {
            text: option.text
            color: option.selected ? Theme.background : Theme.text
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 6
            border.width: option.selected ? 0 : 1
            border.color: Theme.border
            color: option.selected
                ? (option.down ? Qt.darker(Theme.accent, 1.3) : (option.hovered ? Qt.darker(Theme.accent, 1.15) : Theme.accent))
                : (option.down ? Theme.border : (option.hovered ? Theme.surfaceHover : "transparent"))
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
        property string placeholder: ""
        property bool allowEmpty: false
        signal confirmed(string value)

        x: Math.round(((parent ? parent.width : 0) - width) / 2)
        y: Math.round(((parent ? parent.height : 0) - height) / 2)
        modal: true
        standardButtons: Dialog.NoButton
        onOpened: { field.text = initialValue; field.selectAll(); field.forceActiveFocus() }
        onAccepted: if (dialog.allowEmpty || field.text.trim() !== "") dialog.confirmed(field.text.trim())

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
            placeholderText: dialog.placeholder
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

    component FilePickerDialog: Dialog {
        id: dialog
        signal confirmed(var paths)

        x: Math.round(((parent ? parent.width : 0) - width) / 2)
        y: Math.round(((parent ? parent.height : 0) - height) / 2)
        modal: true
        standardButtons: Dialog.NoButton
        onOpened: {
            picker.selectedPaths = []
            picker.startPath = root.service ? root.service.uploadStartPath : ""
            picker.resetToStart()
        }
        onAccepted: if (picker.selectedPaths.length > 0) dialog.confirmed(picker.selectedPaths)

        background: Rectangle {
            implicitWidth: 320
            color: Theme.surface
            border.color: Theme.border
            radius: 10
        }

        header: Item {
            implicitHeight: headerColumn.implicitHeight + 20

            ColumnLayout {
                id: headerColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    GhostButton {
                        text: "‹"
                        enabled: picker.canGoUp
                        onClicked: picker.goUp()
                    }

                    Label {
                        text: "Upload files"
                        color: Theme.text
                        font.bold: true
                        Layout.fillWidth: true
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: picker.currentPath
                    color: Theme.textMuted
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                }
            }
        }

        contentItem: Components.FilePicker {
            id: picker
            fontFamily: root.fontFamily
            implicitWidth: 300
            implicitHeight: 280
        }

        footer: DialogFooter {
            confirmLabel: "Upload (" + picker.selectedPaths.length + ")"
            onCancelClicked: dialog.reject()
            onConfirmClicked: dialog.accept()
        }
    }

    FilePickerDialog {
        id: uploadPickerDialog
        onConfirmed: function (paths) {
            if (!root.service) return
            for (var i = 0; i < paths.length; i++) {
                var path = paths[i]
                var name = path.substring(path.lastIndexOf("/") + 1)
                if (name !== "") root.service.startUpload(path, name)
            }
        }
    }

    component FolderPickerDialog: Dialog {
        id: dialog
        property string startPath: ""
        property string dialogTitle: "Select folder"
        signal confirmed(string path)

        x: Math.round(((parent ? parent.width : 0) - width) / 2)
        y: Math.round(((parent ? parent.height : 0) - height) / 2)
        modal: true
        standardButtons: Dialog.NoButton
        onOpened: { picker.startPath = dialog.startPath; picker.resetToStart() }
        onAccepted: dialog.confirmed(picker.currentPath)

        background: Rectangle {
            implicitWidth: 320
            color: Theme.surface
            border.color: Theme.border
            radius: 10
        }

        header: Item {
            implicitHeight: headerColumn.implicitHeight + 20

            ColumnLayout {
                id: headerColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    GhostButton {
                        text: "‹"
                        enabled: picker.canGoUp
                        onClicked: picker.goUp()
                    }

                    Label {
                        text: dialog.dialogTitle
                        color: Theme.text
                        font.bold: true
                        Layout.fillWidth: true
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: picker.currentPath
                    color: Theme.textMuted
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                }
            }
        }

        contentItem: Components.FilePicker {
            id: picker
            fontFamily: root.fontFamily
            selectFolders: true
            implicitWidth: 300
            implicitHeight: 280
        }

        footer: DialogFooter {
            confirmLabel: "Select this folder"
            onCancelClicked: dialog.reject()
            onConfirmClicked: dialog.accept()
        }
    }

    FolderPickerDialog {
        id: uploadStartFolderDialog
        dialogTitle: "Upload start folder"
        onConfirmed: function (path) { if (root.service) root.service.setUploadStartPath(path) }
    }

    FolderPickerDialog {
        id: downloadFolderDialog
        dialogTitle: "Download folder"
        onConfirmed: function (path) { if (root.service) root.service.setDownloadPath(path) }
    }
}
