//
//  Protocols.swift
//  MeMeBaseComponents
//
//  Created by fabo on 2022/4/27.
//

import Foundation

public protocol HttpUtilProtocol {
    var memeHeaders: [String: String] {get}
    func getUserHeaderForCpp()-> [String: Any]
    func getUserHeaderForJavaService()-> [String: String]
    
    var baseURLString:String {get}
    
    var maxUploadSize:Int {get}
}

extension HttpUtilProtocol {
    public func getUserHeaderForCpp()-> [String: Any] {
        return [String: Any]()
    }
    public func getUserHeaderForJavaService()-> [String: String] {
        return [String: String]()
    }
}

public protocol PlayerUtilProtocol {
    func getMyCountryRegionCode() -> String
}

extension PlayerUtilProtocol {
    public func getMyCountryRegionCode() -> String {
        return ""
    }
}
