//
//  Moya+Ext.swift
//  MeMe
//
//  Created by LuanMa on 16/9/13.
//  Copyright © 2016年 sip. All rights reserved.
//

import Alamofire
import MeMeKit
import Moya

extension MoyaProvider {
    public final class func MemeDefaultEndpointMapping(_ target: Target) -> Endpoint {
		if let myTarget = target as? MemeTargetType {
            var url: String
            if myTarget.path.isEmpty {
                url = myTarget.baseURL.absoluteString
            } else {
				var theUrl = myTarget.baseURL
				theUrl.appendPathComponent(myTarget.path)
                url = theUrl.absoluteString
            }

			var httpHeaderFields: [String: String]

			if let headers = myTarget.headers {
				httpHeaderFields = headers
			} else {
				httpHeaderFields = [String: String]()
			}

            // 服务器端强制加入的Http头信息，所有的HTTP API都要
            var headers: [String: String] = [:]
            if !Thread.isMainThread {
                DispatchQueue.main.sync {
                    headers = MeMeBaseComponentConfig.shared.httpUtilObject.memeHeaders
                }
            } else {
                headers = MeMeBaseComponentConfig.shared.httpUtilObject.memeHeaders
            }
            for (key, value) in headers {
                httpHeaderFields[key] = value
            }
            
            if let memeTarget = myTarget as? MemeTargetType {
                url = memeTarget.endpointPredeal(url)
            }
            
            var hasSpecialKey = httpHeaderFields.keys.contains(where: {$0 == "specialkey"}) == true
            let preEndPoint = Endpoint(url: url, sampleResponseClosure: { .networkResponse(200, target.sampleData) }, method: myTarget.method, task: myTarget.task, httpHeaderFields: httpHeaderFields)
            if hasSpecialKey == true {
                let bodyCount:Int = (try? preEndPoint.urlRequest().httpBody?.count) ?? 0
                let firstNum = bodyCount / 2555
                let secondNum = bodyCount % 2555
                let fouthNum = httpHeaderFields["specialkey"]?.count ?? 0
                let thirdNum = bodyCount / 25 + fouthNum
                httpHeaderFields["specialcode"] =  "\(firstNum + secondNum + thirdNum)\(secondNum*thirdNum)"
            }
            
            let endPoint = Endpoint(url: url, sampleResponseClosure: { .networkResponse(200, target.sampleData) }, method: myTarget.method, task: myTarget.task, httpHeaderFields: httpHeaderFields)
            return endPoint
        } else {
            return MoyaProvider.defaultEndpointMapping(for: target)
        }
    }
}

