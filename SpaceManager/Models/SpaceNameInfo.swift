//
//  SpaceNameInfo.swift
//  SpaceManager
//
//  Adapted from Spaceman by Sasindu Jayasinghe (MIT License).
//

import Foundation

enum NameSource: String, Codable, Hashable {
    case auto
    case workspace
    case manual
}

struct SpaceNameInfo: Hashable, Codable {
    let spaceNum: Int
    let spaceName: String
    let spaceByDesktopID: String

    var displayUUID: String?
    var positionOnDisplay: Int?
    var currentDisplayIndex: Int?
    var currentSpaceNumber: Int?

    var nameSource: NameSource

    var isUserOverride: Bool { nameSource == .manual }

    var hasUserData: Bool {
        (nameSource == .manual || nameSource == .workspace) && !spaceName.isEmpty
    }

    init(
        spaceNum: Int,
        spaceName: String,
        spaceByDesktopID: String,
        nameSource: NameSource = .auto
    ) {
        self.spaceNum = spaceNum
        self.spaceName = spaceName
        self.spaceByDesktopID = spaceByDesktopID
        self.nameSource = nameSource
    }

    // Custom Codable for backward compat: migrates old isUserOverride bool → nameSource enum
    enum CodingKeys: String, CodingKey {
        case spaceNum, spaceName, spaceByDesktopID
        case displayUUID, positionOnDisplay, currentDisplayIndex, currentSpaceNumber
        case nameSource, isUserOverride
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        spaceNum = try c.decode(Int.self, forKey: .spaceNum)
        spaceName = try c.decode(String.self, forKey: .spaceName)
        spaceByDesktopID = try c.decode(String.self, forKey: .spaceByDesktopID)
        displayUUID = try c.decodeIfPresent(String.self, forKey: .displayUUID)
        positionOnDisplay = try c.decodeIfPresent(Int.self, forKey: .positionOnDisplay)
        currentDisplayIndex = try c.decodeIfPresent(Int.self, forKey: .currentDisplayIndex)
        currentSpaceNumber = try c.decodeIfPresent(Int.self, forKey: .currentSpaceNumber)

        if let source = try c.decodeIfPresent(NameSource.self, forKey: .nameSource) {
            nameSource = source
        } else if let legacy = try c.decodeIfPresent(Bool.self, forKey: .isUserOverride) {
            nameSource = legacy ? .manual : .auto
        } else {
            nameSource = .auto
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(spaceNum, forKey: .spaceNum)
        try c.encode(spaceName, forKey: .spaceName)
        try c.encode(spaceByDesktopID, forKey: .spaceByDesktopID)
        try c.encodeIfPresent(displayUUID, forKey: .displayUUID)
        try c.encodeIfPresent(positionOnDisplay, forKey: .positionOnDisplay)
        try c.encodeIfPresent(currentDisplayIndex, forKey: .currentDisplayIndex)
        try c.encodeIfPresent(currentSpaceNumber, forKey: .currentSpaceNumber)
        try c.encode(nameSource, forKey: .nameSource)
    }

    func withName(_ newName: String, nameSource: NameSource) -> SpaceNameInfo {
        var copy = SpaceNameInfo(
            spaceNum: spaceNum,
            spaceName: newName,
            spaceByDesktopID: spaceByDesktopID,
            nameSource: nameSource
        )
        copy.displayUUID = displayUUID
        copy.positionOnDisplay = positionOnDisplay
        copy.currentDisplayIndex = currentDisplayIndex
        copy.currentSpaceNumber = currentSpaceNumber
        return copy
    }
}
