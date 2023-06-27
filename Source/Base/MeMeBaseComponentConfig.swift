//
//  MeMeBaseComponentConfig.swift
//  MeMeBaseComponents
//
//  Created by fabo on 2022/4/6.
//

import Foundation
import Result
import AVFoundation

public class BaseHttpUtil : HttpUtilProtocol {
    public var memeHeaders: [String : String] {return [String : String]()}
    public var baseURLString:String {return ""}
    public var maxUploadSize:Int { return 1024 * 1024 * 4}
}

public class BasePlayerUtil : PlayerUtilProtocol {
    
}

@objc public class MeMeBaseComponentConfig : NSObject {
    @objc public static let shared:MeMeBaseComponentConfig = MeMeBaseComponentConfig()
    //MARK:<>外部变量
    public var httpUtilObject:HttpUtilProtocol = BaseHttpUtil()
    public var playerUtilObject:PlayerUtilProtocol = BasePlayerUtil()
    
    //MARK:<>外部block
    @objc public var ne_myIdBlock:(()->String?) = {return nil}
    public var myIdBlock:(()->Int?) = {return nil}
    public var myNickNameBlock:(()->String?) = {return nil}
    public var mySessionTokenBlock:(()->String?) = {return nil}
    public var myAccountIsRegisterIn48HoursBlock:(()->Bool?) = {return nil}
    public var devModeBlock:(()->Bool) = {return false}
    public var productModeBlock:(()->Bool) = {return true}
    public var launchCountBlock:(()->Int) = {return 0}
    public var enableRtmAckBlock:(()->Bool) = {return true}
    public var fpnnHostsBlock:(()->[(host:String,port:Int)]?) = {return nil}
    public var netyHostsBlock:(()->[(host:String,port:Int)]?) = {return nil}
    public var rtmHostsBlock:(()->[(host:String,port:Int,projectId:Int,useBak:Bool)]?) = {return nil}
    
    public var isLandscapeBlock:(()->Bool) = {return false}
    public var serviceDegradeBlock:(()->Bool) = {return false}
    public var accountKeyIvBlock:(()->(key:Data,iv:Data)?) = {return nil}
    public var rootNavControllerBlock:((_ nestable:Bool)->UIViewController?) = {_ in return nil} //nested为优先获取presentedViewController
    public var setupAccountBlock:(()->()) = {return} //已设置忽略
    
    public var updateRtmTokenBlock:((@escaping (Bool)->())->()) = {complete in complete(false)}
    public var myRtmTokenBlock:(()->String?) = {return nil}
    public var getRoomChatTopics:((_ content: [String: [String: Any]])->[(key: String, value: [String: String])]?) = {content in return nil}
    
    public var accountDidChangedBlock:(()->()) = {return}  //账号变更
    public var accountDidLoadedBlock:(()->()) = {return} //账号载入后的服务加载
    
    public var netURLAuthenticationFileBlock:((_ host:String)->URL?) = {_ in return nil} //https证书文件位置

    //MARK:<>生命周期开始
    private override init() {super.init()}
    //MARK:<>功能性方法
    public func startNetworkListener() {
        NetworkListener.shared.restart()
    }
    
    //MARK:<>内部View
    
    //MARK:<>内部UI变量
    //MARK:<>内部数据变量
    
    //MARK:<>内部block
    
}
