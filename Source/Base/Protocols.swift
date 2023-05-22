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

public protocol FpnnUtilProtocol {
    func getMemeHeaders() -> [String: Any]
    
    func extraDealResult(result:Result<[String: Any]?, MemeError>)
}

extension FpnnUtilProtocol {
    public func getMemeHeaders() -> [String: Any] {
        return [:]
    }
    public func extraDealResult(result:Result<[String: Any]?, MemeError>) {
        
    }
}

public protocol RtmManagerAnswerBaseDelegate {
    
}

public protocol RtmUtilProtocol {
    func getAnswerDelegate() -> RtmManagerAnswerBaseDelegate?
}

extension RtmUtilProtocol {
    public func getAnswerDelegate() -> RtmManagerAnswerBaseDelegate? {
        return nil
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
