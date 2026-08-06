/*
    Qubix OS compatibility override for Aurora's dark Plasma startup splash.

    SPDX-FileCopyrightText: 2014 Marco Martin <mart@kde.org>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    color: "black"

    property int stage

    // Fade the branded surface in once Plasma reaches its visual startup stage.
    onStageChanged: {
        if (stage == 2) {
            introAnimation.running = true;
        }
    }

    // Existing users may still select Aurora by ID; render only Qubix artwork there too.
    Item {
        id: content
        anchors.fill: parent
        opacity: 0

        Image {
            id: logo
            readonly property real size: Kirigami.Units.gridUnit * 8

            anchors.centerIn: parent
            asynchronous: true
            source: "file:///usr/share/pixmaps/qubixos-logo.svg"
            sourceSize.width: size
            sourceSize.height: size
        }
    }

    // Plasma owns the stage lifetime; this animation only controls presentation.
    OpacityAnimator {
        id: introAnimation
        running: false
        target: content
        from: 0
        to: 1
        duration: Kirigami.Units.veryLongDuration * 2
        easing.type: Easing.InOutQuad
    }
}
