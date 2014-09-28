// Copyright 2014-present 650 Industries, Inc. All rights reserved.

import Foundation

public typealias ServiceLoadCallback = (service: BKService, loaded: Bool, error: NSError?) -> Void

@objc public protocol BKService: class {
    func loadService(callback: ServiceLoadCallback)
}
