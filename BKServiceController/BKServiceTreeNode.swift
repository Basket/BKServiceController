// Copyright 2014-present 650 Industries, Inc. All rights reserved.

import Foundation

class BKServiceTreeNode: Printable {

    var running: Bool = false

    let key: ServiceKey
    let service: BKService
    let dependencies: [BKServiceTreeNode]

    init(service: BKService, key: ServiceKey, dependencies: [BKServiceTreeNode]) {
        self.service = service
        self.key = key
        self.dependencies = dependencies
    }

    var description: String {
        return "[\(key)] => running=\(running) <\(service)> dependencies: \(dependencies)"
    }
}
