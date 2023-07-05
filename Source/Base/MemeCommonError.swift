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
	return NSError(domain: MemeErrorDomain, code: -18888898, userInfo: [NSLocalizedDescriptionKey: errorMessage])
}

public enum MemeCommonErrorCode: Int {
    case cancel = -18888897
	case nonetwork = -18888896
    case network = -18888895
    case system = -18888894
}

public enum MemeCommonError: CustomNSError ,Equatable {
    case cancel
	case nonetwork
    case network
    case system(NSError?)
    case normal(NSError)
    case custom(code: Int, msg: String)
    
    public static var errorDomain: String { return MemeErrorDomain }

	/// The error code within the given domain.
    public var errorCode: Int {
		switch self {
		case .cancel:
			return MemeCommonErrorCode.cancel.rawValue
        case .nonetwork:
			return MemeCommonErrorCode.nonetwork.rawValue
        case .network:
            return MemeCommonErrorCode.network.rawValue
		case .system(let error):
			if let error = error {
				return error.code
			} else {
				return MemeCommonErrorCode.system.rawValue
			}
        case .normal(let error):
            return error.code
        case .custom(let code,  _):
            return code
		}
	}

	/// The user-info dictionary.
    public var errorUserInfo: [String : Any] {
		var userInfo = [String : Any]()

		switch self {
        case .cancel:
            userInfo[NSLocalizedDescriptionKey] = NELocalize.localizedString("user cancelled", comment: "")
        case .nonetwork:
            userInfo[NSLocalizedDescriptionKey] = NELocalize.localizedString("no network", comment: "")
        case .network:
            userInfo[NSLocalizedDescriptionKey] = NELocalize.localizedString("network error", comment: "")
        case .system(let error):
            if let error = error {
                userInfo[NSLocalizedDescriptionKey] = error.localizedDescription
            } else {
                userInfo[NSLocalizedDescriptionKey] = NELocalize.localizedString("system error", comment: "")
            }
        case .normal(let error):
            userInfo[NSLocalizedDescriptionKey] = error.localizedDescription
        case .custom(_,  let msg):
            userInfo[NSLocalizedDescriptionKey] = msg
		}
		return userInfo
	}

    public func nsError() -> NSError {
		if case .system(let error) = self {
			if let error = error {
				return error
			}
		}
		return NSError(domain: MemeCommonError.errorDomain, code: errorCode, userInfo: errorUserInfo)
	}
}

extension MemeCommonError: CustomStringConvertible {
    public var description: String {
        return (self.errorUserInfo[NSLocalizedDescriptionKey] as? String) ?? ""
	}
}