//创建默认的Session
public func MemeDefaultAlamofireManager(_ timeout: TimeInterval = 30) -> Session {
	let configuration = URLSessionConfiguration.default
	configuration.timeoutIntervalForRequest = timeout
	configuration.timeoutIntervalForResource = 120

    func dateToString(_ date: Date?) -> String {
        if let date = date {
            return "\(date.timeIntervalSince1970)"
        }
        return "null"
    }
    //创建回调事件监听
    let event = ClosureEventMonitor()
    event.taskDidFinishCollectingMetrics = {session, task, metrics in
        //获取task任务的总时长
        if metrics.taskInterval.duration > 3 {
            var detailString = ""
            if let transactionMetric = metrics.transactionMetrics.last {
                detailString += "request:  "
                detailString += "\(transactionMetric.request)"
                detailString += "\n"
                detailString += "\n"
                
                detailString += "duration:  "
                detailString += "\(metrics.taskInterval.duration)"
                detailString += "\n"
                
                detailString += "fetchStartDate:  "
                detailString += dateToString(transactionMetric.fetchStartDate)
                detailString += "\n"
                detailString += "\n"
                
                if let domainLookupEndDate = transactionMetric.domainLookupEndDate?.timeIntervalSince1970, let domainLookupStartDate = transactionMetric.domainLookupStartDate?.timeIntervalSince1970 {
                    detailString += "time_DNS:  "
                    detailString += "\(domainLookupEndDate - domainLookupStartDate)"
                    detailString += "\n"
                }
                
                detailString += "domainLookupStartDate:  "
                detailString += dateToString(transactionMetric.domainLookupStartDate)
                detailString += "\n"
                
                detailString += "domainLookupEndDate:  "
                detailString += dateToString(transactionMetric.domainLookupEndDate)
                detailString += "\n"
                detailString += "\n"
                
                if let endDate = transactionMetric.connectEndDate?.timeIntervalSince1970, let startDate = transactionMetric.connectStartDate?.timeIntervalSince1970 {
                    detailString += "time_Connection:  "
                    detailString += "\(endDate - startDate)"
                    detailString += "\n"
                }
                
                detailString += "connectStartDate:  "
                detailString += dateToString(transactionMetric.connectStartDate)
                detailString += "\n"
                
                detailString += "connectEndDate:  "
                detailString += dateToString(transactionMetric.connectEndDate)
                detailString += "\n"
                detailString += "\n"
                
                if let endDate = transactionMetric.secureConnectionEndDate?.timeIntervalSince1970, let startDate = transactionMetric.secureConnectionStartDate?.timeIntervalSince1970 {
                    detailString += "time_TLS:  "
                    detailString += "\(endDate - startDate)"
                    detailString += "\n"
                }
                
                detailString += "secureConnectionStartDate:  "
                detailString += dateToString(transactionMetric.secureConnectionStartDate)
                detailString += "\n"
                
                detailString += "secureConnectionEndDate:  "
                detailString += dateToString(transactionMetric.secureConnectionEndDate)
                detailString += "\n"
                detailString += "\n"
                
                if let endDate = transactionMetric.requestEndDate?.timeIntervalSince1970, let startDate = transactionMetric.requestStartDate?.timeIntervalSince1970 {
                    detailString += "time_GET:  "
                    detailString += "\(endDate - startDate)"
                    detailString += "\n"
                }
                detailString += "requestStartDate:  "
                detailString += dateToString(transactionMetric.requestStartDate)
                detailString += "\n"
                
                detailString += "requestEndDate:  "
                detailString += dateToString(transactionMetric.requestEndDate)
                detailString += "\n"
                
                if #available(iOS 13.0, *) {
                    detailString += "requestHeaderBytes:  "
                    detailString += "\(transactionMetric.countOfRequestHeaderBytesSent)"
                    detailString += "\n"
                    
                    detailString += "requestBodyTransferBytes:  "
                    detailString += "\(transactionMetric.countOfRequestBodyBytesSent)"
                    detailString += "\n"
                    
                    detailString += "requestBodyBytes:  "
                    detailString += "\(transactionMetric.countOfRequestBodyBytesBeforeEncoding)"
                    detailString += "\n"
                }
                detailString += "\n"
                
                if let endDate = transactionMetric.responseEndDate?.timeIntervalSince1970, let startDate = transactionMetric.responseStartDate?.timeIntervalSince1970 {
                    detailString += "time_Response:  "
                    detailString += "\(endDate - startDate)"
                    detailString += "\n"
                }
                detailString += "responseStartDate:  "
                detailString += dateToString(transactionMetric.responseStartDate)
                detailString += "\n"
                
                detailString += "responseEndDate:  "
                detailString += dateToString(transactionMetric.responseEndDate)
                detailString += "\n"
                
                if #available(iOS 13.0, *) {
                    detailString += "responseHeaderBytes:  "
                    detailString += "\(transactionMetric.countOfResponseHeaderBytesReceived)"
                    detailString += "\n"
                    
                    detailString += "responseBodyTransferBytes:  "
                    detailString += "\(transactionMetric.countOfResponseBodyBytesReceived)"
                    detailString += "\n"
                    
                    detailString += "responseBodyBytes:  "
                    detailString += "\(transactionMetric.countOfResponseBodyBytesAfterDecoding)"
                    detailString += "\n"
                }
                detailString += "\n"
            }
            gLog(key: "network.interface.taskInterval", detailString)
        }
    }
    //事件监听集合
    let eventMonitors: [EventMonitor] = [event]
    //创建带有舰艇的Session
    let manager = Session(configuration: configuration,delegate: MeMeSessionDelegate(), startRequestsImmediately: true, eventMonitors: eventMonitors)
    return manager
}

public protocol MemeTargetType: TargetType {
	var headers: [String: String]? { get }
	var body: [String: Any]? { get }
	var parameterEncoding: Moya.ParameterEncoding { get }
    func endpointPredeal(_ url:String) -> String //url请求前进行处理
    func canRequest() -> Bool  //是否可请求，false为强制阻止
    func responseExtraDeal(_ resp:Response) //返回后额外处理
    func isFpnnResponse() -> Bool  //是否是来自fpnn的结果
}

extension MemeTargetType {
    public var baseURL: URL {
        return URL(string: MeMeBaseComponentConfig.shared.httpUtilObject.baseURLString)!
	}

    public var path: String {
		return ""
	}

    public var method: Moya.Method {
		return Moya.Method.get
	}

    public var parameters: [String : Any]? {
		return nil
	}

    public var sampleData: Data {
		do {
			let dict = ["errorCode": 0, "message": "OK"] as [String : Any]
			return try JSONSerialization.data(withJSONObject: dict, options: [])
		} catch {
			return Data()
		}
	}

    public var multipartBody: [Moya.MultipartFormData]? {
		return nil
	}

    public var headers: [String: String]? {
		return nil
	}

    public var body: [String: Any]? {
		return nil
	}

    public var parameterEncoding: Moya.ParameterEncoding {
		return Alamofire.URLEncoding.default
	}

    public var task: Moya.Task {
        if let parameters = parameters {
            return .requestParameters(parameters: parameters, encoding: parameterEncoding)
        } else if let body = body {
            return .requestParameters(parameters: body, encoding: parameterEncoding)
        } else {
            return .requestPlain
        }
	}
    
    public func endpointPredeal(_ url:String) -> String {
        return url
    }
    
    public func canRequest() -> Bool {
        return true
    }
    
    public func responseExtraDeal(_ resp:Response) {
        
    }
    
    public func isFpnnResponse() -> Bool {
        return false
    }
}

extension Moya.MoyaError {
    public func toMemeError() -> MemeError {
        if case .underlying(let error, let response) = self, let afError = error as? AFError, afError.isExplicitlyCancelledError == true {
            return .cancel
        }
        return .network
    }
}
