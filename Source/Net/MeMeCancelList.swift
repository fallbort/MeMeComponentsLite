//
//  MeMeCancelList.swift
//  MeMeComponents
//
//  Created by xfb on 2023/5/21.
//

import Foundation

import Moya

public class MeMeCancelList {
    
    //MARK: <>外部变量
    public var list:[Moya.Cancellable] = []
    
    //MARK: <>外部block
    
    
    //MARK: <>生命周期开始
    public init() {
        
    }
    //MARK: <>功能性方法
    public func cancelAll() {
        for item in list {
            item.cancel()
        }
        list.removeAll()
    }
    
    public func append(object:Moya.Cancellable?) {
        guard let object = object else {return}
        self.list.append(object)
    }
    
    //MARK: <>内部View
    
    //MARK: <>内部UI变量
    //MARK: <>内部数据变量
    
    //MARK: <>内部block
    
}
