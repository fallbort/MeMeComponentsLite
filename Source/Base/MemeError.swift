//
//  MemeError.swift
//  LiveMeme
//
//  Created by LuanMa on 16/4/13.
//  Copyright © 2016年 FunPlus. All rights reserved.
//

import Foundation
import MeMeKit



public let MemeErrorDomain = "meme"

public func defaultError() -> NSError {
	let errorMessage = NELocalize.localizedString("Oops, there's an error!", comment: "")
	return NSError(domain: MemeErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
}

public enum MemeErrorCode: Int {
    case cancel = -1
	case auth = 0
	case network
	case system
	case fpnn
	case nonetwork
	case database
    case purchase
    case purchased
    case fileTooLarge
    case normal
    case signined = 2000709
    case authTimeOut = 100202
}

public enum MemeError: CustomNSError {
	case auth
	case network
	case system(NSError?)
	case fpnn(FpnnErrorProtocol)
	case nonetwork
	case database
    case purchase(NSError?)
    case purchased(PurchasedErrorProtocol)
    case fileTooLarge
    case normal(NSError)
    case cancel
    case custom(code: Int, msg: String)
    case notConnect
    case authTimeOut
    
    public static var errorDomain: String { return MemeErrorDomain }

	/// The error code within the given domain.
    public var errorCode: Int {
		switch self {
		case .auth:
			return MemeErrorCode.auth.rawValue
        case .network, .notConnect:
			return MemeErrorCode.network.rawValue
		case .system(let error):
			if let error = error {
				return error.code
			} else {
				return MemeErrorCode.system.rawValue
			}
		case .fpnn(let fpnnError):
			return fpnnError.errorCode
		case .nonetwork:
			return MemeErrorCode.nonetwork.rawValue
		case .database:
			return MemeErrorCode.database.rawValue
        case .purchase(let error):
            if let error = error {
                return error.code
            } else {
                return MemeErrorCode.purchase.rawValue
            }
        case .purchased(let error):
            return error.code
        case .fileTooLarge:
            return MemeErrorCode.fileTooLarge.rawValue
        case .normal(let error):
            return error.code
        case .cancel:
            return MemeErrorCode.cancel.rawValue
        case .custom(let code,  _):
            return code
        case .authTimeOut:
            return MemeErrorCode.authTimeOut.rawValue
		}
	}

	/// The user-info dictionary.
    public var errorUserInfo: [String : Any] {
		var userInfo = [String : Any]()

		switch self {
		case .auth:
			userInfo[NSLocalizedDescriptionKey] = NELocalize.localizedString("Oops, there's an error!", comment: "")
        case .network, .notConnect:
			userInfo[NSLocalizedDescriptionKey] = NELocalize.localizedString("Can't connect to server", comment: "")
		case .system(let error):
			if let info = error?.userInfo {
				userInfo = info
			} else {
				userInfo[NSLocalizedDescriptionKey] = NELocalize.localizedString("Oops, there's an error!", comment: "")
			}
		case .fpnn(let fpnnError):
			userInfo = fpnnError.errorUserInfo
		case .nonetwork:
			userInfo[NSLocalizedDescriptionKey] = NELocalize.localizedString("Can't connect to server", comment: "")
		case .database:
			userInfo[NSLocalizedDescriptionKey] = NELocalize.localizedString("Database error", comment: "")
        case .purchase(let error):
            if let info = error?.userInfo {
                userInfo = info
            } else {
                userInfo[NSLocalizedDescriptionKey] = NELocalize.localizedString("Purchase Failed", comment: "")
            }
        case .purchased(let error):
            userInfo = error.errorUserInfo
        case .fileTooLarge:
            userInfo[NSLocalizedDescriptionKey] = NELocalize.localizedString("upload file too large", comment: "")
        case .normal(let error):
            userInfo = error.userInfo
        case .cancel:
            userInfo[NSLocalizedDescriptionKey] = NELocalize.localizedString("cancelled", comment: "")
        case .custom(_, let msg):
            userInfo[NSLocalizedDescriptionKey] = msg
        case .authTimeOut:
            userInfo[NSLocalizedDescriptionKey] = NELocalize.localizedString("whatsapp_expiredlink_toast", comment: "")
		}
		return userInfo
	}

    public func nsError() -> NSError {
		if case .system(let error) = self {
			if let error = error {
				return error
			}
		}
		return NSError(domain: MemeError.errorDomain, code: errorCode, userInfo: errorUserInfo)
	}
}

extension MemeError: CustomStringConvertible {
    public var description: String {
		switch self {
		case .auth:
			return "AuthError[\(NELocalize.localizedString("Oops, there's an error!", comment: ""))]"
        case .network, .notConnect:
			return "\(NELocalize.localizedString("Can't connect to server", comment: ""))"
		case .system(let error):
			return "System[\(error?.localizedDescription ??? unknown)]"
		case .fpnn(let fpnnError):
			return "\(fpnnError)]"
		case .nonetwork:
			return "\(NELocalize.localizedString("Can't connect to server", comment: ""))"
		case .database:
			return "Database[\(NELocalize.localizedString("Database error", comment: ""))]"
        case .purchase(let error):
            return "Purchase[\(error?.localizedDescription ??? unknown)]"
        case .fileTooLarge:
            return "UploadError[\(NELocalize.localizedString("upload file too large", comment: ""))]"
        case .normal(let error):
            return error.localizedDescription
        case .purchased(let error):
            return "\(error)"
        case .cancel:
            return "\(NELocalize.localizedString("cancelled", comment: ""))"
        case .custom(_, let msg):
            return msg
        case .authTimeOut:
            return "\(NELocalize.localizedString("whatsapp_expiredlink_toast", comment: ""))"
		}
	}
}

extension Swift.Error {
    
    public var errorMsg: String {
        guard let error = self as? MemeError,
           let errorMsg = error.errorUserInfo[NSLocalizedDescriptionKey] as? String else {
            return NELocalize.localizedString("Network connection failed", comment: "")
        }
        
        return errorMsg
    }
    
    public var code: Int {
        guard let error = self as? MemeError else {
            return -1
        }
        
        return error.errorCode
    }
    
}
