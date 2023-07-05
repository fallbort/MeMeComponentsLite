//
//  NetworkListener.swift
//  MeMe
//
//  Created by fabo on 2022/4/2.
//  Copyright © 2022 sip. All rights reserved.
//

import Foundation
import Alamofire
import AlamofireNetworkActivityIndicator
import RxSwift
import MeMeKit

@objc public class NetworkListener : NSObject {
    @objc public enum NetConnectStatus : Int, CustomStringConvertible {
        case unknown = 0
        case notReachable = 1
        case ethernetOrWiFi 
        case cellular
        
        public var description: String {
            let connStr: String
            switch self {
            case .unknown:
                connStr = "unknown"
            case .notReachable:
                connStr = "notReachable"
            case .ethernetOrWiFi:
                connStr = "wifi"
            case .cellular:
                connStr = "mobile"
            }
            return connStr
        }
    }
    public static let shared:NetworkListener = NetworkListener()
    //MARK:<>外部变量
    
    //MARK:<>外部block
    
    
    //MARK:<>生命周期开始
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc public override init() {
        super.init()
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { [weak self] notify in
            self?.onAppCallbackWillEnterBackground()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] notify in
            self?.onAppCallbackWillEnterForeground()
        }
    }
    //MARK:<>功能性方法
    @objc public func restart() {
        isStarted = true
        realRestart()
    }
    
    fileprivate func realRestart() {
        guard isStarted == true else {return}
        if networkReachabilityManager == nil {
            networkReachabilityManager = NetworkReachabilityManager()
        }
        networkReachabilityManager?.startListening(onUpdatePerforming: { [weak self](status) in
            guard let `self` = self else {return}
            var oldStatus:NetConnectStatus?
            if let value = try? self.statusChangedBObser.value() {
                oldStatus = value.curStatus
            }
            let curStatus = self.networkStatus
            if self.isWillForeground == false || oldStatus != curStatus {
                self.statusChangedBObser.onNext((oldStatus,curStatus))
                self.statusChangedPObser.onNext((oldStatus,curStatus))
                if curStatus == .ethernetOrWiFi || curStatus == .cellular {
                    gLog(key:"network.reachable.connect","")
                    //log.verbose("Network Reachability changed: true")
                }else{
                    gLog(key:"network.reachable.disconnect","")
                    //log.verbose("Network Reachability changed: false")
                }
            }
        })
        NetworkActivityIndicatorManager.shared.isEnabled = true
    }
    
    @objc public func stop() {
        isStarted = false
        realStop()
    }
    
    fileprivate func realStop() {
        networkReachabilityManager?.stopListening()
    }
    
    @objc fileprivate func onAppCallbackWillEnterForeground() {
        isWillForeground = true
        realRestart()
        isWillForeground = false
    }
    
    @objc fileprivate func onAppCallbackWillEnterBackground() {
        realStop()
    }
    //MARK:<>内部View
    
    //MARK:<>内部UI变量
    //MARK:<>内部数据变量
    @objc public var isNetworkReachability: Bool {
        get {
            return networkStatus == .ethernetOrWiFi || networkStatus == .cellular ? true : false
        }
    }
    
    @objc public var networkStatus:NetConnectStatus {
        get {
            if let status = networkReachabilityManager?.status {
                switch status {
                case let .reachable(info):
                    return info == .ethernetOrWiFi ? .ethernetOrWiFi : .cellular
                case .notReachable:
                    return .notReachable
                case .unknown:
                    return .unknown
                }
            }
            return .unknown
        }
    }
    
    @objc public static func isNetworkReachability(status:NetConnectStatus) -> Bool {
        return status == .ethernetOrWiFi || status == .cellular ? true : false
    }
    
    public lazy var statusChangedBObser = BehaviorSubject<(oldStatus:NetConnectStatus?,curStatus:NetConnectStatus)>(value: (nil,.unknown))
    public lazy var statusChangedPObser = PublishSubject<(oldStatus:NetConnectStatus?,curStatus:NetConnectStatus)>()
    
    fileprivate var networkReachabilityManager: NetworkReachabilityManager?
    fileprivate var isStarted = false
    fileprivate var isWillForeground = false
    //MARK:<>内部block
    
}
