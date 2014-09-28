// Copyright 2014-present 650 Industries, Inc. All rights reserved.

import Foundation

@objc public class BKServiceRegistrar {

    private(set) var addedServices: [ServiceKey: BKServiceTreeNode] = [:]
    private weak var serviceController: BKServiceController?

    init(controller: BKServiceController) {
        serviceController = controller
    }

    private func shouldRegisterService(service: BKService, forKey key: ServiceKey) -> Bool {
        let serviceController = self.serviceController!

        if serviceController.services[key] != nil {
            println("ERROR: Service \(key) already registered with the service controller")
            return false
        }

        for node in addedServices.values {
            if ObjectIdentifier(node.service) == ObjectIdentifier(service) {
                println("ERROR: Service \(key) is already added to the current service registrar")
                return false
            }
            if node.key == key {
                println("ERROR: A service with an identical key is already added to the current service registrar: \(node.service)")
                return false
            }
        }
        return true
    }

    public func registerClosure(closure: () -> Void, forKey key: ServiceKey, dependencies: [ServiceKey] = []) -> Bool {
        let closureService = BKClosureService(closure: closure)
        return registerService(closureService, forKey: key, dependencies: dependencies)
    }

    public func registerService(service: BKService, forKey key: ServiceKey, dependencies: [ServiceKey] = []) -> Bool {
        if !shouldRegisterService(service, forKey: key) {
            return false
        }

        let serviceController = self.serviceController!

        var dependencyNodes: [BKServiceTreeNode] = []
        for dependencyKey in dependencies {
            let dependencyNode = addedServices[dependencyKey] ?? serviceController.services[dependencyKey]!
            dependencyNodes.append(dependencyNode)
        }

        let node = BKServiceTreeNode(service: service, key: key, dependencies: dependencyNodes)
        addedServices[key] = node
        return true
    }
}

@objc class BKClosureService: BKService {

    let closure: () -> Void

    init(closure: () -> Void) {
        self.closure = closure
    }

    func loadService(callback: ServiceLoadCallback) {
        closure()
        callback(service: self, loaded: true, error: nil)
    }
}
