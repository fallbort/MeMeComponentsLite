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

public protocol MeMeSinglePluginProtocol {
    func checkPluginFinished(object:MeMeSingleDownloadProtocol) -> Bool  //是否处理完成
    func afterDeal(object:MeMeSingleDownloadProtocol,complete:(()->()))  //进行处理
    func cancel()  //取消处理
    func getPercent() -> Double //处理进度
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
    
    fileprivate var outSetQueue:DispatchQueue?
    fileprivate var outSetCacheUrl:URL?
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
    public var didDownLoadedBlock:((_ object:MeMeSingleDownloadProtocol,_ justPercent:Bool,_ done:Bool)->())?
    public var didStageChangedInThreadBlock:((_ stage:SingleDownloadStage)->())?
    
    //MARK:<>生命周期开始
    public init(configure:MeMeFileDownloadConfigure) {
        self.resCacheDir = configure.resCacheDir
        self.downloadQueue = configure.queue
        startNetworkWatcher()
    }
    //MARK:<>功能性方法
    public func startNetworkWatcher() {
        reachablityManager?.startListening(onUpdatePerforming: { [weak self](status) in
            self?.startNextDownload()
        })
    }
    
    public func allFinished(object: MeMeSingleDownloadProtocol) -> Bool {
        if fileDownloaded(object: object) == true {
            var hasUnfinished = false
            for plugin in object.plugins {
                let finished = plugin.checkPluginFinished(object: object)
                if finished == false {
                    hasUnfinished = true
                    break
                }
            }
            return !hasUnfinished
        }
        return false
    }
    //判断是否下载完成
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
            downloadObjects[newObject.key] = newObject
            willDownloadGiftQueue.append(newObject)
        }
        lock.unlock()
        if hasInContain == false {
            var newObject = object
            newObject.localUrl = downloadFileUrl(object)
            newObject.localResumeUrl = downloadResumeFileUrl(object)

            didDownLoadedBlock?(newObject,false,false)
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
        plugin?.cancel()
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
        didDownLoadedBlock?(object,false,false)
        if request != nil {
            startNextDownload()
        }
    }
    
    private func startNextDownload() {
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
        if  willCount > 0,downloadingGiftQueue.count < Self.maxDownloadCount {
            object = willDownloadGiftQueue.first
        }
        lock.unlock()
        if let object = object {
            downloadQueue.async { [weak self] in
                if self?.allFinished(object:object) == false {
                    self?.firstDownload()
                }else{
                    self?.startNextDownload()
                }
                
            }
        }else if willCount == 0 {
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
    
    fileprivate func firstDownload() {
        self.download(object: nil)
    }
    
    fileprivate func retryDownload(object: MeMeSingleDownloadProtocol) {
        self.download(object: object)
    }
    
    fileprivate func download(object: MeMeSingleDownloadProtocol?) {
        var object: MeMeSingleDownloadProtocol? = object
        if object == nil { //非重试内部获取object
            lock.lock()
            let willCount = willDownloadGiftQueue.count
            if  willCount > 0,downloadingGiftQueue.count < Self.maxDownloadCount {
                let newObject = willDownloadGiftQueue.removeFirst()
                object = newObject
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
            if let object = object,hasRequest == false {
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
                    if success == true {
                        strongSelf.dealPlugins(object: object, complete: { [weak self] success in
                            guard let strongSelf = self else { return}
                            strongSelf.lock.lock()
                            if let index = strongSelf.downloadingGiftQueue.firstIndex { (oneObject) -> Bool in
                                return oneObject.key == object.key
                            } {
                                strongSelf.downloadingGiftQueue.remove(at: index)
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
                    self?.retryDownload(object: object)
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
                    // 下载完成，更新downloadSuccess 标志位
                    var success: Bool
                    switch response.result {
                    case .success:
                        //print("downloading Success = \(faceuId)")
                        if FileManager.default.fileExists(atPath: cacheURL.path) {
                            do {
                                try FileManager.default.removeItem(at: cacheURL)
                            } catch {
                                gLog(key:"meme.error","\(error)")
                            }
                        }
                        success = self?.checkFileValid(localURL: localFileURL, md5: urlMd5) ?? false
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
                        self?.didStageChangedInThreadBlock?(.success)
                    }else {
                        self?.didStageChangedInThreadBlock?(.failed)
                    }
                    self?.downloadQueue.async {
                        completion?(success)
                    }
                }
                request?.task?.priority = URLSessionTask.lowPriority
            }else{
                downloadQueue.async { [weak self] in
                    DispatchQueue.main.async {[weak self] in
                        self?.updateProgress(object: object, curSize: nil, totalSize: nil, isDone: false, isRunning: false)
                    }
                    completion?(false)
                }
            }
            
        } else {
            downloadQueue.async { [weak self] in
                DispatchQueue.main.async {[weak self] in
                    self?.updateProgress(object: object, curSize: nil, totalSize: nil, isDone: true, isRunning: false)
                }
               completion?(true)
            }
        }
        
        return request
    }
    
    fileprivate func dealPlugins(object: MeMeSingleDownloadProtocol,complete:((_ success:Bool)->())?) {
        complete?(true)
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
    
    func updateProgress(object:MeMeSingleDownloadProtocol,curSize:Int64?,totalSize:Int64?,isDone:Bool,isRunning:Bool) {
        otherLock.lock()
        var progress = downloadProgress[object.key] ?? MeMeSingleProgress()
        progress.key = object.key
        progress.curSize = curSize == nil ? progress.curSize : curSize
        progress.totalSize = totalSize == nil ? progress.totalSize : totalSize
        if isDone == true {
            let localFileURL = downloadFileUrl(object)
            downloadedCache[localFileURL.path] = true
        }
        progress.isDone = isDone
        progress.isRunning = isRunning
        downloadProgress[object.key] = progress
        otherLock.unlock()

        didDownLoadedBlock?(object,totalSize != nil ? true : false,isDone)
    }
    
    func clearProgress(object:MeMeSingleDownloadProtocol) {
        var progress = MeMeSingleProgress()
        progress.key = object.key
        otherLock.lock()
        downloadProgress[progress.key] = progress
        otherLock.unlock()
    }
    
    public func getProgress(object:MeMeSingleDownloadProtocol) -> (percent:Double?,curSize:Int64?,totalSize:Int64?,isDone:Bool,isRunning:Bool,inAllStage:Bool,inDownlaod:Bool,inPlugin:Bool) {
        let isDownloaded = fileDownloaded(object: object)
        otherLock.lock()
        let progress = downloadProgress[object.key]
        let downloaded = isDownloaded == true ? isDownloaded : progress?.isDone
        var percent:Double?
        if downloaded == true {
            percent = 1.0
        }else if let curSize = progress?.curSize,let totalSize = progress?.totalSize,totalSize > 0 {
            percent = Double(curSize) / Double(totalSize)
        }
        otherLock.unlock()
        var inDownlaod = false
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
        var inPlugin = false
        if inPlugin == false {
            inPlugin = downloadPlugins[object.key] != nil
        }
        var inAllStage = false
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
                pluginPercent += plugin.getPercent()
            }
            let oldPercent:Double = (percent ?? 0.0) / 2.0
            let oldPluginPercent = (pluginPercent / Double(plugins.count)) / 2.0
            percent = oldPercent + oldPluginPercent
        }
        
        return (percent,progress?.curSize,progress?.totalSize,downloaded ?? false,progress?.isRunning ?? false,inAllStage,inDownlaod,inPlugin)
    }
    
    
    //MARK:<>内部View
    //MARK:<>内部UI变量
    //MARK:<>内部数据变量
    fileprivate var resCacheDir:URL
    fileprivate var downloadQueue:DispatchQueue
    
    private let reachablityManager = NetworkReachabilityManager()
    
  
    var willDownloadGiftQueue: [MeMeSingleDownloadProtocol] = []
    var downloadingGiftQueue: [MeMeSingleDownloadProtocol] = []
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
        count += downloadRequest.count
        count += downloadPlugins.count
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
