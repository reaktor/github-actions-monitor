QML_RUNNER ?= qml

run:
	QML_XHR_ALLOW_FILE_READ=1 $(QML_RUNNER) App.qml
