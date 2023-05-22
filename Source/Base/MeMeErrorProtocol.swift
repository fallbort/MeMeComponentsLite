//
//  MeMeErrorProtocol.swift
//  MeMeBaseComponents
//
//  Created by fabo on 2022/4/6.
//

import Foundation

public protocol FpnnErrorProtocol : CustomNSError, CustomStringConvertible {
    var code:Int {get set}
    var ex:String {get set}
    var raiser:String {get set}
}

extension FpnnErrorProtocol {
    public static var errorDomain: String { return "meme.fpnn" }
    
    /// The error code within the given domain.
    public var errorCode: Int { return code }
    
    /// The user-info dictionary.
    public var errorUserInfo: [String : Any] { return [NSLocalizedDescriptionKey: ex, NSLocalizedFailureReasonErrorKey: raiser] }
}

extension FpnnErrorProtocol {
    var description: String {
        return "FpnnError[code=\(code),ex=\(ex),raiser=\(raiser)]"
    }
}

public protocol PurchasedErrorProtocol: CustomNSError, CustomStringConvertible {
    var code:Int {get set}
    var message:String {get set}
}

extension PurchasedErrorProtocol {
    static var errorDomain: String { return "meme.purchased" }
    
    /// The error code within the given domain.
    var errorCode: Int { return code }
    
    /// The user-info dictionary.
    var errorUserInfo: [String : Any] { return [NSLocalizedDescriptionKey: message] }
}

extension PurchasedErrorProtocol {
    var description: String {
        return "PurchasedError[code=\(code),message=\(message)]"
    }
}

