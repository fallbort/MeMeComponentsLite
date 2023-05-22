//
//  MeMeSessionDelegate.swift
//  MeMeBaseComponents
//
//  Created by fabo on 2023/3/13.
//

import Foundation

import Foundation
import MeMeKit
import Alamofire

public class MeMeSessionDelegate : SessionDelegate {
    
    //MARK: <>外部变量
    
    //MARK: <>外部block
    
    
    //MARK: <>生命周期开始
    init() {
        
    }
    //MARK: <>功能性方法
    public override func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         didReceive challenge: URLAuthenticationChallenge,
                         completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let host = challenge.protectionSpace.host
        var data = Self.authenticationDataMap[host]
        if data == nil {
            let file = MeMeBaseComponentConfig.shared.netURLAuthenticationFileBlock(host)
            if let file = file {
                data = try? Data.init(contentsOf: file)
            }
        }
        if let localCertificateData = data,
           let serverTrust = challenge.protectionSpace.serverTrust,
           challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            //从信任管理链中获取第一个证书
            let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0)

            //SecCertificateCopyData：返回一个DER 编码的 X.509 certificate
            //根据二进制内容提取证书信息
            let remoteCertificateData
                = CFBridgingRetain(SecCertificateCopyData(certificate!))!

            // 证书校验：这里直接比较本地证书文件内容 和 服务器返回的证书文件内容
            if localCertificateData as Data == remoteCertificateData as! Data {
                let credential = URLCredential(trust: serverTrust)
                //尝试继续请求而不提供证书作为验证凭据
                challenge.sender!.continueWithoutCredential(for: challenge)
                //尝试使用证书作为验证凭据，建立连接
                challenge.sender?.use(credential, for: challenge)
                //回调给服务器，使用该凭证继续连接
                completionHandler(URLSession.AuthChallengeDisposition.useCredential,URLCredential(trust: challenge.protectionSpace.serverTrust!))
            }else {
                challenge.sender?.cancel(challenge)
                // 证书校验不通过
                completionHandler(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
            }
        }else{
            super.urlSession(session, task: task, didReceive: challenge, completionHandler: completionHandler)
        }
    }
    
    //MARK: <>内部View
    
    //MARK: <>内部UI变量
    //MARK: <>内部数据变量
    fileprivate static var authenticationDataMap:[String:Data] = [:]
    //MARK: <>内部block
    
}
