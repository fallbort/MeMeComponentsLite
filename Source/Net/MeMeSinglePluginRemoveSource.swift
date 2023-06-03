//
//  MeMeSinglePluginRemoveSource.swift
//  MeMeComponents
//
//  Created by xfb on 2023/5/29.
//

import Foundation

import Foundation
import Cartography
import MeMeKit

public class MeMeSinglePluginRemoveSource : MeMeSinglePluginProtocol {
    
    //MARK: <>外部变量
    
    //MARK: <>外部block
    
    
    //MARK: <>生命周期开始
    public init() {
        self.percentAccess = 0.1
    }
    //MARK: <>功能性方法
    public func checkPluginFinished(downer:MeMeSingleFileDonwloader,object: MeMeSingleDownloadProtocol) -> Bool {
        let existed:Bool = downer.fileDownloaded(object: object)
        if object.plugins.count > 1 {
            let preFinished = downer.pluginsPreFinished(object, plugin: self)
            return preFinished == true && existed == false
        }else{
            return !existed
        }
    }
    
    public func afterDeal(downer:MeMeSingleFileDonwloader,object:MeMeSingleDownloadProtocol,complete:((_ success:Bool,_ clearedUrl:URL?)->())?) {
        self.progressChangedBlock?(0.1,nil)
        let localFileURL = downer.downloadFileUrl(object)
        var success = true
        if FileManager.default.fileExists(atPath: localFileURL.path) {
            do {
                try FileManager.default.removeItem(at: localFileURL)
            } catch {
                success = false
                gLog(key:"meme.error","\(error)")
            }
        }
        self.progressChangedBlock?(1.0,success)
        complete?(success,localFileURL)
    }

    //MARK: <>内部View
    
    //MARK: <>内部UI变量
    //MARK: <>内部数据变量
    
    //MARK: <>内部block
    
}
