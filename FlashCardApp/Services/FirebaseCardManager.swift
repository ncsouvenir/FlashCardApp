//
//  FirebaseCardManager.swift
//  FlashCardApp
//
//  Created by C4Q on 2/12/18.
//  Copyright © 2018 C4Q. All rights reserved.
//

import Foundation
import FirebaseDatabase

enum FirebaseCardStatus: Error {
    case flashCardNotAdded
    case errorParsingFlashCardData
    case flashCardDidNotUpdate
    case flashCardNotDeleted
}

protocol FirebaseCardManagerDelegate: class {
    //Add flashcard protocols
    func addFlashCard(_ userService: FirebaseCardManager, card: FlashCard)
    func failedToAddFlashCard(_ userService: FirebaseCardManager, error: Error)
    
    //Retrieve flashcard protocols
    func getFlashCard(_ userService: FirebaseCardManager, card: FlashCard)
    func failToGetFlashCard(_ userService: FirebaseCardManager, error: Error)
    
    //Deleting flashcard protocols
    func deleteFlashCard(_ userService: FirebaseCardManager, withCardUID cardUID: String)
    func failedToDeleteFlashCard(_ userService: FirebaseCardManager, error: Error)
    
    //Updateflashcard protocols
    func updateFlashCard(_ userService: FirebaseCardManager, card: FlashCard)
    func failedToUpdateFlashCard(_ userService: FirebaseCardManager, error: Error)
}

//MARK: Automtically makes the functions optional without needing to have it conform to NSObject: Must have an implementation
extension FirebaseCardManagerDelegate {
    
}

class FirebaseCardManager {
    private init(){
        //root reference
        let dbRef = Database.database().reference()
        //child of the root
        cardRef = dbRef.child("flashcard")
    }
    
    
    private var cardRef: DatabaseReference!
    static let manager = FirebaseCardManager()
    weak var delegate: FirebaseCardManagerDelegate?
    
    //Add flashcard to firebase
    public func addFlashCardToFirebase(cardID: String, userUID: String, category: String, term: String, definition: String){
        //creating a unique key identifier
        let childByAutoID = Database.database().reference(withPath: "flashCard").childByAutoId()
        let childKey = childByAutoID.key
        var flashCard: FlashCard
        flashCard = FlashCard(cardUID: childKey, userUID: userUID, category: category, term: term, definition: definition)
        //setting the value of the flashcard
        childByAutoID.setValue((flashCard.flashCardToJSON())) { (error, dbRef) in
            if let error = error {
                self.delegate?.failedToAddFlashCard(self, error: FirebaseCardStatus.flashCardNotAdded)
                print("failed to add flashcard error: \(error)")
            } else {
                self.delegate?.addFlashCard(self, card: flashCard)
                print("flashcard saved to dbRef: \(dbRef)")
            }
        }
    }
    
    
    
    //Gets all of the flashcards for a SINGLE USER from Firebase.
    public func getFlashCard(fromUserID userID: String, completion: @escaping (_ flashCard: [FlashCard]) -> Void){
        getAllFlashCards { (flashCard) in
            if let flashCard = flashCard {
                let userFlashCards = flashCard.filter{$0.userUID == userID}
                completion(userFlashCards)
            }
        }
    }
    
    
    //Gets ALL of the flashcards from Firebase. Sorted by timestamp by default from newest to oldest.
    public func getAllFlashCards(completion: @escaping (_ flashCard: [FlashCard]?) -> Void){
        //observe a single event on the flashcard reference
        cardRef.observeSingleEvent(of: .value) {(dataSnapshot) in
            //Instantiate a empty array of type flashcard
            var flashcardDeck: [FlashCard] = []
            //Make sure the flashcard snapshot is a child of the flashcard node
            guard let flashCardSnapshots = dataSnapshot.children.allObjects as? [DataSnapshot] else {print("flashcard node has no children");return}
            //Iterate thru the snapshots
            for flashCardSnapshot in flashCardSnapshots{
                guard let rawJSON = flashCardSnapshot.value else {continue}
                //convert snapshot to json and decode
                do{
                    let jsonData = try JSONSerialization.data(withJSONObject: rawJSON, options: [])
                    let flashCard = try JSONDecoder().decode(FlashCard.self, from: jsonData)
                    flashcardDeck.append(flashCard)
                    self.delegate?.getFlashCard(self, card: flashCard)
                    print("flashcard added to flashCard array")
                }catch {
                    self.delegate?.failToGetFlashCard(self, error: FirebaseCardStatus.errorParsingFlashCardData)
                }
            }
            //run completetion handler on posts
            completion(flashcardDeck)
            //check is array is empty: handle with custom delegates
            if flashcardDeck.isEmpty{
                print("There are no posts in the database")
            }else{
                print("posts loaded successfully!")
            }
        }
    }
    
    
    //Updates a single flashCard for a single user.
    public func updateFlashCard(withcardUID cardUID: String, userUID: String, updatedFlashCard: FlashCard){
        //Specific flashcard ref based on that cards id
        let cardIDRef = cardRef.child(cardUID)
        let flashCard: FlashCard
        //Initialize flashcard with updated information
        flashCard = FlashCard(cardUID: cardUID,
                              userUID: userUID,
                              category: updatedFlashCard.category,
                              term: updatedFlashCard.term,
                              definition: updatedFlashCard.definition)
        //updating the values at that specific flashcard via downcasting
        cardIDRef.updateChildValues((flashCard.flashCardToJSON() as! [AnyHashable : Any])) { (error, _) in
            if let error = error {
                self.delegate?.failedToUpdateFlashCard(self, error: FirebaseCardStatus.flashCardDidNotUpdate)
                print("flashcard failed to update with error: \(error)")
            } else {
                self.delegate?.updateFlashCard(self, card: flashCard)
                print("flashcard did update with id: \(cardUID)")
            }
        }
    }
    
    
    //Delete sflashCard at it's specific cardUID
    public func deleteFlashCard(withCardID cardUID: String){
        //get post reference
        cardRef.child(cardUID).removeValue{ (error, _) in
            if let error = error {
                self.delegate?.failedToDeleteFlashCard(self, error: FirebaseCardStatus.flashCardNotDeleted)
                print("Error deleting flashCard: \(error.localizedDescription)")
            } else {
               self.delegate?.deleteFlashCard(self, withCardUID: cardUID)
            }
        }
    }
}
