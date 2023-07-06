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
    case other = -18888894
}

public enum MemeCommonError: CustomNSError ,Equatable {
    case cancel
	case nonetwork
    case network
    case other(NSError?)  //一般不使用
    case normal(code: Int, msg: String,isCustom:Bool)
    
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
		case .other(let error):
			if let error = error {
				return error.code
			} else {
				return MemeCommonErrorCode.other.rawValue
			}
        case .normal(let code,  _, _):
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
        case .other(let error):
            if let error = error {
                userInfo[NSLocalizedDescriptionKey] = error.localizedDescription
            } else {
                userInfo[NSLocalizedDescriptionKey] = NELocalize.localizedString("other error", comment: "")
            }
        case .normal(_,  let msg,_):
            userInfo[NSLocalizedDescriptionKey] = msg
		}
		return userInfo
	}

    public func nsError() -> NSError {
		if case .other(let error) = self {
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

