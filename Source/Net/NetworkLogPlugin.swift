//
//  NetworkLogPlugin.swift
//  MeMe
//
//  Created by LuanMa on 16/9/13.
//  Copyright © 2016年 sip. All rights reserved.
//

import Moya
import Result
import MeMeKit

private let output = true

public class NetworkLogPlugin: PluginType {
    public init() {}
	/// Called immediately before a request is sent over the network (or stubbed).
    public func willSendRequest(_ request: RequestType, target: TargetType) {
		if let req = request.request {
			//log.verbose("\(req)")
		}
	}
	
	// Called after a response has been received, but before the MoyaProvider has invoked its completion handler.
    public func didReceiveResponse(_ result: Result<Moya.Response, Moya.MoyaError>, target: TargetType) {
		switch result {
		case .success(let response):
			do {
				if let mimeType = response.response?.mimeType?.lowercased() {
                    if mimeType.contains("json") {
                        try NetworkLog.out(response.statusCode, target: target, body: response.mapJSON())
                    } else if mimeType.contains("text") || mimeType.contains("html") || mimeType.contains("xml") {
                        try NetworkLog.out(response.statusCode, target: target, body: response.mapString())
                    } else {
                        NetworkLog.out(response.statusCode, target: target, body: nil)
                    }
                }
			} catch {
				NetworkLog.out(response.statusCode, target: target, body: response.data)
			}
		case .failure(let error):
            gLog(key: "meme.error", error)
		}
	}
}

public struct NetworkLog {
    public typealias StatusCode = Int
    public static func out(_ statusCode: StatusCode, target: TargetType, body: Any?) {
		guard output else { return }
        guard let myTarget = target as? MemeTargetType else { return }

		if statusCode >= 300 || output {
			if let body = body {
				//log.debug("\(statusCode) - \(myTarget.method): \(myTarget.path) \(myTarget.parameters ?? [:])\n\(body)")
			} else {
				//log.debug("\(statusCode) - \(myTarget.method): \(myTarget.path) \(myTarget.parameters ?? [:])")
			}
		}
	}
}
