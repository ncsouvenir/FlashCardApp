//
//  FirebaseCategoryManager.swift
//  FlashCardApp
//
//  Created by C4Q on 2/12/18.
//  Copyright © 2018 C4Q. All rights reserved.
//

import Foundation
import FirebaseDatabase

enum FirebaseCategoryStatus: Error {
    case categoryNotAdded
    case errorParsingCategoryData
    case categoryDidNotUpdate
    case cateogryNotDeleted
}

protocol FirebaseCategoryDelegate: class {
    //Add category protocols
    func addCategory(_ userService: FirebaseCategoryManager, category: Category)
    func failedToAddCategory(_ userService: FirebaseCategoryManager, error: Error)
    
    //Retrieve category protocols
    func getCategory(_ userService: FirebaseCategoryManager, category: Category)
    func failToGetCategory(_ userService: FirebaseCategoryManager, error: Error)
    
    //Deleting category protocols
    func deleteCategory(_ userService: FirebaseCategoryManager, withCategoryUID categoryUID: String)
    func failedToDeleteCategory(_ userService: FirebaseCategoryManager, error: Error)
    
    //Update category protocols
    func updateCategory(_ userService: FirebaseCategoryManager, withCategoryUID categoryUID: String)
    func failedToUpdateCategory(_ userService: FirebaseCategoryManager, error: Error)
}


//MARK: Automtically makes the functions optional without needing to have it conform to NSObject: Must have an implementation
extension FirebaseCategoryDelegate {
    
}

class FirebaseCategoryManager{
    private init(){
        let dbRef = Database.database().reference()
        //child of the root
        categoryRef = dbRef.child("category")
    }
    
    static let manager = FirebaseCategoryManager()
    var categoryRef: DatabaseReference!
    weak var delegate: FirebaseCategoryDelegate?
    
    //Add category to firebase
    public func addCategoryToFirebase(userUID: String, cardUID: String, categoryUID: String, name: String, description: String?, numberOfCards: Int?, numCorrect: Int?, numWrong: Int?, flashcard: [String]?){
        //creating a unique key identifier
        let childByAutoID = Database.database().reference(withPath: "category").childByAutoId()
        let childKey = childByAutoID.key
        var category: Category
        category = Category(userUID: userUID, cardUID: cardUID, categoryUID: childKey, name: name, description: description, numOfcards: 0, numCorrect: 0, numWrong: 0, flashCard: [])
        //setting the value of the flashcard
        childByAutoID.setValue((category.categoryToJSON())) { (error, _) in
            if let error = error{
                self.delegate?.failedToAddCategory(self, error: FirebaseCategoryStatus.categoryNotAdded)
                print("Category not added with error: \(error)")
            }else{
                self.delegate?.addCategory(self, category: category)
                print("Category added with categoryUID: \(categoryUID)")
            }
        }
    }
    
    
    //Getting all categories back and filtering for ONE SPECIFIC USER by userUID's
    public func getCategory(_ userUID: String, completion: @escaping ([Category]) -> Void){
        getAllCategoriesFromFirebase { (category) in
            if let category = category {
                let userCategory = category.filter{$0.userUID == userUID}
                completion(userCategory)
            }
        }
    }
    
    //Getting ALL categories from firebase
    public func getAllCategoriesFromFirebase(using completion: @escaping ([Category]?) -> Void){
        //set observe single event
        categoryRef.observeSingleEvent(of: .value) { (categorySnapshot) in
            //set an instance of category variable
            var allCategories: [Category] = []
            //make sure the flashcard snapshot is a child of the flashcard node
            guard let categorySnapshots = categorySnapshot.children.allObjects as? [DataSnapshot] else {print("category node has no children");return}
            //iterate through category snapshots
            for categorySnapshot in categorySnapshots {
                //convert to rawJSON and decode
                guard let rawJSON = categorySnapshot.value else {continue}
                do{
                    let jsonData = try JSONSerialization.data(withJSONObject: rawJSON, options: [])
                    let category = try JSONDecoder().decode(Category.self, from: jsonData)
                    allCategories.append(category)
                    self.delegate?.getCategory(self, category: category)
                }catch {
                    print("Failed to get category with error: \(error.localizedDescription)")
                    self.delegate?.failToGetCategory(self, error: FirebaseCategoryStatus.errorParsingCategoryData)
                }
            }
            //run completion
            completion(allCategories)
            
            //empty array check
            if allCategories.isEmpty{
                print("There are no categories in the database")
            } else {
                print("Categories were retrieved successfully")
            }
        }
    }
    
    //Updating the cateogry name
    public func updateCategory(usingCategoryUID categoryUID: String, userUID: String, cardUID: String, updatedCategory: Category){
        //get reference to that specific category based on categories UID
        let catergoryIDRef = categoryRef.child(categoryUID)
        let category: Category
        category = Category(userUID: userUID,
                            cardUID: cardUID,
                            categoryUID: categoryUID,
                            name: updatedCategory.name,
                            description: updatedCategory.description,
                            numOfcards: updatedCategory.numOfcards,
                            numCorrect: updatedCategory.numCorrect,
                            numWrong: updatedCategory.numWrong,
                            flashCard: updatedCategory.flashCard)
        //updating the values at that specific category via downcasting
        catergoryIDRef.updateChildValues((category.categoryToJSON() as! [AnyHashable : Any])) { (error, _) in
            if let error = error {
                print("category is not updated with error: \(error)")
                self.delegate?.failedToUpdateCategory(self, error: FirebaseCategoryStatus.categoryDidNotUpdate)
            } else {
                print("category was updated with categoryUID: \(categoryUID)")
                self.delegate?.updateCategory(self, withCategoryUID: categoryUID)
            }
        }
    }
    
    //Deleting category with categoryUID's
    public func deleteCategoryFromFirebase(withCategoryUID categoryUID: String){
        //get category reference
        categoryRef.child(categoryUID).removeValue {(error, _) in
            if let error = error {
                self.delegate?.failedToDeleteCategory(self, error: FirebaseCategoryStatus.cateogryNotDeleted)
                print("delegate called but failed to delete with error: \(error)")
            } else {
                self.delegate?.deleteCategory(self, withCategoryUID: categoryUID)
                print("delegate called and category was deleted with cateoryUID: \(categoryUID)")
            }
        }
    }
}
