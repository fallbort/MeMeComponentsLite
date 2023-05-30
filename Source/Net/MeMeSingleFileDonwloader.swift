//
//  MeMeSingleFileDonwloader.swift
//  MeMe
//
//  Created by fabo on 2021/1/28.
//  Copyright © 2021 sip. All rights reserved.
//

import Foundation
import MeMeKit
import ObjectMapper
import Result
import Alamofire

public enum SingleDownloadStage : String {
    case start //开始下载
    case stop //停止下载
    case success //下载成功
    case failed //下载失败
}

public protocol MeMeSinglePluginProtocol : AnyObject {
    func getPluginFile(object:MeMeSingleDownloadProtocol,preUrl:URL) -> URL
    func checkPluginFinished(object:MeMeSingleDownloadProtocol) -> Bool  //是否处理完成
    func afterDeal(object:MeMeSingleDownloadProtocol,complete:((_ success:Bool,_ clearedUrl:URL?)->())?)  //进行处理
    func cancel(object:MeMeSingleDownloadProtocol)  //取消处理
    func getPercent(object:MeMeSingleDownloadProtocol) -> Double //处理进度
}

extension MeMeSinglePluginProtocol {
    public func getPluginFile(object:MeMeSingleDownloadProtocol,preUrl:URL) -> URL {return preUrl}
    public func getPercent(object:MeMeSingleDownloadProtocol) -> Double {return self.checkPluginFinished(object: object) == true ? 1.0 : 0.0}
    public func cancel(object:MeMeSingleDownloadProtocol) {}
}

private var MeMeSinglePluginDownloader = "MeMeSinglePluginDownloader"
private var MeMeSinglePluginProgress = "MeMeSinglePluginProgress"

