// The night sky behind the login screen: the boot menu's enamel blue, a twinkling
// starfield, Leo in gold (the stars of the Fabergé Constellation Egg) and, now and then,
// a shooting star.
import QtQuick

Item {
    id: sky
    // Everything is laid out for a 1080-pixel-high screen and scaled to the real one.
    readonly property real u: height / 1080
    readonly property color gold: "#e0b868"
    readonly property color starlight: "#dce6ff"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#162a68" }
            GradientStop { position: 1.0; color: "#04091c" }
        }
    }

    // A soft glow behind the login card.
    Canvas {
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2, cy = height * 0.58, r = Math.max(width, height) * 0.45;
            const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
            g.addColorStop(0, Qt.rgba(0.32, 0.46, 0.92, 0.28));
            g.addColorStop(1, Qt.rgba(0.32, 0.46, 0.92, 0));
            ctx.fillStyle = g;
            ctx.fillRect(0, 0, width, height);
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    // The same seeded starfield every time (1917, the egg's year).
    function rng(seed) {
        let a = seed >>> 0;
        return function () {
            a = (a + 0x6D2B79F5) >>> 0;
            let t = a;
            t = Math.imul(t ^ (t >>> 15), t | 1);
            t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        };
    }
    readonly property var stars: {
        const r = rng(1917), list = [];
        for (let i = 0; i < 180; i++)
            list.push({ x: r(), y: r(), size: [1.2, 1.6, 2, 2, 2.6][Math.floor(r() * 5)],
                        base: 0.18 + r() * 0.45, period: 2200 + r() * 4800, delay: r() * 4000 });
        return list;
    }

    Repeater {
        model: sky.stars
        Rectangle {
            required property var modelData
            x: modelData.x * sky.width
            y: modelData.y * sky.height
            width: modelData.size * sky.u
            height: width
            radius: width / 2
            color: sky.starlight
            opacity: modelData.base
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                PauseAnimation { duration: modelData.delay }
                NumberAnimation { to: modelData.base * 0.25; duration: modelData.period / 2; easing.type: Easing.InOutSine }
                NumberAnimation { to: modelData.base; duration: modelData.period / 2; easing.type: Easing.InOutSine }
            }
        }
    }

    // Leo, upper right, drawn as on the boot menu: offsets in 1920x1080 pixels, from each
    // star's right ascension and declination.
    readonly property var leo: [
        { name: "Regulus",  dx: 165.3, dy: 119.5, mag: 1.4 },
        { name: "Eta",      dx: 169.5, dy: 38.1,  mag: 3.5 },
        { name: "Algieba",  dx: 116.8, dy: -14.3, mag: 2.0 },
        { name: "Adhafera", dx: 130.5, dy: -75.1, mag: 3.4 },
        { name: "Rasalas",  dx: 230.3, dy: -119.2, mag: 3.9 },
        { name: "Algenubi", dx: 259.0, dy: -81.1, mag: 3.0 },
        { name: "Zosma",    dx: -108.7, dy: -25.8, mag: 2.6 },
        { name: "Chertan",  dx: -109.2, dy: 60.7, mag: 3.3 },
        { name: "Denebola", dx: -254.5, dy: 75.3, mag: 2.1 }
    ]
    readonly property var leoLines: [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [2, 6], [6, 8], [8, 7], [7, 0], [6, 7]]
    // Anchored to the right edge (so it clears the clock on narrower screens), a little
    // further in and higher than on the boot menu, whose menu sits lower down.
    readonly property real leoX: width - 0.17 * 1920 * u
    readonly property real leoY: 0.2 * height

    Canvas {
        id: leoLinesCanvas
        anchors.fill: parent
        opacity: 0.4
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = sky.gold;
            ctx.lineWidth = 1.6 * sky.u;
            for (const [a, b] of sky.leoLines) {
                const p = sky.leo[a], q = sky.leo[b];
                ctx.beginPath();
                ctx.moveTo(sky.leoX + p.dx * sky.u, sky.leoY + p.dy * sky.u);
                ctx.lineTo(sky.leoX + q.dx * sky.u, sky.leoY + q.dy * sky.u);
                ctx.stroke();
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Repeater {
        model: sky.leo
        Item {
            required property var modelData
            required property int index
            readonly property real r: (1.2 * (4.5 - modelData.mag) + 2) * sky.u
            x: sky.leoX + modelData.dx * sky.u
            y: sky.leoY + modelData.dy * sky.u
            // A halo of three soft rings, breathing slowly, around an ivory core.
            Repeater {
                model: [4.4, 3.0, 1.9]
                Rectangle {
                    required property real modelData
                    width: parent.r * 2 * modelData; height: width; radius: width / 2
                    x: -width / 2; y: -height / 2
                    color: sky.gold
                    opacity: 0.07
                }
            }
            Rectangle {
                width: parent.r * 2; height: width; radius: width / 2
                x: -width / 2; y: -height / 2
                color: "#ffeec8"
            }
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                PauseAnimation { duration: index * 450 }
                NumberAnimation { to: 0.72; duration: 2600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 2600; easing.type: Easing.InOutSine }
            }
        }
    }

    // A shooting star every so often, from the upper left, gone in under a second.
    Rectangle {
        id: meteor
        width: 140 * sky.u; height: 2 * sky.u; radius: height / 2
        rotation: 24
        transformOrigin: Item.Right
        opacity: 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: "#fff6dc" }
        }
        property real startX: 0
        property real startY: 0
        ParallelAnimation {
            id: fall
            NumberAnimation { target: meteor; property: "x"; from: meteor.startX; to: meteor.startX + 420 * sky.u; duration: 900; easing.type: Easing.InQuad }
            NumberAnimation { target: meteor; property: "y"; from: meteor.startY; to: meteor.startY + 187 * sky.u; duration: 900; easing.type: Easing.InQuad }
            SequentialAnimation {
                NumberAnimation { target: meteor; property: "opacity"; from: 0; to: 0.9; duration: 200 }
                NumberAnimation { target: meteor; property: "opacity"; to: 0; duration: 700 }
            }
        }
        Timer {
            interval: 14000; repeat: true; running: true
            onTriggered: {
                meteor.startX = sky.width * (0.05 + Math.random() * 0.4);
                meteor.startY = sky.height * (0.04 + Math.random() * 0.22);
                interval = 11000 + Math.random() * 12000;
                fall.start();
            }
        }
    }
}
