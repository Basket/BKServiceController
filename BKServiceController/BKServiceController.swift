// Copyright 2014-present 650 Industries, Inc. All rights reserved.

import Foundation

public typealias ServiceKey = String
public typealias ServiceRegistrationClosure = (controller: BKServiceController, registrar: BKServiceRegistrar) -> Void

private let ServiceLaunchTimeout: NSTimeInterval = 10.0

@objc public class BKServiceController {

    private let serviceQueue: dispatch_queue_t
    private(set) var services: [ServiceKey: BKServiceTreeNode] = [:]

    public class var sharedInstance: BKServiceController {
        struct Static {
            static let instance = BKServiceController()
        }
        return Static.instance
    }

    public init() {
        serviceQueue = dispatch_queue_create("basket.services", DISPATCH_QUEUE_CONCURRENT)
    }

    // MARK: - Accessing services

    public func serviceForKey(key: ServiceKey) -> BKService? {
        let node = services[key]
        return node?.service
    }

    public func serviceKeys() -> [ServiceKey] {
        return services.keys.array
    }

    // MARK: - Registering services

    public func registerServicesImmediately(register: ServiceRegistrationClosure) {
        let registrar = BKServiceRegistrar(controller: self)
        register(controller: self, registrar: registrar)
        for (key, node) in registrar.addedServices {
            assert(services[key] == nil, "Expected service \(key) not to have been registered")
            services[key] = node
        }

        for (key, node) in registrar.addedServices {
            // FIXME TODO: linearize the DAG
            for dependencyNode in node.dependencies {
                // TODO: error reporting here?
                assert(dependencyNode.running, "A needed dependency is not running!")
            }

            node.service.loadService { service, loaded, error in
                node.running = loaded
                assert(loaded, "Failed to load service \(key) with error \(error)")
            }
            node.running = true
        }
    }

    public func registerServices(register: ServiceRegistrationClosure) {
        let registrar = BKServiceRegistrar(controller: self)
        register(controller: self, registrar: registrar)
        for (key, node) in registrar.addedServices {
            assert(services[key] == nil, "Expected service \(key) not to have been registered")
            services[key] = node
        }

        recursiveLoad()
    }

    private func recursiveLoad() {
        let servicesToLoad = calculateNextServicesToLoad()
        if servicesToLoad.isEmpty {
            return
        }

        let group = dispatch_group_create()
        for node in servicesToLoad {
            dispatch_group_enter(group)
            dispatch_async(serviceQueue) {
                node.service.loadService { service, loaded, error in
                    node.running = loaded
                    dispatch_group_leave(group)
                    assert(loaded, "Failed to load service \(service) with error \(error)")
                }
                return
            }
        }

        blockThenContinue(group: group)
    }

    private func blockThenContinue(#group: dispatch_group_t) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            let timeout = dispatch_time(DISPATCH_TIME_NOW, Int64(ServiceLaunchTimeout * Double(NSEC_PER_SEC)))
            let result = dispatch_group_wait(group, timeout)
            if result != 0 { // Dispatch group didn't finish
                println("ERROR: Timeout reached while launching services")
                self.blockThenContinue(group: group)
            } else { // Dispatch group did finish
                dispatch_async(dispatch_get_main_queue()) {
                    self.recursiveLoad()
                }
            }
        }
    }

    private func calculateNextServicesToLoad() -> [BKServiceTreeNode] {
        var servicesToLoad: [BKServiceTreeNode] = []

        // Select non-running nodes whose dependencies are all running (no dependencies == all running)
        for node in services.values {
            if node.running {
                continue
            }

            let runningDependencies = node.dependencies.filter { $0.running }
            if runningDependencies.count == node.dependencies.count {
                servicesToLoad.append(node)
            }
        }

        return servicesToLoad
    }
}
