//
//  MeMeSinglePluginUnzip.swift
//  MeMeComponents
//
//  Created by xfb on 2023/5/29.
//

import Foundation
import MeMeKit

public class MeMeSinglePluginUnzip : NSObject, MeMeSinglePluginProtocol {
    public override init() {
        
    }
    
    public func cancel(downer:MeMeSingleFileDonwloader,object: MeMeSingleDownloadProtocol) {
        self.lock.lock()
        self.needCancel = true
        self.lock.unlock()
        
        self.clear(downer: downer, object: object)
    }
    
    public func checkPluginFinished(downer:MeMeSingleFileDonwloader,object: MeMeSingleDownloadProtocol) -> Bool {
        self.lock.lock()
        let finished = self.finishedDict[object.key]
        self.lock.unlock()
        if let finished = finished {
            return finished
        }else{
            if let localFileURL = self.getFileUrl(downer: downer, object: object) {
                let finished = FileManager.default.fileExists(atPath: localFileURL.path)
                return finished
            }
        }
        
        return false
    }
    
    public func afterDeal(downer:MeMeSingleFileDonwloader,object: MeMeSingleDownloadProtocol, complete: ((Bool, URL?) -> ())?) {
        guard let destPath = self.getFileUrl(downer: downer, object: object) else {
            complete?(false,nil)
            return
        }
        self.lock.lock()
        self.needCancel = false
        let progress = 0.0
        self.progress = progress
        self.finishedDict.removeValue(forKey: object.key)
        self.lock.unlock()
        self.progressChangedBlock?(progress,nil)
        let destTmp = self.getTempUrl(object: object)
        let sourcePath = downer.pluginsPreUrl(object, plugin: self).path
        gLog("test afterDeal 1,key=\(object.key),sourcePath=\(sourcePath),destPath=\(destPath),destTmp=\(destTmp)")
        do {
            if FileManager.default.fileExists(atPath: destPath.path) == true {
                try FileManager.default.removeItem(at: destPath)
            }
            if FileManager.default.fileExists(atPath: destTmp.path) == true {
                try FileManager.default.removeItem(at: destTmp)
            }
            try FileManager.default.createDirectory(at: destTmp, withIntermediateDirectories: true, attributes: nil)
            FileUtils.unzip(sourcePath, toDestination: destTmp.path,delegate: self) { [weak self] progress, success in
                guard let `self` = self else {return}
                self.lock.lock()
                var showProgress = self.progress
                self.lock.unlock()
                if var progress = progress {
                    progress = progress > 0.99 ? 0.99 : progress
                    self.lock.lock()
                    self.progress = progress
                    showProgress = progress
                    self.lock.unlock()
                }
                self.progressChangedBlock?(showProgress,nil)
                
                if success == true, progress != nil {
                    var success = true
                    do {
                        try FileManager.default.moveItem(at: destTmp, to: destPath)
                    } catch {
                        do {
                            if FileManager.default.fileExists(atPath: destPath.path) == true {
                                try FileManager.default.removeItem(at: destPath)
                            }
                        }catch {
                            
                        }
                        success = false
                    }
                    if success == true {
                        gLog("test afterDeal 2,key=\(object.key)")
                        self.lock.lock()
                        var showProgress = 1.0
                        self.progress = showProgress
                        self.finishedDict.removeValue(forKey: object.key)
                        self.lock.unlock()
                        self.progressChangedBlock?(showProgress,true)
                        
                        complete?(true,destPath)
                    }else{
                        gLog("test afterDeal 3,key=\(object.key)")
                        self.lock.lock()
                        self.finishedDict.removeValue(forKey: object.key)
                        let progress = self.progress
                        self.lock.unlock()
                        self.progressChangedBlock?(progress,false)
                        complete?(false,nil)
                    }
                }else if success == false {
                    gLog("test afterDeal 4,key=\(object.key)")
                    self.lock.lock()
                    self.finishedDict.removeValue(forKey: object.key)
                    let progress = self.progress
                    self.lock.unlock()
                    self.progressChangedBlock?(progress,false)
                    complete?(false,nil)
                }
            }
        }catch {
            gLog("test afterDeal 5,key=\(object.key)")
            self.lock.lock()
            self.finishedDict.removeValue(forKey: object.key)
            let progress = self.progress
            self.lock.unlock()
            self.progressChangedBlock?(progress,false)
            complete?(false,nil)
        }
    }
    
    public func getPercent(downer:MeMeSingleFileDonwloader,object:MeMeSingleDownloadProtocol) -> Double {
        self.lock.lock()
        let progress = self.progress
        self.lock.unlock()
        return progress
    }
    
    public func getPluginFile(downer:MeMeSingleFileDonwloader,object:MeMeSingleDownloadProtocol,preUrl:URL) -> URL {
        return self.getFileUrl(downer:downer,object: object) ?? preUrl
    }
    
    fileprivate func getFileUrl(downer:MeMeSingleFileDonwloader,object:MeMeSingleDownloadProtocol) -> URL? {
        return downer.resPluginsDir.appendingPathComponent(object.key + "_unzip")
    }
    
    fileprivate func getTempUrl(object:MeMeSingleDownloadProtocol) -> URL {
        return FileUtils.temporaryDirectory.appendingPathComponent(object.key + "_unzip")
    }
    
    fileprivate func clear(downer:MeMeSingleFileDonwloader,object: MeMeSingleDownloadProtocol) {
        self.lock.lock()
        self.finishedDict.removeValue(forKey: object.key)
        self.lock.unlock()
        guard let destPath = self.getFileUrl(downer:downer,object: object) else {
            return
        }
        let destTmp = self.getTempUrl(object: object)
        do {
            if FileManager.default.fileExists(atPath: destPath.path) == true {
                try FileManager.default.removeItem(at: destPath)
            }
            if FileManager.default.fileExists(atPath: destTmp.path) == true {
                try FileManager.default.removeItem(at: destTmp)
            }
        }catch {
            
        }
    }
    
    
    fileprivate var progress:Double = 0.0
    fileprivate var lock:NSLock = NSLock()
    fileprivate var needCancel:Bool = false
    fileprivate var finishedDict:[String:Bool] = [:]  //object key
}

extension MeMeSinglePluginUnzip : SSZipArchiveDelegate {
    public func zipArchiveShouldUnzipFile(at fileIndex: Int, totalFiles: Int, archivePath: String, fileInfo: unz_file_info) -> Bool {
        self.lock.lock()
        let isCanceld = self.needCancel
        self.lock.unlock()
        if isCanceld == true {
            return false
        }else{
            return true
        }
    }
}
