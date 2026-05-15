//
//  GitHubIssue.swift
//  SpaceManager
//

import Foundation

struct GitHubIssue: Codable {
    let number: Int
    let title: String
    let url: String
    let updatedAt: String
    let repository: Repository
    let labels: [Label]

    struct Repository: Codable {
        let name: String
        let nameWithOwner: String
    }

    struct Label: Codable {
        let name: String
    }

    var repoName: String { repository.name }
    var repoFullName: String { repository.nameWithOwner }
}
