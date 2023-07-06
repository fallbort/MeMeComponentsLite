//
//  PPNetwork.swift
//  PetalPaint
//
//  Created by xfb on 2023/5/20.
//

import Foundation
import MeMeComponents
import Moya
import SwiftyJSON
import MeMeKit
import Result

public struct MeMeCommonNetwork {
    @discardableResult
    public static func request<T: MemeTargetType>(
        _ target: T,
        callbackQueue: DispatchQueue? = DispatchQueue(label:"moyarequest.net.z1j"),
        thisProvider: MoyaProvider<T>? = nil,
        complete completeCallback: @escaping (Result<Any, MemeCommonError>) -> Void
        ) -> Cancellable? {
        
        guard NetworkListener.shared.isNetworkReachability else {
            DispatchQueue.main.async {
                completeCallback(.failure(.nonetwork))
            }
            return nil
        }

        //log.verbose("request_Http,\(target.method.rawValue)->\(target.baseURL)\(target.path)")
        
        guard target.canRequest() == true else {
            DispatchQueue.main.async {
                completeCallback(.failure(.network))
            }
            return nil
        }
        
        let start = Date()
        let tprovider = thisProvider ?? MoyaProvider<T>(endpointClosure: MoyaProvider.defaultEndpointMapping,
                                                        session: MoyaProvider<T>.defaultAlamofireSession(),
                                                         plugins: [NetworkLogPlugin()])
        
        let ret = tprovider.request(target, callbackQueue:callbackQueue) { event in
            var isSuccess = false
            
            switch event {
            case let .success(response):
                var errorString:String?
                var isResponseSuccess:Bool?
                
                var successData:Any?
                var failedCode:Int?
                var failedMsg:String?
                let path = target.path
                if response.statusCode == 404 || response.statusCode == 400 {
                    //log.verbose("requesterror,api=\(target),path=\(path)")
                }

                do {
                    let resp:Response = try response.filterSuccessfulStatusCodes()
                  
                    target.responseExtraDeal(resp)
                    
                    if (response.statusCode == 200) {
                        if let json = try? JSON(data: resp.data) {
                            isSuccess = true
                            successData = json
                            isResponseSuccess = true
                        }else if let string = String(data: resp.data, encoding: .utf8) {
                            isSuccess = true
                            successData = string
                            isResponseSuccess = true
                        }else{
                            isResponseSuccess = false
                        }
                    }else{
                        isResponseSuccess = false
                    }
                } catch {
                    errorString = "\(target.method)->\(target.baseURL)\(target.path): \(error)"
                }
                
                DispatchQueue.main.async {
                    if let isResponseSuccess = isResponseSuccess {
                        if isResponseSuccess == true,let successData = successData {
                            completeCallback(.success(successData))
                        }else{
                            let code:Int = failedCode ?? 999999754
                            let msg:String = failedMsg ?? ""
                            completeCallback(.failure(.normal(code: code, msg: msg, isCustom: true)))
                        }
                    }else{
                        if let errorString = errorString {
                            gLog(key: "meme.error", errorString)
                        }
                        completeCallback(.failure(.network))
                    }
                }
                
            case let .failure(error):
                DispatchQueue.main.async {
                    gLog(key: "meme.error", "\(target.method)->\(target.baseURL)\(target.path): \(error)")
                    completeCallback(.failure(error.toMemeError()))
                }
            }
        }
        return ret
            
    }
    
}
