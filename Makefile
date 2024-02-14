QML_RUNNER ?= qmlscene

run:
	QML_XHR_ALLOW_FILE_READ=1 $(QML_RUNNER) App.qml
