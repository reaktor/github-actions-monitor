import "./moment.js" as Moment
import QtQuick 2.15
import QtQuick.Controls 1.0
import QtQuick.Window 2.15

Window {
    id: app

    property var targetPipelines
    property var pipelineStatuses
    property int prCount
    property var lastUpdateDate
    property int refreshIntervalSeconds: 16
    property string targetRepository
    property string targetBranch
    property string githubToken
    property int numColumns: 3
    property int numRows: pipelineStatuses ? Math.ceil(pipelineStatuses.length / numColumns) : 1

    width: 1280
    height: 720
    color: "#071436"

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

    onGithubTokenChanged: initialLoad()
    onTargetPipelinesChanged: targetPipelines && refresh()

    Component.onCompleted: {
        httpGet("./config.json").then((fileContent) => {
            const cfg = JSON.parse(fileContent);
            app.targetRepository = cfg.repository;
            app.githubToken = cfg.token;
            app.targetBranch = cfg.branch;
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
                text: `${app.targetBranch} branch`
                font.pointSize: 60
            }

            Text {
                id: prCounter

                color: "white"
                text: `${app.prCount} pull requests`
                font.pointSize: 20
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 10
            }

            Text {
                id: updateTimestamp

                color: "white"
                text: `updated at ${Qt.moment(app.lastUpdateDate).format('HH:mm:ss')}`
                font.pointSize: 20
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
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

                        if (status === "failure")
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
