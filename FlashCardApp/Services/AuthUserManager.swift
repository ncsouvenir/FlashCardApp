//
//  FirebaseUserManager.swift
//  FlashCardApp
//
//  Created by C4Q on 2/12/18.
//  Copyright © 2018 C4Q. All rights reserved.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseDatabase


enum AuthUserStatus: Error {
    case failedToSignIn
    case didFailToVerifyEmail
    case failedToSignOut
    case failedToSendNewPassword
    case failedToCreateUser
}

protocol AuthUserDelegate: class {
    //create user delegate protocols
    func didFailCreatingUser(_ userService: AuthUserManager, error: Error)
    func didCreateUser(_ userService: AuthUserManager, user: UserProfile)
    
    //sign out delegate protocols
    func didFailSigningOut(_ userService: AuthUserManager, error: Error)
    func didSignOut(_ userService: AuthUserManager)
    
    //sign in delegate protocols
    func didFailToSignIn(_ userService: AuthUserManager, error: Error)
    func didSignIn(_ userService: AuthUserManager, user: UserProfile)
    
    //verifying email protocols
    func didFailToVerifyEmail(_ userService: AuthUserManager, user: UserProfile, error: Error)
    func didSendEmailVerification(_ userService: AuthUserManager, user: UserProfile, message: String)
    
    //password reset protocols
    func didFailToSendPasswordReset(_ userService: AuthUserManager, error: Error)
    func didSendPasswordReset(_userService: AuthUserManager)
}

//MARK: Automtically makes the functions optional without needing to have it conform to NSObject: Must have an implementation
extension AuthUserDelegate {
    
}

//This API client is responsible for logging the user in and creating accounts in the Firebase database.
class AuthUserManager {
    private init(){
        //root reference
        let dbRef = Database.database().reference()
        //child reference
        usersRef = dbRef.child("users")
        self.auth = Auth.auth()
    }
    
    weak public var delegate: AuthUserDelegate?
    static let manager = AuthUserManager()
    private var usersRef: DatabaseReference!
    private var auth: Auth!
    
    // Gets and returns the current user logged into Firebase as a User object.
    //The User object contains info about the user, like phone number, display name, email, etc.
    //Methods can also be called on this User object to do things like send email verification,reset password etc.
    public func getCurrentUser() -> User? {
        return auth.currentUser
    }
    
    //Creates an account for the user with their email and password.
    public func createAccount(withEmail email: String, password: String, AndUserName userName: String){
        self.auth.createUser(withEmail: email, password: password) { (user, error) in
            if let error = error {
                print("Failure creating user with error: \(error)")
                self.delegate?.didFailCreatingUser(self, error: AuthUserStatus.failedToCreateUser)
            } else if let user = user, let displayName = user.displayName {
                
                //checking if username already exists
                let child = self.usersRef.child(displayName)
                child.observeSingleEvent(of: .value, with: {(dataSnapshot) in
                    //check to see if the username is already taken
                    guard !dataSnapshot.exists() else {print("\(displayName) is already taken");return}
                })
                //send verification email
                user.sendEmailVerification(completion: { (error) in
                    if let error = error {
                        print("failed to send email verification with error : \(error)")
                        self.delegate?.didFailToVerifyEmail(self, user: user, error: AuthUserStatus.didFailToVerifyEmail)
                    } else {
                        self.delegate?.didSendEmailVerification(self, user: user, message: "A verification email has been sent. Please check your email and verify your account before logging in.")
                    }
                })
                //add user to Firebase
                self.addUserToFirebase(userUID: user.uid, userName: userName, categories: nil)
            }
        }
    }
    
    private func addUserToFirebase(userUID: String, userName: String, categories: [String]?){
        let childByAutoID = usersRef.child("users").childByAutoId()
        let childKey = childByAutoID.key
        let user: UserProfile
        user = UserProfile(userUID: childKey, userName: userName, categories: [])
        childByAutoID.setValue(user.userToJSON()) { (error, _) in
            if let error = error {
                print("User not added with error: \(error)")
                self.delegate?.didFailCreatingUser(self, error: AuthUserStatus.failedToCreateUser)
            } else {
                print("User added to firebase with userUID: \(userUID)")
                self.delegate?.didCreateUser(self, user: user)
            }
        }
    }
    
    
    //Logs the user in with their email and password.
    public func login(withEmail email: String, andPassword password: String){
        auth.signIn(withEmail: email, password: password) { (user, error) in
            if let error = error{
                print("failed to sign in with error: \(error)")
                self.delegate?.didFailToSignIn(self, error: AuthUserStatus.failedToSignIn)
            }else if let user = user {
                if !user.isEmailVerified{
                    self.delegate?.didFailToVerifyEmail(self, user: user, error: AuthUserStatus.didFailToVerifyEmail)
                    self.logout()
                }
                self.delegate?.didSignIn(self, user: user)
                print("logged in")
            }
        }
    }
    
    //Signs the current user out of the app and Firebase.
    public func logout(){
        do{
            try auth.signOut()
            self.delegate?.didSignOut(self)
        }catch {
            print("failed to sign out with error: \(error)")
            self.delegate?.didFailSigningOut(self, error: AuthUserStatus.failedToSignOut)
        }
    }
    
    
    public func forgotPassword(withEmail email: String){
        auth.sendPasswordReset(withEmail: email) { (error) in
            if let error = error {
                print("failed to send password with eror : \(error)")
                self.delegate?.didFailToSendPasswordReset(self, error: AuthUserStatus.failedToSendNewPassword)
            } else {
                self.delegate?.didSendPasswordReset(_userService: self)
            }
        }
    }
    
    //gets userName from userID
    public func convertUIDToUserName(usingUID userUID: String, completion: @escaping (String) -> Void){
        let child = usersRef.child(userUID)
        child.observeSingleEvent(of: .value) { (dataSnapshot) in
            if let json = dataSnapshot.value {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
                    let user = try JSONDecoder().decode(UserProfile.self, from: jsonData)
                    completion(user.userName)
                } catch {
                    print("Failed to parse user profile data with error: \(error)")
                }
            }
        }
    }
    
    //changes users current user name to a new user name
    public func changeUserName(usingUserUID userUID: String, to newUserName: String ){
        let child = usersRef.child(userUID)
        child.child("userName").setValue(newUserName)
    }
    
    //load user for injection into user Profiles..
    private func getUser(fromUserUID userUID: String, completion: @escaping (_ currentUser: UserProfile) -> Void){
        usersRef.child(userUID)
        usersRef.observe(.value) { (dataSnapshot) in
            if let json = dataSnapshot.value {
                do{
                    let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
                    let currentUser = try JSONDecoder().decode(UserProfile.self, from: jsonData)
                    completion(currentUser)
                }catch{
                    print("Unable to parse currentUser")
                }
            }
        }
    }
}
