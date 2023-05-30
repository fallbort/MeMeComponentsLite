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
        
    }
    //MARK: <>功能性方法
    public func checkPluginFinished(object: MeMeSingleDownloadProtocol) -> Bool {
        let existed:Bool = self.downloader?.fileDownloaded(object: object) ?? false
        if object.plugins.count > 1 {
            let preFinished = self.downloader?.pluginsPreFinished(object, plugin: self) ?? false
            return preFinished == true && existed == false
        }else{
            return !existed
        }
    }
    
    public func afterDeal(object:MeMeSingleDownloadProtocol,complete:((_ success:Bool,_ clearedUrl:URL?)->())?) {
        guard let downloader = downloader else {
            complete?(false,nil)
            return
        }
        self.progressChangedBlock?(0.1,false)
        let localFileURL = downloader.downloadFileUrl(object)
        if FileManager.default.fileExists(atPath: localFileURL.path) {
            do {
                try FileManager.default.removeItem(at: localFileURL)
            } catch {
                gLog(key:"meme.error","\(error)")
            }
        }
        self.progressChangedBlock?(1.0,true)
        complete?(true,localFileURL)
    }
    
    //MARK: <>内部View
    
    //MARK: <>内部UI变量
    //MARK: <>内部数据变量
    
    //MARK: <>内部block
    
}
