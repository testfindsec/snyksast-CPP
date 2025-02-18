// SPDX-License-Identifier: Apache-2.0
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import QtQml 2.15
import xstudio.qml.bookmarks 1.0
import QtQml.Models 2.14
import QtQuick.Dialogs 1.3 //for ColorDialog
import QtGraphicalEffects 1.15 //for RadialGradient
import QtQuick.Controls.Styles 1.4 //for TextFieldStyle
import QuickFuture 1.0
import QuickPromise 1.0

import xStudio 1.1

XsWindow { id: shotgunBrowser
    centerOnOpen: true
    onTop: false

    property var projectModel: null
    property alias projectCurrentIndex: leftDiv.projectCurrentIndex
    property alias liveLinkProjectChange: leftDiv.liveLinkProjectChange

    property var authorModel: null
    property var siteModel: null
    property var noteTypeModel: null
    property var departmentModel: null
    property var playlistTypeModel: null
    property var productionStatusModel: null
    property var pipelineStatusModel: null
    property var boolModel: null
    property var resultLimitModel: null
    property var orderByModel: null
    property var primaryLocationModel: null
    property var lookbackModel: null
    property var stepModel: null
    property var onDiskModel: null
    property var twigTypeCodeModel: null
    property var shotStatusModel: null

    property var sequenceModel: null
    property var sequenceModelFunc: null

    property var sequenceTreeModel: null
    property var sequenceTreeModelFunc: null

    property var shotModel: null
    property var shotModelFunc: null

    property var shotSearchFilterModel: null
    property var shotSearchFilterModelFunc: null

    property var playlistModel: null
    property var playlistModelFunc: null

    property var shotResultsModel: null
    property var playlistResultsModel: null
    property var editResultsModel: null
    property var referenceResultsModel: null
    property var noteResultsModel: null
    property var mediaActionResultsModel: null

    property var shotPresetsModel: null
    property var playlistPresetsModel: null
    property var editPresetsModel: null
    property var referencePresetsModel: null
    property var notePresetsModel: null
    property var mediaActionPresetsModel: null

    property var shotFilterModel: null
    property var playlistFilterModel: null
    property var editFilterModel: null
    property var referenceFilterModel: null
    property var noteFilterModel: null
    property var mediaActionFilterModel: null

    property var mergeQueriesFunc: null
    property var executeQueryFunc: null
    property var authenticateFunc: null

    property var preferredVisual: null
    property var preferredAudio: null
    property var flagText: null
    property var flagColour: null

    property var loadPlaylists: dummyFunction
    property var addShotsToNewPlaylist: dummyFunction
    property var addAndCompareShotsToPlaylist: dummyFunction
    property var addShotsToPlaylist: dummyFunction

    property alias presetListView: leftDiv.searchPresetsView
    property bool executeQueryOnCategorySwitch: true
    property bool categorySwitchedOnClick: false

    signal showRelatedVersions()

    title: "Shot Browser"

    XsWindowStateSaver
    {
        windowObj: shotgunBrowser
        windowName: "shotgun_browser"
    }

    width: 840
    minimumWidth: leftDiv.isCollapsed? minimumLeftSplitViewWidth*1.4 : 840
    height: 480
    minimumHeight: 480
    property real oldWidth: minimumWidth
    property real oldHeight: 480
    property real minimumLeftSplitViewWidth: 350
    property real minimumRightSplitViewWidth: minimumLeftSplitViewWidth*1.25
    property real minimumSplitViewHeight: 120
    onWidthChanged: {
        if((width-leftDiv.width) < minimumLeftSplitViewWidth)
        leftDiv.SplitView.preferredWidth = leftDiv.width - (oldWidth-width)
        oldWidth = width
    }
    onHeightChanged: {
        if((height-leftDiv.height) < minimumSplitViewHeight)
        leftDiv.SplitView.preferredHeight = leftDiv.height - (oldHeight-height)
        oldHeight = height
    }

    property real framePadding: 6
    property real frameWidth: 1
    property real frameRadius: 2
    property color frameColor: itemColorNormal

    property real itemHeight: 22*1.2
    property real itemSpacing: 2
    property color itemColorActive: palette.highlight
    property color itemColorNormal: palette.base

    property color textColorActive: "white"
    property color textColorNormal: "light grey"
    property real fontSize: XsStyle.menuFontSize
    property string fontFamily: XsStyle.menuFontFamily

    property alias currentCategory: leftDiv.currentCategory

    Shortcut {
        context:  Qt.WindowShortcut
        sequence: "Ctrl+V"
        onActivated: leftDiv.presetsDiv.onMenuAction("PASTE")
    }
    Shortcut {
        context:  Qt.WindowShortcut
        sequence: "Ctrl+C"
        onActivated: leftDiv.presetsDiv.onMenuAction("COPY")
    }
    Shortcut {
        context:  Qt.WindowShortcut
        sequence: "Ctrl+Z"
        onActivated: data_source.undo()
    }
    Shortcut {
        context:  Qt.WindowShortcut
        sequence: "Ctrl+Shift+Z"
        onActivated: data_source.redo()
    }

    Shortcut {
        context:  Qt.WindowShortcut
        sequence: "V"
        onActivated: showRelatedVersions()
    }

    Shortcut {
        context:  Qt.WindowShortcut
        sequence: "S"
        onActivated: {
            if (visible) {
                hide()
            } else {
                show()
                requestActivate()
            }
        }
    }

    onVisibleChanged: {
        if (!visible) {
            // ensure keyboard events are returned to the viewport
            sessionWidget.playerWidget.viewport.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        currentCategoryUpdate()
    }

    function executeMediaActionQuery(action_name, media_metadata, func) {
        // find index of MediaAction..
        let mai = mediaActionPresetsModel.search(action_name)
        let pid = mediaActionPresetsModel.getProjectId(media_metadata)

        // there is a possible race here with populating the project caches..
        data_source.liveLinkMetadata = media_metadata

        // console.log(action_name, projectCurrentIndex, projectModel, projectModel.count, pid)

        if(mai !== -1 && pid != -1) {
            // we have a selection to iterate over..
            let query = mergeQueriesFunc(mediaActionPresetsModel.get(mai, "jsonRole"), mediaActionFilterModel.get(0, "jsonRole"))

            // we need to refresh livelinks for each item..
            query = mediaActionPresetsModel.applyLiveLink(query, media_metadata)

            Future.promise(
                executeQueryFunc("Menu Setup", pid, query, false)
            ).then(function(json_string) {
                try {
                    var data = JSON.parse(json_string)
                       // should be array of uuids..
                    func(data)
                } catch(err) {
                    console.log(err)
                }
            },
            function() {
            })
        }
    }

    function createPresetType(mode) {
        if(mode == "Live Notes") {
            // check it doesn't already exist.
            let ind = notePresetsModel.search("---- Live Notes ----")
            if(ind == -1) {
                notePresetsModel.insert(
                    notePresetsModel.rowCount(),
                    notePresetsModel.index(notePresetsModel.rowCount(),0),
                    {
                        "expanded": false,
                        "loaded": false,
                        "name": "---- Live Notes ----",
                        "queries": [
                            {
                                "enabled": true,
                                "livelink": true,
                                "term": "Shot",
                                "value": ""
                            },
                            {
                                "enabled": true,
                                "livelink": true,
                                "term": "Twig Name",
                                "value": ""
                            },
                            {
                                "enabled": true,
                                "livelink": true,
                                "term": "Version Name",
                                "value": ""
                            },
                            {
                                "enabled": false,
                                "livelink": true,
                                "term": "Pipeline Step",
                                "value": ""
                            },
                            {
                                "enabled": false,
                                "term": "Note Type",
                                "value": "Client"
                            },
                            {
                                "enabled": true,
                                "term": "Flag Media",
                                "value": "Orange"
                            }
                        ]
                    }
                )
                ind = notePresetsModel.rowCount()-1
            }
            leftDiv.searchPresetsView.currentIndex = ind
        } else if(mode == "Live All Versions") {
            let ind = shotPresetsModel.search("---- Live Versions (All) ----")
            if(ind == -1) {
                shotPresetsModel.insert(
                    shotPresetsModel.rowCount(),
                    shotPresetsModel.index(shotPresetsModel.rowCount(),0),
                    {
                        "expanded": false,
                        "loaded": false,
                        "name": "---- Live Versions (All) ----",
                        "queries": [
                            {
                                "enabled": true,
                                "term": "Shot",
                                "livelink": true,
                                "value": ""
                            },
                            {
                                "enabled": true,
                                "term": "Latest Version",
                                "value": "True"
                            },
                            {
                              "enabled": true,
                              "livelink": false,
                              "term": "Twig Type",
                              "value": "scan"
                            },
                            {
                              "enabled": true,
                              "livelink": false,
                              "term": "Twig Type",
                              "value": "render/element"
                            },
                            {
                              "enabled": true,
                              "livelink": false,
                              "term": "Twig Type",
                              "value": "render/out"
                            },
                            {
                              "enabled": true,
                              "livelink": false,
                              "term": "Twig Type",
                              "value": "render/playblast"
                            },
                            {
                              "enabled": true,
                              "livelink": false,
                              "term": "Twig Type",
                              "value": "render/playblast/working"
                            },
                            {
                                "enabled": true,
                                "term": "Flag Media",
                                "value": "Orange"
                            }
                        ]
                    }
                )
                ind = shotPresetsModel.rowCount()-1
            }
            leftDiv.searchPresetsView.currentIndex = ind
        } else if(mode == "Live Related Versions") {
            let ind = shotPresetsModel.search("---- Live Versions (Related) ----")
            if(ind == -1) {
                shotPresetsModel.insert(
                    shotPresetsModel.rowCount(),
                    shotPresetsModel.index(shotPresetsModel.rowCount(),0),
                    {
                        "expanded": false,
                        "loaded": false,
                        "name": "---- Live Versions (Related) ----",
                        "queries": [
                            {
                                "enabled": true,
                                "livelink": true,
                                "term": "Shot",
                                "value": ""
                            },
                            {
                                "enabled": true,
                                "livelink": true,
                                "term": "Pipeline Step",
                                "value": ""
                            },
                            {
                                "enabled": true,
                                "livelink": true,
                                "term": "Twig Type",
                                "value": ""
                            },
                            {
                                "enabled": true,
                                "livelink": true,
                                "term": "Twig Name",
                                "value": ""
                            },
                            {
                                "enabled": false,
                                "term": "Latest Version",
                                "value": "True"
                            },
                            {
                                "enabled": false,
                                "term": "Sent To Client",
                                "value": "True"
                            },
                            {
                                "enabled": true,
                                "term": "Flag Media",
                                "value": "Orange"
                            }
                        ]
                    }
                )
                ind = shotPresetsModel.rowCount()-1
            }
            leftDiv.searchPresetsView.currentIndex = ind
        } else if(mode == "All Versions") {
            shotPresetsModel.insert(
                shotPresetsModel.rowCount(),
                shotPresetsModel.index(shotPresetsModel.rowCount(),0),
                {
                    "expanded": false,
                    "loaded": false,
                    "name": "All Versions",
                    "queries": [
                        {
                            "enabled": true,
                            "livelink": true,
                            "term": "Shot",
                            "value": ""
                        }
                    ]
                }
            )
            leftDiv.searchPresetsView.currentIndex = shotPresetsModel.rowCount()-1
        }
    }

    function updateLiveLink(media){
        if(visible && currentCategory && leftDiv.searchPresetsView.currentIndex != -1) {
            // check current preset has a live link field active.
            if(leftDiv.searchPresetsViewModel.hasActiveLiveLink) {
                leftDiv.executeQuery()
            }
        }
    }

    function currentCategoryUpdate() {

        if(currentCategory == "Shots")
        {
            leftDiv.presetSelectionModel.clearSelection()

            leftDiv.filterViewModel = shotFilterModel
            leftDiv.searchPresetsViewModel = shotPresetsModel
            rightDiv.searchResultsViewModel = shotResultsModel
        }
        else if(currentCategory == "Playlists")
        {
            leftDiv.presetSelectionModel.clearSelection()

            leftDiv.filterViewModel = playlistFilterModel
            leftDiv.searchPresetsViewModel = playlistPresetsModel
            rightDiv.searchResultsViewModel = playlistResultsModel
        }
        else if(currentCategory == "Edits")
        {
            leftDiv.presetSelectionModel.clearSelection()

            leftDiv.filterViewModel = editFilterModel
            leftDiv.searchPresetsViewModel = editPresetsModel
            rightDiv.searchResultsViewModel = editResultsModel
        }
        else if(currentCategory == "Reference")
        {
            leftDiv.presetSelectionModel.clearSelection()

            leftDiv.filterViewModel = referenceFilterModel
            leftDiv.searchPresetsViewModel = referencePresetsModel
            rightDiv.searchResultsViewModel = referenceResultsModel
        }
        else if(currentCategory == "Notes")
        {
            leftDiv.presetSelectionModel.clearSelection()

            leftDiv.filterViewModel = noteFilterModel
            leftDiv.searchPresetsViewModel = notePresetsModel
            rightDiv.searchResultsViewModel = noteResultsModel
        }
        else if(currentCategory == "Menu Setup")
        {
            leftDiv.presetSelectionModel.clearSelection()

            leftDiv.filterViewModel = mediaActionFilterModel
            leftDiv.searchPresetsViewModel = mediaActionPresetsModel
            rightDiv.searchResultsViewModel = mediaActionResultsModel
        }

        let found = false

        for(let i=0; i< leftDiv.presetsModel.count;i++){
            if(leftDiv.presetsModel.get(i, "loadedRole")) {
                if(categorySwitchedOnClick) executeQueryOnCategorySwitch = false
                if(leftDiv.searchPresetsView.currentIndex == i) leftDiv.searchPresetsView.currentIndex = -1
                leftDiv.searchPresetsView.currentIndex = i
                found = true
                break
            }
        }

        if(!found)
            leftDiv.searchPresetsView.currentIndex = -1

        categorySwitchedOnClick = false
        executeQueryOnCategorySwitch = true
    }

    onCurrentCategoryChanged: currentCategoryUpdate()

    Connections {
        target: leftDiv
        function onProjectChanged(project_id) {
            // reset models
            shotResultsModel.clear()
            playlistResultsModel.clear()
            editResultsModel.clear()
            referenceResultsModel.clear()
            noteResultsModel.clear()

            // set all preset loaded state to false.
            shotPresetsModel.clearLoaded()
            playlistPresetsModel.clearLoaded()
            editPresetsModel.clearLoaded()
            referencePresetsModel.clearLoaded()
            notePresetsModel.clearLoaded()
        }
    }

    function dummyFunction(id_list) {
        console.log(id_list)
    }

    function addShotsToPlaylistWrapper(id_list) {
        shotgunBrowser.addShotsToPlaylist(
            id_list,
            preferredVisual(currentCategory),
            preferredAudio(currentCategory),
            flagText(currentCategory),
            flagColour(currentCategory)
        )
    }

    function addShotsToNewPlaylistWrapper(id_list) {
        shotgunBrowser.addShotsToNewPlaylist(
            leftDiv.presetsModel.get(leftDiv.searchPresetsView.currentIndex, "nameRole"),
            id_list,
            preferredVisual(currentCategory),
            preferredAudio(currentCategory),
            flagText(currentCategory),
            flagColour(currentCategory)
        )
    }

    function addAndCompareShotsToPlaylistWrapper(id_list, mode) {
        shotgunBrowser.addAndCompareShotsToPlaylist(
            leftDiv.presetsModel.get(leftDiv.searchPresetsView.currentIndex, "nameRole"),
            id_list,
            mode,
            preferredVisual(currentCategory),
            preferredAudio(currentCategory),
            flagText(currentCategory),
            flagColour(currentCategory)
        )
    }


    XsSplitView { id: leftAndRightDivs
        anchors.fill: parent

        onResizingChanged: {
            if(!resizing) { leftDiv.SplitView.preferredWidth = leftDiv.width; rightDiv.SplitView.preferredWidth = rightDiv.width }
        }

        SBLeftPanel{ id: leftDiv
            projectModel: shotgunBrowser.projectModel
            projectCurrentIndex: shotgunBrowser.projectCurrentIndex

            authenticateFunc: shotgunBrowser.authenticateFunc

            authorModel: shotgunBrowser.authorModel

            sequenceModel: shotgunBrowser.sequenceModel
            sequenceModelFunc: shotgunBrowser.sequenceModelFunc

            sequenceTreeModel: shotgunBrowser.sequenceTreeModel
            sequenceTreeModelFunc: shotgunBrowser.sequenceTreeModelFunc

            shotModel: shotgunBrowser.shotModel
            shotModelFunc: shotgunBrowser.shotModelFunc

            shotSearchFilterModel: shotgunBrowser.shotSearchFilterModel
            shotSearchFilterModelFunc: shotgunBrowser.shotSearchFilterModelFunc

            playlistModel: shotgunBrowser.playlistModel
            playlistModelFunc: shotgunBrowser.playlistModelFunc

            siteModel: shotgunBrowser.siteModel
            noteTypeModel: shotgunBrowser.noteTypeModel
            departmentModel: shotgunBrowser.departmentModel
            playlistTypeModel: shotgunBrowser.playlistTypeModel
            productionStatusModel: shotgunBrowser.productionStatusModel
            pipelineStatusModel: shotgunBrowser.pipelineStatusModel

            primaryLocationModel: shotgunBrowser.primaryLocationModel
            orderByModel: shotgunBrowser.orderByModel
            resultLimitModel: shotgunBrowser.resultLimitModel
            boolModel: shotgunBrowser.boolModel
            lookbackModel: shotgunBrowser.lookbackModel
            stepModel: shotgunBrowser.stepModel
            onDiskModel: shotgunBrowser.onDiskModel
            twigTypeCodeModel: shotgunBrowser.twigTypeCodeModel
            shotStatusModel: shotgunBrowser.shotStatusModel

            shotPresetsModel: shotgunBrowser.shotPresetsModel
            playlistPresetsModel: shotgunBrowser.playlistPresetsModel
            editPresetsModel: shotgunBrowser.editPresetsModel
            referencePresetsModel: shotgunBrowser.referencePresetsModel
            notePresetsModel: shotgunBrowser.notePresetsModel
            mediaActionPresetsModel: shotgunBrowser.mediaActionPresetsModel

            shotFilterModel: shotgunBrowser.shotFilterModel
            playlistFilterModel: shotgunBrowser.playlistFilterModel
            editFilterModel: shotgunBrowser.editFilterModel
            referenceFilterModel: shotgunBrowser.referenceFilterModel
            noteFilterModel: shotgunBrowser.noteFilterModel
            mediaActionFilterModel: shotgunBrowser.mediaActionFilterModel

            executeQueryFunc: shotgunBrowser.executeQueryFunc
            mergeQueriesFunc: shotgunBrowser.mergeQueriesFunc

            pipelineStepFilterIndex: rightDiv.pipelineStepFilterIndex
            onDiskFilterIndex: rightDiv.onDiskFilterIndex

            onUndo: data_source.undo()
            onRedo: data_source.redo()
            onSnapshotGlobals: {
                let preset = ""
                if(currentCategory == "Shots")
                    preset = "shot_filter"
                else if(currentCategory == "Playlists")
                    preset = "playlist_filter"
                else if(currentCategory == "Edits")
                    preset = "edit_filter"
                else if(currentCategory == "Reference")
                    preset = "reference_filter"
                else if(currentCategory == "Notes")
                    preset = "note_filter"
                else if(currentCategory == "Menu Setup")
                    preset = "media_action_filter"

                data_source.snapshot(preset)
            }
            onSnapshotPresets: {
                let preset = ""
                if(currentCategory == "Shots")
                    preset = "shot"
                else if(currentCategory == "Playlists")
                    preset = "playlist"
                else if(currentCategory == "Edits")
                    preset = "edit"
                else if(currentCategory == "Reference")
                    preset = "reference"
                else if(currentCategory == "Notes")
                    preset = "note"
                else if(currentCategory == "Menu Setup")
                    preset = "media_action"

                data_source.snapshot(preset)
            }
        }

        SBRightPanel{ id: rightDiv
            currentPresetIndex: leftDiv.searchPresetsView.currentIndex

            loadPlaylists: shotgunBrowser.loadPlaylists
            addShotsToPlaylist: shotgunBrowser.addShotsToPlaylistWrapper
            addShotsToNewPlaylist: shotgunBrowser.addShotsToNewPlaylistWrapper
            addAndCompareShotsToPlaylist: shotgunBrowser.addAndCompareShotsToPlaylistWrapper

            Connections {
                target: shotgunBrowser
                function onShowRelatedVersions() {
                    rightDiv.popupMenuAction("Related Versions")
                }
            }
        }
    }
}