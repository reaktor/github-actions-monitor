import "./moment.js" as Moment
import QtQuick 2.15
import QtQuick.Controls 1.0
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

Window {
    id: app

    property var targetPipelines
    property var pipelineStatuses
    property int prCount
    property var lastUpdateDate
    property string currentTimeOdd: ""
    property string currentTimeEven: ""
    property int refreshIntervalSeconds: 16
    property string targetRepository
    property string targetBranch
    property string githubToken
    property int numColumns: 3
    property int numRows: pipelineStatuses ? Math.ceil(pipelineStatuses.length / numColumns) : 1

    function difftime(dateStr) {
        const prev = Qt.moment(new Date(dateStr));
        const duration = Qt.moment.duration(prev.diff(new Date()));
        return `${duration.humanize()} ago `;
    }

    function httpGet(url) {
        return new Promise((resolve, reject) => {
            var xhr = new XMLHttpRequest();
            xhr.timeout = 15000;
            xhr.open("GET", url, true);
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE)
                    return ;

                if (xhr.status && xhr.status === 200)
                    resolve(xhr.responseText);
                else
                    reject(xhr.status, xhr.responseText);
            };
            xhr.setRequestHeader("X-GitHub-Api-Version", "2022-11-28");
            xhr.setRequestHeader("Authorization", `Bearer ${app.githubToken}`);
            xhr.send();
        });
    }

    function refreshPRCount() {
        httpGet(`https://api.github.com/repos/${app.targetRepository}/pulls`).then((response) => {
            app.prCount = JSON.parse(response).length;
        });
    }

    function initialLoad() {
        httpGet(`https://api.github.com/repos/${app.targetRepository}/actions/workflows`).then((response) => {
            app.targetPipelines = JSON.parse(response).workflows.filter((wf) => {
                return wf.state === "active";
            }).map((wf) => {
                return {
                    "id": wf.id,
                    "name": wf.name,
                    "status": "",
                    "lastActor": "",
                    "timestamp": 0
                };
            });
        }).catch((e) => {
            return console.error(e);
        });
    }

    function refresh() {
        refreshPRCount();
        const workflowRequests = targetPipelines.map((pl) => {
            return httpGet(`https://api.github.com/repos/${app.targetRepository}/actions/workflows/${pl.id}/runs?branch=${app.targetBranch}`);
        });
        Promise.all(workflowRequests).then((reqs) => {
            app.pipelineStatuses = reqs.map(JSON.parse).filter((r) => {
                return r.workflow_runs && r.workflow_runs.length > 0;
            }).map((r) => {
                return r.workflow_runs[0];
            }).map((run) => {
                return {
                    "id": run.workflow_id,
                    "name": run.name,
                    "status": run.conclusion,
                    "user": run.actor.login,
                    "timestamp": run.updated_at
                };
            });
        }).catch((e) => {
            return console.error(e);
        });
        app.lastUpdateDate = new Date();
    }

    width: 1280
    height: 720
    color: "#071436"
    onGithubTokenChanged: initialLoad()
    onTargetPipelinesChanged: targetPipelines && refresh()
    Component.onCompleted: {
        httpGet("./config.json").then((fileContent) => {
            const cfg = JSON.parse(fileContent);
            app.targetRepository = cfg.repository;
            app.githubToken = cfg.token;
            app.targetBranch = cfg.branch;
            if (typeof cfg.numColumns === "number")
                app.numColumns = cfg.numColumns;

            if (cfg.fullscreen)
                showFullScreen();

        }).catch((e) => {
            return console.error(e);
        });
    }

    Timer {
        interval: 1000 * app.refreshIntervalSeconds
        repeat: true
        running: true
        onTriggered: app.refresh()
    }

    Timer {
        property int i: 0

        interval: 500
        repeat: true
        running: true
        onTriggered: {
            if (i === 0)
                currentTimeEven = `${Qt.moment().format('HH:mm:ss')}`;
            else if (i === 1 || i === 3)
                clockOddEven.odd = !clockOddEven.odd;
            else if (i === 2)
                currentTimeOdd = `${Qt.moment().format('HH:mm:ss')}`;
            i = (i + 1) % 4;
        }
    }

    Item {
        id: container

        width: parent.width * 0.95
        height: parent.height * 0.95
        anchors.centerIn: parent

        Item {
            id: header

            width: parent.width - 20
            height: parent.height * 0.125
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                id: headerText

                color: "white"
                text: `<b>${app.targetBranch}</b> branch`
                font.pointSize: 60
                textFormat: Text.StyledText
            }

            ColumnLayout {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 10
                spacing: 1

                Rectangle {
                    id: clockOddEven

                    property bool odd: true

                    color: "transparent"
                    Layout.alignment: Qt.AlignRight
                    Layout.preferredHeight: childrenRect.height
                    Layout.preferredWidth: childrenRect.width
                    states: [
                        State {
                            when: clockOddEven.odd

                            PropertyChanges {
                                target: oddElement
                                opacity: 1
                            }

                            PropertyChanges {
                                target: evenElement
                                opacity: 0
                            }

                        },
                        State {
                            when: !clockOddEven.odd

                            PropertyChanges {
                                target: oddElement
                                opacity: 0
                            }

                            PropertyChanges {
                                target: evenElement
                                opacity: 1
                            }

                        }
                    ]
                    transitions: [
                        Transition {
                            NumberAnimation {
                                target: oddElement
                                properties: "opacity"
                                duration: 400
                                easing.type: Easing.OutInQuad
                            }

                            NumberAnimation {
                                target: evenElement
                                properties: "opacity"
                                duration: 400
                                easing.type: Easing.OutInQuad
                            }

                        }
                    ]

                    Text {
                        id: evenElement

                        color: "white"
                        text: currentTimeEven
                        font.pointSize: 20
                        textFormat: Text.StyledText
                        font.family: "Courier New,courier"
                        font.bold: true
                    }

                    Text {
                        id: oddElement

                        opacity: 1
                        color: "white"
                        text: currentTimeOdd
                        font.pointSize: 20
                        textFormat: Text.StyledText
                        font.family: "Courier New,courier"
                        font.bold: true
                    }

                }

                Text {
                    id: prCounter

                    color: "white"
                    text: `<b>${app.prCount}</b> pull requests`
                    font.pointSize: 20
                    textFormat: Text.StyledText
                    Layout.alignment: Qt.AlignRight
                }

                Text {
                    id: updateTimestamp

                    color: "white"
                    text: `updated at <b>${Qt.moment(app.lastUpdateDate).format('HH:mm:ss')}</b>`
                    font.pointSize: 20
                    Layout.alignment: Qt.AlignRight
                }

            }

        }

        GridView {
            id: grid

            anchors.top: header.bottom
            width: parent.width
            height: parent.height - header.height
            model: app.pipelineStatuses
            cellWidth: parent.width / numColumns
            cellHeight: grid.height / numRows

            delegate: Item {
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    function pickColor(status) {
                        if (status === "success")
                            return "#afff94";

                        if (status.includes("failure"))
                            return "#ff7e75";

                        return "#fffbb3";
                    }

                    width: parent.width - 20
                    height: parent.height - 20
                    anchors.centerIn: parent
                    color: pickColor(modelData["status"])

                    Item {
                        width: parent.width * 0.9
                        height: parent.height * 0.9
                        anchors.centerIn: parent

                        Text {
                            id: name

                            font.pointSize: 24
                            font.bold: true
                            color: "black"
                            width: parent.width
                            text: modelData["name"]
                            elide: Text.ElideRight
                        }

                        Text {
                            id: statusText

                            font.pointSize: 22
                            anchors.top: name.bottom
                            color: "black"
                            text: modelData["status"]
                        }

                        Text {
                            id: actor

                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            font.pointSize: 20
                            color: "black"
                            text: modelData["user"]
                        }

                        Text {
                            id: time

                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            font.pointSize: 18
                            color: "black"
                            text: difftime(modelData["timestamp"])

                            Timer {
                                interval: 1000 * 60
                                repeat: true
                                running: true
                                triggeredOnStart: true
                                onTriggered: {
                                    time.text = app.difftime(modelData["timestamp"]);
                                }
                            }

                        }

                    }

                }

            }

        }

    }

}
