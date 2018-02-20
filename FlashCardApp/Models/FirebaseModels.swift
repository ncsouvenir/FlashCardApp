//
//  FirebaseModels.swift
//  FlashCardApp
//
//  Created by C4Q on 2/12/18.
//  Copyright © 2018 C4Q. All rights reserved.
//

import Foundation

struct UserProfile: Codable {
    let userUID: String
    let userName: String
    let categories: [String]? //categoryUIDS = category.key
    //trying to encode the struct into jsonData
    func userToJSON() -> Any? {
        let jsonData = try! JSONEncoder().encode(self)
        return try! JSONSerialization.jsonObject(with: jsonData, options: [])
    }
}

struct Category: Codable {
    let userUID: String
    let cardUID: String
    let categoryUID: String
    let name: String?
    let description: String?
    let numOfcards: Int?
    let numCorrect: Int?
    let numWrong: Int?
    let flashCard: [String]?//flashcardid = flashcard.key
    func categoryToJSON() -> Any {
        let jsonData = try! JSONEncoder().encode(self)
        return try! JSONSerialization.jsonObject(with: jsonData, options: [])
    }
}


struct FlashCard: Codable {
    let cardUID: String // flashCardUIDS = flashcard.key
    let userUID: String
    let category: String
    let term: String?
    let definition: String?
    func flashCardToJSON() -> Any {
        let jsonData = try! JSONEncoder().encode(self)
        return try! JSONSerialization.jsonObject(with: jsonData, options: [])
    }
}
