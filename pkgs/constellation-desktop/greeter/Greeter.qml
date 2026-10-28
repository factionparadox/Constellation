// Constellation's login screen: the clock, the date in Russian and English, and a card with
// your initial, your name and the password field. Pure QtQuick: shell.qml connects it to
// greetd, so the same screen can be previewed without logging anyone in.
import QtQuick

Item {
    id: greeter

    property string userName: ""
    property string fullName: ""
    property int userCount: 1
    property bool busy: false
    property string errorText: ""
    property string infoText: ""
    property bool showCard: true            // false on second screens: the sky and clock only

    signal submit(string password)
    signal nextUser()
    signal previousUser()
    signal power(string action)             // "suspend", "reboot", "poweroff"

    readonly property real u: Math.min(height / 1080, width / 1440) * 1.35
    readonly property color ivory: "#eef1fb"
    readonly property color gold: "#e0b868"
    readonly property color mist: "#9fb0d8"
    readonly property string sans: "Inter"
    readonly property string icons: "Material Symbols Rounded"

    function shake() { shakeAnim.restart(); }
    function clearPassword() { password.text = ""; password.forceActiveFocus(); }

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: greeter.now = new Date() }

    Sky { anchors.fill: parent }

    // ---------------------------------------------------------------- clock and date
    Column {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.14
        spacing: 6 * greeter.u
        opacity: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(greeter.now, "HH:mm")
            color: greeter.ivory
            font { family: greeter.sans; pixelSize: 104 * greeter.u; weight: Font.Light; letterSpacing: -2 * greeter.u }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property string ru: Qt.locale("ru_RU").toString(greeter.now, "dddd, d MMMM")
            text: ru.charAt(0).toUpperCase() + ru.slice(1)
            color: greeter.gold
            font { family: greeter.sans; pixelSize: 21 * greeter.u; weight: Font.Medium; letterSpacing: 0.5 * greeter.u }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale("en_GB").toString(greeter.now, "dddd d MMMM")
            color: greeter.mist
            font { family: greeter.sans; pixelSize: 14 * greeter.u; letterSpacing: 1 * greeter.u }
        }
    }

    // ---------------------------------------------------------------- the card
    Rectangle {
        id: card
        visible: greeter.showCard
        width: 360 * greeter.u
        height: cardColumn.implicitHeight + 64 * greeter.u
        anchors.horizontalCenter: parent.horizontalCenter
        property real lift: 24 * greeter.u
        y: parent.height * 0.42 + lift
        radius: 28 * greeter.u
        color: Qt.rgba(0.05, 0.09, 0.22, 0.55)
        border { width: 1; color: Qt.rgba(0.88, 0.72, 0.41, 0.28) }
        opacity: 0
        transform: Translate { id: shakeX }

        Column {
            id: cardColumn
            anchors { top: parent.top; topMargin: 34 * greeter.u; horizontalCenter: parent.horizontalCenter }
            spacing: 16 * greeter.u

            // Your initial in a gold ring.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96 * greeter.u; height: width; radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#f6dfa8" }
                    GradientStop { position: 1.0; color: "#b3843a" }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 6 * greeter.u; height: width; radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1d3478" }
                        GradientStop { position: 1.0; color: "#0b1638" }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: (greeter.fullName || greeter.userName || "?").charAt(0).toUpperCase()
                        color: greeter.ivory
                        font { family: greeter.sans; pixelSize: 40 * greeter.u; weight: Font.DemiBold }
                    }
                }
            }

            // Your name (with arrows to choose another account, if there is one).
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10 * greeter.u
                IconButton {
                    visible: greeter.userCount > 1
                    icon: "chevron_left"; size: 30 * greeter.u
                    onClicked: greeter.previousUser()
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2 * greeter.u
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: greeter.fullName || greeter.userName
                        color: greeter.ivory
                        font { family: greeter.sans; pixelSize: 23 * greeter.u; weight: Font.DemiBold }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: greeter.fullName !== "" && greeter.fullName !== greeter.userName
                        text: greeter.userName
                        color: greeter.mist
                        font { family: greeter.sans; pixelSize: 13 * greeter.u }
                    }
                }
                IconButton {
                    visible: greeter.userCount > 1
                    icon: "chevron_right"; size: 30 * greeter.u
                    onClicked: greeter.nextUser()
                }
            }

            // The password field, with a gold button that becomes a spinner while checking.
            Rectangle {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                width: 288 * greeter.u; height: 50 * greeter.u; radius: height / 2
                color: Qt.rgba(1, 1, 1, password.activeFocus ? 0.09 : 0.06)
                border { width: 1; color: password.activeFocus ? Qt.rgba(0.88, 0.72, 0.41, 0.7) : Qt.rgba(1, 1, 1, 0.14) }
                Behavior on border.color { ColorAnimation { duration: 180 } }

                TextInput {
                    id: password
                    anchors { left: parent.left; leftMargin: 22 * greeter.u; right: go.left; rightMargin: 10 * greeter.u; verticalCenter: parent.verticalCenter }
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: greeter.ivory
                    selectionColor: Qt.rgba(0.88, 0.72, 0.41, 0.5)
                    font { family: greeter.sans; pixelSize: 18 * greeter.u; letterSpacing: 2 * greeter.u }
                    focus: true
                    enabled: !greeter.busy
                    clip: true
                    onAccepted: if (text !== "") greeter.submit(text)
                    Keys.onEscapePressed: text = ""
                    Keys.onUpPressed: greeter.previousUser()
                    Keys.onDownPressed: greeter.nextUser()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: password.text === ""
                        text: "Пароль"
                        color: Qt.rgba(0.87, 0.9, 0.98, 0.38)
                        font { family: greeter.sans; pixelSize: 17 * greeter.u }
                    }
                }

                Rectangle {
                    id: go
                    anchors { right: parent.right; rightMargin: 5 * greeter.u; verticalCenter: parent.verticalCenter }
                    width: 40 * greeter.u; height: width; radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: goArea.containsMouse ? "#fbe7b5" : "#f0d391" }
                        GradientStop { position: 1.0; color: goArea.containsMouse ? "#c89a4c" : "#b3843a" }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: greeter.busy ? "progress_activity" : "arrow_forward"
                        color: "#14204a"
                        font { family: greeter.icons; pixelSize: 22 * greeter.u }
                        RotationAnimation on rotation { running: greeter.busy; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
                        onTextChanged: if (!greeter.busy) rotation = 0
                    }
                    MouseArea {
                        id: goArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (password.text !== "" && !greeter.busy) greeter.submit(password.text)
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: field.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: greeter.errorText || greeter.infoText
                visible: text !== ""
                color: greeter.errorText ? "#ff9d92" : greeter.mist
                font { family: greeter.sans; pixelSize: 13.5 * greeter.u }
            }
        }

        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: shakeX; property: "x"; to: -14 * greeter.u; duration: 60 }
            NumberAnimation { target: shakeX; property: "x"; to: 12 * greeter.u; duration: 80 }
            NumberAnimation { target: shakeX; property: "x"; to: -8 * greeter.u; duration: 80 }
            NumberAnimation { target: shakeX; property: "x"; to: 5 * greeter.u; duration: 70 }
            NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 60 }
        }
    }

    // ---------------------------------------------------------------- the bottom edge
    Item {
        id: footer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 34 * greeter.u }
        height: 48 * greeter.u
        opacity: 0

        Column {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            spacing: 2 * greeter.u
            Text {
                text: "Созвездие"
                color: greeter.ivory
                font { family: greeter.sans; pixelSize: 19 * greeter.u; weight: Font.DemiBold }
            }
            Text {
                text: "CONSTELLATION"
                color: greeter.gold
                font { family: greeter.sans; pixelSize: 10 * greeter.u; weight: Font.DemiBold; letterSpacing: 4 * greeter.u }
            }
        }

        Row {
            anchors.centerIn: parent
            visible: greeter.showCard
            spacing: 8 * greeter.u
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "keyboard"
                color: greeter.mist
                font { family: greeter.icons; pixelSize: 18 * greeter.u }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Alt + Shift  ·  EN / RU"
                color: greeter.mist
                font { family: greeter.sans; pixelSize: 13 * greeter.u; letterSpacing: 0.5 * greeter.u }
            }
        }

        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: greeter.showCard
            spacing: 10 * greeter.u
            IconButton { icon: "bedtime"; label: "Сон · Suspend"; onClicked: greeter.power("suspend") }
            IconButton { icon: "restart_alt"; label: "Перезагрузка · Restart"; onClicked: greeter.power("reboot") }
            IconButton { icon: "power_settings_new"; label: "Выключение · Shut down"; onClicked: greeter.power("poweroff") }
        }
    }

    // ---------------------------------------------------------------- arrival
    ParallelAnimation {
        running: true
        NumberAnimation { target: clock; property: "opacity"; to: 1; duration: 900; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 180 }
            ParallelAnimation {
                NumberAnimation { target: card; property: "opacity"; to: 1; duration: 700; easing.type: Easing.OutCubic }
                NumberAnimation { target: card; property: "lift"; to: 0; duration: 700; easing.type: Easing.OutCubic }
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 450 }
            NumberAnimation { target: footer; property: "opacity"; to: 1; duration: 700 }
        }
    }

    // A round icon button with an optional label that appears above it on hover.
    component IconButton: Item {
        id: btn
        property string icon
        property string label: ""
        property real size: 44 * greeter.u
        signal clicked()
        width: size; height: size
        Rectangle {
            anchors.fill: parent; radius: width / 2
            color: Qt.rgba(1, 1, 1, area.containsMouse ? 0.12 : 0.0)
            border { width: btn.label ? 1 : 0; color: Qt.rgba(1, 1, 1, area.containsMouse ? 0.25 : 0.12) }
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Text {
            anchors.centerIn: parent
            text: btn.icon
            color: area.containsMouse ? greeter.gold : greeter.ivory
            font { family: greeter.icons; pixelSize: btn.size * 0.5 }
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Text {
            visible: btn.label !== "" && area.containsMouse
            anchors { bottom: parent.top; bottomMargin: 8 * greeter.u; horizontalCenter: parent.horizontalCenter }
            text: btn.label
            color: greeter.ivory
            font { family: greeter.sans; pixelSize: 12 * greeter.u }
        }
        MouseArea {
            id: area
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