extension MeMeSinglePluginProtocol {
    weak var downloader: MeMeSingleFileDonwloader? {
        get {
            let weakArray = objc_getAssociatedObject(self, &MeMeSinglePluginDownloader) as? WeakReferenceArray<MeMeSingleFileDonwloader>
            if let object = weakArray?.allObjects().first as? MeMeSingleFileDonwloader {
                return object
            } else {
                return nil
            }
        }
        
        set {
            let weakArray = WeakReferenceArray<MeMeSingleFileDonwloader>()
            if let object = newValue {
                weakArray.addObject(object)
            }
            objc_setAssociatedObject(self, &MeMeSinglePluginDownloader, weakArray, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    var progressChangedBlock: ((_ percent:CGFloat,_ done:Bool)->())? {
        get {
            let block = objc_getAssociatedObject(self, &MeMeSinglePluginProgress) as? ((_ percent:CGFloat,_ done:Bool)->())
            return block
        }
        set {
            objc_setAssociatedObject(self, &MeMeSinglePluginProgress, newValue, .OBJC_ASSOCIATION_COPY)
        }
    }
}

public protocol MeMeSingleDownloadProtocol {
    var fileName:String {get}
    var sourceUrl:String {get}
    var key:String {get}
    var alwaysRetry:Bool {get}
    var md5Check:String? {get}
    var sourceUrlConverCDN:String {get}
    var plugins:[MeMeSinglePluginProtocol] {get}
    func extraCheckLocalValid(url:URL) -> Bool
    
    var localUrl:URL? {get set}
    var localResumeUrl:URL? {get set}
    
}

public struct MeMeSingleDownloadObject:MeMeSingleDownloadProtocol {
    public init() {}
    public var fileName:String = ""   //拼写后的文件名
    public var sourceUrl:String = "" { //服务器url
        didSet {
            sourceUrlConverCDN = MeMeKitConfig.converCDNBlock(sourceUrl)
        }
    }
    
    public var alwaysRetry:Bool = false
    public var md5Check:String?

    public var plugins:[MeMeSinglePluginProtocol] = []
    
    public func extraCheckLocalValid(url:URL) -> Bool {
        return true
    }
    
    public var key:String {
        return fileName
    }
    public var sourceUrlConverCDN:String = ""
    
    public var localUrl:URL?   //下载器设定
    public var localResumeUrl:URL?  //断点续传Url
}

public class MeMeFileDownloadConfigure {
    public init() {}
    public var showLog = false
    public func setQueue(label:String,qos:DispatchQoS) {
        outSetQueue = DispatchQueue(label: label, qos: qos)
    }
    
    public func setQueue(_ queue:DispatchQueue) {
        outSetQueue = queue
    }
    
    public func setCacheUrl(url:URL?,orDirectory:String?) {
        if let url = url {
            outSetCacheUrl = url
        }else if let directory = orDirectory {
            outSetCacheUrl = FileUtils.libraryDirectory.appendingPathComponent(directory)
        }
    }
    
    public func setPluginsUrl(url:URL?,orDirectory:String?) {
        if let url = url {
            outSetPluginUrl = url
        }else if let directory = orDirectory {
            outSetPluginUrl = FileUtils.libraryDirectory.appendingPathComponent(directory)
        }
    }
    
    fileprivate var _queue:DispatchQueue?
    public var queue:DispatchQueue {
        if let queue = _queue {
            return queue
        }else{
            let newQueue = outSetQueue ?? DispatchQueue(label: "meme.singlefile.download", qos: .background)
            _queue = newQueue
            return newQueue
        }
    }
    
    fileprivate var _resCacheDir: URL?
    public var resCacheDir: URL {
        if let dir = _resCacheDir {
            return dir
        }else{
            let url = outSetCacheUrl ?? FileUtils.libraryDirectory.appendingPathComponent("singlefile")
            if !FileManager.default.fileExists(atPath: url.path) {
                do {
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
                } catch {
                    gLog(key:"meme.error","\(error)")
                }
            }
            _resCacheDir = url
            return url
        }
    }
    
    fileprivate var _resPluginDir: URL?
    public var resPluginDir: URL {
        if let dir = _resPluginDir {
            return dir
        }else{
            
            let url = outSetPluginUrl ?? FileUtils.libraryDirectory.appendingPathComponent("\(self.resCacheDir.lastPathComponent)_plugins")
            if !FileManager.default.fileExists(atPath: url.path) {
                do {
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
                } catch {
                    gLog(key:"meme.error","\(error)")
                }
            }
            _resPluginDir = url
            return url
        }
    }
    
    fileprivate var outSetQueue:DispatchQueue?
    fileprivate var outSetCacheUrl:URL?
    fileprivate var outSetPluginUrl:URL?
}

public struct MeMeSingleProgress {
    public var key:String = ""
    public var curSize:Int64?   //当前下载量
    public var totalSize:Int64?  //总大小
    public var isRunning:Bool = false  //是否在下载中
    public var isDone:Bool = false  //是否已完成
}


public class MeMeSingleFileDonwloader {
    //MARK:<>外部变量
    
    //MARK:<>外部block
    public var didDownLoadedBlock:((_ object:MeMeSingleDownloadProtocol,_ justPercent:Bool,_ done:Bool,_ isDownload:Bool)->())?
    public var didStageChangedInThreadBlock:((_ stage:SingleDownloadStage)->())?
    
    //MARK:<>生命周期开始
    public init(configure:MeMeFileDownloadConfigure) {
        self.resCacheDir = configure.resCacheDir
        self.downloadQueue = configure.queue
        self.resPluginsDir = configure.resPluginDir
        self.showLog = configure.showLog
        startNetworkWatcher()
    }
    //MARK:<>功能性方法
    public func startNetworkWatcher() {
        reachablityManager?.startListening(onUpdatePerforming: { [weak self](status) in
            self?.startNextDownload()
        })
    }
    
    //单个object中下载和plugins任务是否都完成
    public func allFinished(object: MeMeSingleDownloadProtocol) -> Bool {
        var hasUnfinished = false
        for plugin in object.plugins {
            let finished = plugin.checkPluginFinished(object: object)
            if finished == false {
                hasUnfinished = true
                break
            }
        }
        if hasUnfinished == false {
            let url = self.allFinishedFileUrl(object)
            return fileDownloaded(localFileURL: url)
        }else{
            return false
        }
    }
    
    //前面的plugins是否都完成
    public func pluginsPreFinished(_ object: MeMeSingleDownloadProtocol,plugin:MeMeSinglePluginProtocol?) -> Bool {
        var hasUnfinished = false
        if let plugin = plugin {
            for onePlugin in object.plugins {
                if NSObject.getAddress(plugin) != NSObject.getAddress(onePlugin) {
                    let finished = onePlugin.checkPluginFinished(object: object)
                    if finished == false {
                        hasUnfinished = true
                        break
                    }
                }else{
                    break
                }
            }
            if hasUnfinished == false {
                let url = self.allFinishedFileUrl(object)
                return fileDownloaded(localFileURL: url)
            }else{
                return false
            }
        }else{
            return fileDownloaded(object: object)
        }
    }
    //判断是否存在下载完的文件
    public func fileDownloaded(object: MeMeSingleDownloadProtocol) -> Bool {
        let localFileURL = downloadFileUrl(object)
        return fileDownloaded(localFileURL: localFileURL)
    }
    
    public func fileDownloaded(fileName: String) -> Bool {
        let localFileURL = downloadFileUrl(fileName: fileName)
        return fileDownloaded(localFileURL: localFileURL)
    }
    
    public func fileDownloaded(localFileURL: URL) -> Bool {
        otherLock.lock()
        var isDownloaded = false
        if let cached = downloadedCache[localFileURL.path] {
            isDownloaded = cached
        }else{
            let downloaded = FileManager.default.fileExists(atPath: localFileURL.path)
            downloadedCache[localFileURL.path] = downloaded
            isDownloaded = downloaded
        }
        otherLock.unlock()
        return isDownloaded
    }
    
    //获取下载后原始文件
    public func downloadFileUrl(_ object: MeMeSingleDownloadProtocol) -> URL {
        if let url = object.localUrl {
            return url
        }else{
            return resCacheDir.appendingPathComponent(object.fileName)
        }
    }
    //获取单个object中下载和所有插件完成后文件
    public func allFinishedFileUrl(_ object: MeMeSingleDownloadProtocol) -> URL {
        let downloadUrl = self.downloadFileUrl(object)
        return self.pluginsFileUrlInternel(object, plugins: object.plugins, preUrl: downloadUrl)
    }
    
    //前面的plugins返回的url
    public func pluginsPreUrl(_ object: MeMeSingleDownloadProtocol,plugin:MeMeSinglePluginProtocol?) -> URL {
        let rootUrl = self.downloadFileUrl(object)
        if let plugin = plugin {
            var plugins = [MeMeSinglePluginProtocol]()
            if let foundIndex = object.plugins.firstIndex(where: {NSObject.getAddress($0) == NSObject.getAddress(plugin)}) {
                for (index,item) in object.plugins.enumerated() {
                    if index < foundIndex {
                        plugins.append(item)
                    }else{
                        break
                    }
                }
            }
            return self.pluginsFileUrlInternel(object, plugins: plugins, preUrl: rootUrl)
        }else{
            return rootUrl
        }
    }
    
    fileprivate func pluginsFileUrlInternel(_ object: MeMeSingleDownloadProtocol,plugins:[MeMeSinglePluginProtocol],preUrl:URL) -> URL {
        var newPlugins = plugins
        if plugins.count > 0 {
            let onePlugin = newPlugins.removeFirst()
            let newPreUrl = onePlugin.getPluginFile(object: object, preUrl: preUrl)
            return self.pluginsFileUrlInternel(object, plugins: newPlugins, preUrl: newPreUrl)
        }else{
            return preUrl
        }
    }
    
    public func downloadFileUrl(fileName: String) -> URL {
        return resCacheDir.appendingPathComponent(fileName)
    }
    
    func downloadResumeFileUrl(_ object: MeMeSingleDownloadProtocol) -> URL {
        if let url = object.localResumeUrl {
            return url
        }else{
            return resCacheDir.appendingPathComponent(object.fileName + ".__resume__")
        }
    }
    
    public func addOneDownload(object: MeMeSingleDownloadProtocol) {
        lock.lock()
        var hasInContain = false
        if willDownloadGiftQueue.contains(where: { $0.key == object.key }) || downloadingGiftQueue.contains(where: { $0.key == object.key }) {
            hasInContain = true
        }
        if hasInContain == false {
            var newObject = object
            newObject.localUrl = downloadFileUrl(object)
            newObject.localResumeUrl = downloadResumeFileUrl(object)
            var key = newObject.key
            newObject.plugins.forEach { [weak self] plugin in
                plugin.downloader = self
                plugin.progressChangedBlock = { [weak self,weak plugin] percent,done in
                    DispatchQueue.main.async { [weak self,weak plugin] in
                        guard let `self` = self else {return}
                        self.lock.lock()
                        let inObject = self.downloadObjects[key]
                        self.lock.unlock()
                        
                        if let inObject = inObject,let plugin = plugin {
                            self.updatePluginsProgress(object: inObject,plugin: plugin, isDone: done)
                        }
                    }
                }
            }
            downloadObjects[newObject.key] = newObject
            willDownloadGiftQueue.append(newObject)
        }
        lock.unlock()
        if hasInContain == false {
            var newObject = object
            newObject.localUrl = downloadFileUrl(object)
            newObject.localResumeUrl = downloadResumeFileUrl(object)
            var hasDone = false
            if self.allFinished(object: newObject) == true {
                hasDone = true
            }

            didDownLoadedBlock?(newObject,false,hasDone,(hasDone == true ? false : true))
            startNextDownload()
        }
    }
    
    public func stopObject(object: MeMeSingleDownloadProtocol,isPause:Bool = false,del:Bool = false) {
        didStageChangedInThreadBlock?(.stop)
        lock.lock()
        if let index = willDownloadGiftQueue.firstIndex { (oneObject) -> Bool in
            return oneObject.key == object.key
        } {
            willDownloadGiftQueue.remove(at: index)
        }
        if let index = failDownloadGiftQueue.firstIndex { (oneObject) -> Bool in
            return oneObject.key == object.key
        } {
            failDownloadGiftQueue.remove(at: index)
        }
        if let index = downloadingGiftQueue.firstIndex { (oneObject) -> Bool in
            return oneObject.key == object.key
        } {
            downloadingGiftQueue.remove(at: index)
        }
        downloadRetry.removeValue(forKey: object.key)
        let request = downloadRequest.removeValue(forKey: object.key)
        downloadObjects.removeValue(forKey: object.key)
        if isPause == true {
            request?.cancel(producingResumeData: true)
        }else{
            request?.cancel()
        }
        let plugin = downloadPlugins.removeValue(forKey: object.key)
        plugin?.cancel(object: object)
        plugin?.progressChangedBlock = nil
        lock.unlock()
        
        if del == true {
            let localFileURL = downloadFileUrl(object)
            if FileManager.default.fileExists(atPath: localFileURL.path) {
                do {
                    try FileManager.default.removeItem(at: localFileURL)
                } catch {
                    gLog(key:"meme.error","\(error)")
                }
            }
            otherLock.lock()
            downloadedCache.removeValue(forKey: localFileURL.path)
            otherLock.unlock()
            clearProgress(object: object)
        }
        didDownLoadedBlock?(object,false,false,true)
        if request != nil {
            startNextDownload()
        }
    }
    
    private func startNextDownload() {
        if showLog {
            gLog("test start next")
        }
        otherLock.lock()
        let hasNetwork = reachablityManager == nil || reachablityManager!.isReachable == true
        otherLock.unlock()
        if hasNetwork == false {
            MeMeKitConfig.showHUDBlock(MeMeKitConfig.localizeStringBlock("check_network",.normal))
            return //无网络不继续
        }
        
        var object: MeMeSingleDownloadProtocol?
        lock.lock()
        let willCount = willDownloadGiftQueue.count
        let canDownload = downloadingGiftQueue.count < Self.maxDownloadCount
        if  willCount > 0,canDownload == true {
            object = willDownloadGiftQueue.first
        }
        lock.unlock()
        if let object = object {
            downloadQueue.async { [weak self] in
                guard let `self` = self else {return}
                if self.allFinished(object:object) == false {
                    self.firstDownload(key: object.key)
                }else{
                    self.lock.lock()
                    if let firstObject = self.willDownloadGiftQueue.first, firstObject.key == object.key {
                        self.willDownloadGiftQueue.removeFirst()
                    }
                    self.lock.unlock()
                }
                self.startNextDownload()
                
            }
        }else if willCount == 0 && canDownload == true {
            lock.lock()
            let count = failDownloadGiftQueue.count
            lock.unlock()
            if count > 0 {
                DispatchQueue.main.async { [weak self] in
                    _ = delay(3) { [weak self] in
                        guard let strongSelf = self else { return}
                        strongSelf.lock.lock()
                        let count = self?.failDownloadGiftQueue.count
                        if count > 0 {
                            if let failedQueues = self?.failDownloadGiftQueue {
                                self?.willDownloadGiftQueue.append(contentsOf: failedQueues)
                            }
                            self?.failDownloadGiftQueue.removeAll()
                        }
                        strongSelf.lock.unlock()
                        if count > 0 {
                            self?.startNextDownload()
                        }
                    }
                }
            }
        }
    }
    
    fileprivate func firstDownload(key:String) {
        self.download(object: nil,key: key)
    }
    
    fileprivate func retryDownload(object: MeMeSingleDownloadProtocol) {
        self.download(object: object,key: nil)
    }
    
    fileprivate func download(object: MeMeSingleDownloadProtocol?,key:String?) {
        var object: MeMeSingleDownloadProtocol? = object
        if object == nil { //非重试内部获取object
            lock.lock()
            let willCount = willDownloadGiftQueue.count
            if  willCount > 0,downloadingGiftQueue.count < Self.maxDownloadCount {
                let fisrtObject = willDownloadGiftQueue.first
                if fisrtObject?.key == key {
                    let newObject = willDownloadGiftQueue.removeFirst()
                    object = newObject
                }
            }
            var hasRequest = false
            if let object = object {
                // 如果并非是重试，那么发现队列中有当前礼物，那么不能继续执行了，等待执行完毕了再说
                if let index = downloadingGiftQueue.firstIndex { (oneObject) -> Bool in
                    return oneObject.key == object.key
                } {
                    hasRequest = true
                }
            }
            var skipToNext = false
            if let object = object,hasRequest == false, skipToNext == false {
                downloadingGiftQueue.append(object)
            }else{
                skipToNext = true
            }
            lock.unlock()
            if skipToNext == true {
                self.startNextDownload()
                return
            }
        }
        
        guard let object = object else {
            self.startNextDownload()
            return
        }
        
        let request = dowloadFile(object: object) { [weak self] success in
            if self?.showLog == true {
                gLog("test dowloadFile out")
            }
            guard let strongSelf = self else { return}
            if let success = self?.fileDownloaded(object: object) {
                var needRetry = false
                if success == false
                {
                    strongSelf.otherLock.lock()
                    let hasNetwork = self?.reachablityManager == nil || self?.reachablityManager!.isReachable == true
                    strongSelf.otherLock.unlock()
                    if hasNetwork == true {
                        var currentFaceuRetryNum = 0
                        strongSelf.lock.lock()
                        if let tmp = self?.downloadRetry[object.key] {
                            currentFaceuRetryNum = tmp
                        } else {
                            self?.downloadRetry[object.key] = currentFaceuRetryNum
                        }
                        if currentFaceuRetryNum < Self.retryNumMax  {
                            self?.downloadRetry[object.key] = currentFaceuRetryNum + 1
                        }
                        let oldRequest = self?.downloadRequest[object.key]
                        let hasRequest = oldRequest != nil
                        strongSelf.lock.unlock()
                        if hasRequest {
                            if currentFaceuRetryNum < Self.retryNumMax {
                                needRetry = true
                            } else {
                                strongSelf.lock.lock()
                                if object.alwaysRetry == true {
                                    if self?.failDownloadGiftQueue.contains(where: { (one) -> Bool in
                                        return one.key == object.key
                                    }) == false {
                                        self?.failDownloadGiftQueue.append(object)
                                    }
                                }
                                strongSelf.lock.unlock()
                            }
                        }else{
                            needRetry = false

                        }
                    }else{
                        strongSelf.lock.lock()
                        self?.willDownloadGiftQueue.append(object)
                        strongSelf.lock.unlock()

                    }
                    
                }
                if self?.showLog == true {
                    gLog("test dowloadFile out check needRetry")
                }
                if needRetry == false {
                    strongSelf.lock.lock()
                    self?.downloadRetry.removeValue(forKey: object.key)
                    self?.downloadRequest.removeValue(forKey: object.key)
                    let hasInFailed = self?.failDownloadGiftQueue.contains(where: { (one) -> Bool in
                        return one.key == object.key
                    })
                    strongSelf.lock.unlock()
                    if hasInFailed != true && success == false {
                        DispatchQueue.main.async {[weak self] in
                            self?.updateProgress(object: object, curSize: nil, totalSize: nil, isDone: false, isRunning: false)
                        }
                    }
                    if self?.showLog == true {
                        gLog("test dowloadFile out check success")
                    }
                    if success == true {
                        strongSelf.dealPlugins(object: object, complete: { [weak self] success in
                            guard let strongSelf = self else { return}
                            strongSelf.lock.lock()
                            if let index = strongSelf.downloadingGiftQueue.firstIndex { (oneObject) -> Bool in
                                return oneObject.key == object.key
                            } {
                                strongSelf.downloadingGiftQueue.remove(at: index)
                            }
                            if let index = strongSelf.downloadPlugins.firstIndex { (oneObject) -> Bool in
                                return oneObject.key == object.key
                            } {
                                strongSelf.downloadPlugins.remove(at: index)
                            }
                            strongSelf.lock.unlock()
                            strongSelf.startNextDownload()
                        })
                    }else{
                        strongSelf.lock.lock()
                        if let index = strongSelf.downloadingGiftQueue.firstIndex { (oneObject) -> Bool in
                            return oneObject.key == object.key
                        } {
                            strongSelf.downloadingGiftQueue.remove(at: index)
                        }
                        strongSelf.lock.unlock()
                        strongSelf.startNextDownload()
                    }
                }else{
                    if self?.showLog == true {
                        gLog("test dowloadFile out before retry")
                    }
                    self?.retryDownload(object: object)
                }
            }else{
                if self?.showLog == true {
                    gLog("test dowloadFile out no self")
                }
            }
        }
        
        // 只要走到这里，那就需要把先前的request都停掉，并且清除downloadRequest
        lock.lock()
        let oldRequest = downloadRequest.removeValue(forKey: object.key)
        downloadRequest[object.key] = request
        oldRequest?.cancel()
        lock.unlock()
        
    }
    
    /*
     * 下载某个url下的文件，监控进度和监控下载完成
     */
    fileprivate func dowloadFile(object: MeMeSingleDownloadProtocol, completion: ((Bool) -> Void)? = nil) -> DownloadRequest? {
        
        var request: DownloadRequest? = nil
        
        let urlMd5: String? = object.md5Check
        let localFileURL = downloadFileUrl( object)
        gLog("start dowloadFile,key=\(object.key),localFileURL=\(localFileURL.path)")
        
        if !FileManager.default.fileExists(atPath: localFileURL.path) {
            
            // 如果远程url存在，且本地的图片文件不存在，则开始下载
            let destination: DownloadRequest.Destination = { temporaryURL, response in
                return (localFileURL, [.removePreviousFile, .createIntermediateDirectories])
            }
            let cacheURL = downloadResumeFileUrl(object)
            if FileManager.default.fileExists(atPath: cacheURL.path),let data = FileManager.default.contents(atPath: cacheURL.path) {
                DispatchQueue.main.async {[weak self] in
                    self?.updateProgress(object: object, curSize: nil, totalSize: nil, isDone: false, isRunning: true)
                }
                request = AF.download(resumingWith:data, to: destination)
            }else{
                DispatchQueue.main.async {[weak self] in
                    self?.updateProgress(object: object, curSize: 0, totalSize: nil, isDone: false, isRunning: true)
                }
                request = AF.download(object.sourceUrlConverCDN, to: destination)
            }
            
            if let requestsource = request {
                request = requestsource.downloadProgress(closure: { [weak self] progress in
                    // 传入当前下载的size，更新下载进度
                    let curSize = progress.completedUnitCount
                    let totalSize = progress.totalUnitCount
                    DispatchQueue.main.async {[weak self] in
                        self?.updateProgress(object: object, curSize: curSize, totalSize: totalSize, isDone: false, isRunning: true)
                    }
                }).responseData { [weak self] response in
                    guard let `self` = self else {return}
                    // 下载完成，更新downloadSuccess 标志位
                    var success: Bool
                    switch response.result {
                    case .success:
                        if self.showLog == true {
                            gLog("test download success")
                        }
                        //print("downloading Success = \(faceuId)")
                        if FileManager.default.fileExists(atPath: cacheURL.path) {
                            do {
                                try FileManager.default.removeItem(at: cacheURL)
                            } catch {
                                gLog(key:"meme.error","\(error)")
                            }
                        }
                        success = self.checkFileValid(localURL: localFileURL, md5: urlMd5) ?? false
                        if success == true {
                            success = object.extraCheckLocalValid(url: localFileURL)
                        }
                        if success == false {
                            do {
                                try FileManager.default.removeItem(at: localFileURL)
                            } catch {
                                gLog(key:"meme.error","\(error)")
                            }
                        }
                        self.otherLock.lock()
                        self.downloadedCache[localFileURL.path] = success
                        self.otherLock.unlock()
                        if success == true {
                            DispatchQueue.main.async {[weak self] in
                                self?.updateProgress(object: object, curSize: nil, totalSize: nil, isDone: true, isRunning: false)
                            }
                        }else{
                            DispatchQueue.main.async {[weak self] in
                                self?.updateProgress(object: object, curSize: 0, totalSize: nil, isDone: false, isRunning: false)
                            }
                        }
                        
                    case let .failure(error):
                        gLog(key: "meme.error", "signle dowloadFile failed,res=\(object.sourceUrl),cdn=\(object.sourceUrlConverCDN),error=\(error)")
                        do {
                            try FileManager.default.removeItem(at: localFileURL)
                        } catch {
                            
                        }
                        self.otherLock.lock()
                        self.downloadedCache[localFileURL.path] = false
                        self.otherLock.unlock()
                        
                        if let data = response.resumeData {
                            data.write(toFile: cacheURL.path)
//                            var contentLengthInt:Int64 = 0
//                            if let ALLheader = response.response?.allHeaderFields  {
//                                if let header = ALLheader as? [String : Any] {
//                                    if let contentLength = header["Content-Length"] as? NSString {
//                                        contentLengthInt = Int64(contentLength.integerValue)
//                                    }
//                                }
//                            }
                            DispatchQueue.main.async {[weak self] in
                                self?.updateProgress(object: object, curSize: nil, totalSize: nil, isDone: false, isRunning: false)
                            }
                        }else{
                            if FileManager.default.fileExists(atPath: cacheURL.path) {
                                do {
                                    try FileManager.default.removeItem(at: cacheURL)
                                } catch {
                                    gLog(key:"meme.error","\(error)")
                                }
                            }
                            DispatchQueue.main.async {[weak self] in
                                self?.updateProgress(object: object, curSize: 0, totalSize: nil, isDone: false, isRunning: false)
                            }
                        }
                        success = false

                    }
                    if success == true {
                        self.didStageChangedInThreadBlock?(.success)
                    }else {
                        self.didStageChangedInThreadBlock?(.failed)
                    }
                    self.downloadQueue.async {
                        if self.showLog == true {
                            gLog("test download completion")
                        }
                        completion?(success)
                    }
                }
                request?.task?.priority = URLSessionTask.lowPriority
            }else{
                downloadQueue.async { [weak self] in
                    DispatchQueue.main.async {[weak self] in
                        self?.updateProgress(object: object, curSize: nil, totalSize: nil, isDone: false, isRunning: false)
                    }
                    if self?.showLog == true {
                        gLog("test download completion")
                    }
                    completion?(false)
                }
            }
            
        } else {
            downloadQueue.async { [weak self] in
                DispatchQueue.main.async {[weak self] in
                    self?.updateProgress(object: object, curSize: nil, totalSize: nil, isDone: true, isRunning: false)
                }
                if self?.showLog == true {
                    gLog("test download completion")
                }
               completion?(true)
            }
        }
        
        return request
    }
    
    fileprivate func dealPlugins(object: MeMeSingleDownloadProtocol,complete:((_ success:Bool)->())?) {
        var foundPlugin:MeMeSinglePluginProtocol?
        for onePlugin in object.plugins {
            if onePlugin.checkPluginFinished(object: object) == false {
                foundPlugin = onePlugin
                break
            }
        }
        if self.showLog == true {
            gLog("test dealPlugins foundPlugin=\(foundPlugin != nil)")
        }
        if let foundPlugin = foundPlugin {
            self.lock.lock()
            self.downloadPlugins[object.key] = foundPlugin
            self.lock.unlock()
            foundPlugin.afterDeal(object: object) { [weak self] (ret,clearedUrl) in
                guard let `self` = self else { return}
                if let clearedUrl = clearedUrl {
                    self.otherLock.lock()
                    self.downloadedCache.removeValue(forKey: clearedUrl.path)
                    self.otherLock.unlock()
                }
                if ret == true {
                    self.downloadQueue.async { [weak self] in
                        self?.dealPlugins(object: object, complete: { success in
                            complete?(success)
                        })
                    }
                }else{
                    complete?(false)
                }
            }
        }else{
            complete?(true)
        }
    }

    func checkFileValid(localURL:URL,md5:String?) -> Bool {
        var ret = false
        if FileManager.default.fileExists(atPath: localURL.path) {
            var needCheckedMd5 = false
            if let md5 = md5, md5.count > 0 {
                needCheckedMd5 = true
            }
            autoreleasepool {
                var data:Data? = nil
                if needCheckedMd5 == true {
                    do {
                        data = try Data.init(contentsOf: localURL)
                        if let data = data {
                            if let md5 = md5, md5.count > 0 {
                                let newMd5 = data.getMD5String()
                                if newMd5.uppercased() == md5.uppercased() {
                                    ret = true
                                }
                            }
                        }
                    }catch {
                         
                    }
                }
                
                if needCheckedMd5 == false {
                    ret = true
                }else if ret == false {
                    gLog(key: "meme.error", "singledownloadfile checkFileValid md5 not match,url=\(localURL.path),md5=\(md5 ?? "")")
                }
            }
        }else{
            gLog(key: "meme.error", "singledownloadfile checkFileValid file not exist,url=\(localURL.path),md5=\(md5 ?? "")")
        }
        return ret
    }
    
    fileprivate func updateProgress(object:MeMeSingleDownloadProtocol,curSize:Int64?,totalSize:Int64?,isDone:Bool,isRunning:Bool) {
        otherLock.lock()
        var progress = downloadProgress[object.key] ?? MeMeSingleProgress()
        progress.key = object.key
        progress.curSize = curSize == nil ? progress.curSize : curSize
        progress.totalSize = totalSize == nil ? progress.totalSize : totalSize
        progress.isDone = isDone
        progress.isRunning = isRunning
        downloadProgress[object.key] = progress
        otherLock.unlock()

        didDownLoadedBlock?(object,totalSize != nil ? true : false,(object.plugins.count > 0 ? false : isDone),true)
    }
    
    fileprivate func clearProgress(object:MeMeSingleDownloadProtocol) {
        var progress = MeMeSingleProgress()
        progress.key = object.key
        otherLock.lock()
        downloadProgress[progress.key] = progress
        otherLock.unlock()
    }
    
    fileprivate func updatePluginsProgress(object:MeMeSingleDownloadProtocol,plugin:MeMeSinglePluginProtocol,isDone:Bool) {
        var isDone = isDone
        if let last = object.plugins.last,NSObject.getAddress(last) == NSObject.getAddress(plugin) {
            
        }else{
            isDone = false
        }
        didDownLoadedBlock?(object,true,isDone,false)
    }
    
    public func getProgress(object:MeMeSingleDownloadProtocol) -> (percent:Double?,curSize:Int64?,totalSize:Int64?,isDone:Bool,isRunning:Bool,inAllStage:Bool,inDownlaod:Bool,inPlugin:Bool) {
        var percent:Double?
        var inAllStage = false
        var inDownlaod = false
        var inPlugin = false
        var downloaded:Bool?
        var progress:MeMeSingleProgress?
        if self.allFinished(object: object) == false {
            let isDownloaded = fileDownloaded(object: object)
            otherLock.lock()
            progress = downloadProgress[object.key]
            downloaded = isDownloaded == true ? isDownloaded : progress?.isDone
            
            if downloaded == true {
                percent = 1.0
            }else if let curSize = progress?.curSize,let totalSize = progress?.totalSize,totalSize > 0 {
                percent = Double(curSize) / Double(totalSize)
            }
            otherLock.unlock()
            
            lock.lock()
            if inDownlaod == false {
                inDownlaod = willDownloadGiftQueue.contains { (one) -> Bool in
                    return one.key == object.key
                }
            }
            if inDownlaod == false {
                inDownlaod = failDownloadGiftQueue.contains { (one) -> Bool in
                    return one.key == object.key
                }
            }
            if inDownlaod == false {
                inDownlaod = downloadRequest[object.key] != nil
            }
            
            if inPlugin == false {
                inPlugin = downloadPlugins[object.key] != nil
            }
            
            if inAllStage == false {
                inAllStage = downloadingGiftQueue.contains { (one) -> Bool in
                    return one.key == object.key
                }
            }
            let plugins:[MeMeSinglePluginProtocol] = downloadObjects[object.key]?.plugins ?? []
            lock.unlock()
            if plugins.count > 0, percent != nil {
                var pluginPercent:Double = 0.0
                for plugin in plugins {
                    pluginPercent += plugin.getPercent(object: object)
                }
                let oldPercent:Double = (percent ?? 0.0) / 2.0
                let oldPluginPercent = (pluginPercent / Double(plugins.count)) / 2.0
                percent = oldPercent + oldPluginPercent
            }
        }else {
            percent = 1.0
            downloaded = true
        }

        return (percent,progress?.curSize,progress?.totalSize,downloaded ?? false,progress?.isRunning ?? false,inAllStage,inDownlaod,inPlugin)
    }
    
    
    //MARK:<>内部View
    //MARK:<>内部UI变量
    //MARK:<>内部数据变量
    fileprivate var resCacheDir:URL
    public var resPluginsDir:URL
    public var showLog:Bool
    fileprivate var downloadQueue:DispatchQueue
    
    private let reachablityManager = NetworkReachabilityManager()
    
  
    var willDownloadGiftQueue: [MeMeSingleDownloadProtocol] = []
    var downloadingGiftQueue: [MeMeSingleDownloadProtocol] = []  //download和plugin阶段的流程中
    var failDownloadGiftQueue: [MeMeSingleDownloadProtocol] = []
    // 暂存变量
    static let progressMin = 0
    static let progressMax = 100
    static let retryNumMax: Int = 3
    static let maxDownloadCount = 4
    var downloadRetry = [String: Int]()   // 记录重试的次数
    var downloadRequest = [String: DownloadRequest]()
    var downloadPlugins = [String: MeMeSinglePluginProtocol]()
    var downloadObjects:[String:MeMeSingleDownloadProtocol] = [:]  //key的对象
    fileprivate let lock:NSLock = NSLock()
    
    var downloadProgress = [String: MeMeSingleProgress]()
    private var downloadedCache:[String:Bool] = [:]   //文件是否已下载完成的缓存,key为localPath
    fileprivate let otherLock:NSLock = NSLock()  //用于reachablityManager等
    
    public var downloadAllCount: Int {
        var count = 0
        lock.lock()
        count += downloadingGiftQueue.count
        lock.unlock()
        return count
    }
    
    public var downloadRequestCount: Int {
        var count = 0
        lock.lock()
        count = downloadRequest.count
        lock.unlock()
        return count
    }
    
    public var downloadPluginCount: Int {
        var count = 0
        lock.lock()
        count = downloadPlugins.count
        lock.unlock()
        return count
    }
    
    //MARK:<>内部block
}
