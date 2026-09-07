.pragma library

var translations = {
    en: {
        settingsTitle: "Settings",
        signOut: "Sign out",
        settingsToolTip: "Settings",
        newFolderToolTip: "New folder",
        uploadToolTip: "Upload",
        refreshToolTip: "Refresh",
        emptyFolder: "This folder is empty.",
        dropToUpload: "Drop to upload",
        transfersLabel: "Transfers",
        downloadFolder: "Download folder",
        downloadDefault: "~/Downloads (default)",
        uploadStartFolder: "Upload start folder",
        uploadStartDefault: "Home folder (default)",
        barPosition: "Bar position",
        positionLeft: "Left",
        positionCenter: "Center",
        positionRight: "Right",
        languageLabel: "Language",
        cancel: "Cancel",
        newFolderTitle: "New folder",
        create: "Create",
        rename: "Rename",
        deleteItemTitle: "Delete item",
        deleteAction: "Delete",
        uploadFilesTitle: "Upload files",
        selectThisFolder: "Select this folder",
        connectAccount: "Connect your OneDrive account",
        personalAccountsOnly: "Personal Microsoft accounts only",
        signIn: "Sign in",
        trackedFolders: "Tracked folders",
        addTrackedFolder: "Add folder",
        noTrackedFolders: "No folders tracked yet."
    },
    es: {
        settingsTitle: "Ajustes",
        signOut: "Cerrar sesión",
        settingsToolTip: "Ajustes",
        newFolderToolTip: "Nueva carpeta",
        uploadToolTip: "Subir",
        refreshToolTip: "Actualizar",
        emptyFolder: "Esta carpeta está vacía.",
        dropToUpload: "Soltá para subir",
        transfersLabel: "Transferencias",
        downloadFolder: "Carpeta de descargas",
        downloadDefault: "~/Downloads (por defecto)",
        uploadStartFolder: "Carpeta inicial de subida",
        uploadStartDefault: "Carpeta de inicio (por defecto)",
        barPosition: "Posición en la barra",
        positionLeft: "Izquierda",
        positionCenter: "Centro",
        positionRight: "Derecha",
        languageLabel: "Idioma",
        cancel: "Cancelar",
        newFolderTitle: "Nueva carpeta",
        create: "Crear",
        rename: "Renombrar",
        deleteItemTitle: "Eliminar elemento",
        deleteAction: "Eliminar",
        uploadFilesTitle: "Subir archivos",
        selectThisFolder: "Seleccionar esta carpeta",
        connectAccount: "Conectá tu cuenta de OneDrive",
        personalAccountsOnly: "Solo cuentas personales de Microsoft",
        signIn: "Iniciar sesión",
        trackedFolders: "Carpetas trackeadas",
        addTrackedFolder: "Agregar carpeta",
        noTrackedFolders: "Todavía no hay carpetas trackeadas."
    }
}

function t(lang, key) {
    var table = translations[lang] || translations.en
    var value = table[key]
    return value !== undefined ? value : translations.en[key]
}

function deleteConfirmMessage(lang, name) {
    if (lang === "es") return "¿Eliminar “" + name + "”? No se puede deshacer."
    return "Delete “" + name + "”? This can't be undone."
}

function uploadCountLabel(lang, count) {
    if (lang === "es") return "Subir (" + count + ")"
    return "Upload (" + count + ")"
}
