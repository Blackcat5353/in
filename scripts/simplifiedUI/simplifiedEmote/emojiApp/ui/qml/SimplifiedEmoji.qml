//
//  SimplifiedEmoji.qml
//
//  Created by Milad Nazeri on 2019-08-03
//  Copyright 2019 High Fidelity, Inc.
//
//  Distributed under the Apache License, Version 2.0.
//  See the accompanying file LICENSE or http://www.apache.org/licenses/LICENSE-2.0.html
//

import QtQuick 2.12
import QtQuick.Controls 2.4
import QtGraphicalEffects 1.12
import stylesUit 1.0 as HifiStylesUit
import TabletScriptingInterface 1.0
import hifi.simplifiedUI.simplifiedControls 1.0 as SimplifiedControls
import hifi.simplifiedUI.simplifiedConstants 1.0 as SimplifiedConstants
import "../../resources/modules/emojiList.js" as EmojiList
import "../../resources/modules/customEmojiList.js" as CustomEmojiList

Rectangle {
    id: root
    color: simplifiedUI.colors.darkBackground
    anchors.fill: parent
    
    // Used for the indicator picture
    readonly property string emojiBaseURL: "../../resources/images/emojis/1024px/"
    readonly property string emoji52BaseURL: "../../resources/images/emojis/52px/"
    // Capture the selected code to handle which emoji to show
    property string currentCode: ""
    // if this is true, then hovering doesn't allow showing other icons
    property bool isSelected: false

    // Update the selected emoji image whenever the code property is changed.
    onCurrentCodeChanged: {
        mainEmojiImage.source = emojiBaseURL + currentCode;
    }

    SimplifiedConstants.SimplifiedConstants {
        id: simplifiedUI
    }

    focus: true

    ListModel {
        id: mainModel
    }

    ListModel {
        id: filteredModel
    }

    Component.onCompleted: {
        emojiSearchTextField.forceActiveFocus();
        EmojiList.emojiList
            .filter(emoji => {
                return emoji.mainCategory === "Smileys & Emotion" || 
                emoji.mainCategory === "People & Body" ||
                emoji.mainCategory === "Animals & Nature" ||
                emoji.mainCategory === "Food & Drink";
            })
            // Convert the filtered list to seed our QML Model used for our view
            .forEach(function(item, index){
                item.code = { utf: item.code[0] }
                item.keywords = { keywords: item.keywords }
                mainModel.append(item);
                filteredModel.append(item);
            });
        CustomEmojiList.customEmojiList
            .forEach(function(item, index){
                item.code = { utf: item.name }
                item.keywords = { keywords: item.keywords }
                mainModel.append(item);
                filteredModel.append(item);
            });
            
        root.currentCode = filteredModel.get(0).code.utf;
    }

    Rectangle {
        id: emojiIndicatorContainer
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 200
        clip: true
        color: simplifiedUI.colors.darkBackground

        Image {
            id: mainEmojiLowOpacity
            width: mainEmojiImage.width
            height: mainEmojiImage.height
            anchors.centerIn: parent
            source: mainEmojiImage.source
            opacity: 0.5
            fillMode: Image.PreserveAspectFit
            visible: true
            mipmap: true
        }

        Image {
            id: mainEmojiImage
            width: 180
            height: 180
            anchors.centerIn: parent
            source: ""
            fillMode: Image.PreserveAspectFit
            visible: false
            mipmap: true
        }

        // The overlay used during the pie timeout
        SimplifiedControls.ProgressCircle {
            id: progressCircle
            animationDuration: 7000 // Must match `TOTAL_EMOJI_DURATION_MS` in `simplifiedEmoji.js`
            anchors.centerIn: mainEmojiImage
            size: mainEmojiImage.width * 2
            opacity: 0.5
            colorCircle: "#FFFFFF"
            colorBackground: "#E6E6E6"
            showBackground: false
            isPie: true
            arcBegin: 0
            arcEnd: 360
            visible: false
        }

        OpacityMask {
            anchors.fill: mainEmojiImage
            source: mainEmojiImage
            maskSource: progressCircle
        }
    }


    function selectEmoji(code) {
        sendToScript({
            "source": "SimplifiedEmoji.qml",
            "method": "selectedEmoji",
            "code": code
        });
        root.isSelected = true;
        root.currentCode = code;
    }


    Rectangle {
        id: emojiIconListContainer
        anchors.top: emojiIndicatorContainer.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: emojiSearchContainer.top
        clip: true
        color: simplifiedUI.colors.darkBackground

        GridView {
            id: grid
            anchors.fill: parent
            anchors.leftMargin: 30
            anchors.rightMargin: 24
            cellWidth: 60
            cellHeight: 60
            model: filteredModel
            delegate: Image {
                    width: 52
                    height: 52
                    source: emoji52BaseURL + model.code.utf
                    fillMode: Image.PreserveAspectFit
                    MouseArea {
                        hoverEnabled: enabled
                        anchors.fill: parent
                        onEntered: {
                            grid.currentIndex = index
                            // don't allow a hover image change of the main emoji image 
                            if (root.isSelected) {
                                return;
                            }
                            // Updates the selected image
                            root.currentCode = model.code.utf;
                        }
                        onClicked: {
                            root.selectEmoji(model.code.utf);
                        }
                    }
                }
            cacheBuffer: 400
            focus: true
            highlight: Rectangle {
                color: Qt.rgba(1, 1, 1, 0.4)
                radius: 2
            }

            KeyNavigation.backtab: emojiSearchTextField
            KeyNavigation.tab: emojiSearchTextField

            Keys.onPressed: {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.selectEmoji(grid.model.get(grid.currentIndex).code.utf);
                }
            }
        }

        SimplifiedControls.VerticalScrollBar {
            parent: grid
            anchors.rightMargin: -grid.anchors.rightMargin + 2
        }

        HifiStylesUit.GraphikRegular {
            readonly property var cantFindEmojiList: ["😣", "😭", "😖", "😢", "🤔"]
            onVisibleChanged: {
                if (visible) {
                    text = "We couldn't find that emoji " + cantFindEmojiList[Math.floor(Math.random() * cantFindEmojiList.length)]
                }
            }
            visible: grid.model.count === 0
            anchors.fill: parent
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: simplifiedUI.colors.text.darkGrey
            size: 22
        }
    }


    Item {
        id: emojiSearchContainer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 40

        SimplifiedControls.TextField {
            id: emojiSearchTextField
            placeholderText: "Search"
            maximumLength: 100
            clip: true
            selectByMouse: true
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            onTextChanged: {
                if (text.length === 0) {
                    root.filterEmoji(emojiSearchTextField.text);
                } else {
                    waitForMoreInputTimer.restart();
                }
            }
            onAccepted: {
                root.filterEmoji(emojiSearchTextField.text);
                waitForMoreInputTimer.stop();
                if (filteredModel.count === 1) {
                    root.selectEmoji(filteredModel.get(0).code.utf);
                } else {
                    grid.forceActiveFocus();
                }
            }

            KeyNavigation.backtab: grid
            KeyNavigation.tab: grid
        }

        Timer {
            id: waitForMoreInputTimer
            repeat: false
            running: false
            triggeredOnStart: false
            interval: 300

            onTriggered: {
                root.filterEmoji(emojiSearchTextField.text);
            }
        }
    }

    function filterEmoji(filterText) {
        filteredModel.clear();

        if (filterText.length === 0) {
            for (var i = 0; i < mainModel.count; i++) {
                filteredModel.append(mainModel.get(i));
            }
            return;
        }

        for (var i = 0; i < mainModel.count; i++) {
            var currentObject = mainModel.get(i);
            var currentKeywords = currentObject.keywords.keywords;
            for (var j = 0; j < currentKeywords.length; j++) {
                if ((currentKeywords[j].toLowerCase()).indexOf(filterText.toLowerCase()) > -1) {
                    filteredModel.append(mainModel.get(i));
                    break;
                }
            }
        }
    }


    signal sendToScript(var message);

    function fromScript(message) {
        if (message.source !== "simplifiedEmoji.js") {
            return;
        }

        switch(message.method) {
            case "beginCountdownTimer":
                progressCircle.endAnimation = true;
                progressCircle.arcEnd = 0;
                root.isSelected = true;
            break;
            case "clearCountdownTimer":
                progressCircle.endAnimation = false;
                progressCircle.arcEnd = 360;
                progressCircle.endAnimation = true;
                root.isSelected = false;
            break;
            default:
                console.log("Message not recognized from simplifiedEmoji.js", JSON.stringify(message));
        }
    }
}