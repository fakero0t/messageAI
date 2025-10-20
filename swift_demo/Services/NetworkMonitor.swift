//
//  NetworkMonitor.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import Foundation
import Network
import Combine

enum ConnectionQuality: Equatable {
    case excellent  // WiFi with good signal
    case good       // WiFi or 5G/LTE
    case fair       // 4G or weak WiFi
    case poor       // 3G or very weak connection
    case offline    // No connection
    
    var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .offline: return "Offline"
        }
    }
}

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType?
    @Published var connectionQuality: ConnectionQuality = .excellent
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? true
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
                self?.updateConnectionQuality(path: path)
                
                // Notify when network is restored
                if path.status == .satisfied && !wasConnected {
                    print("🌐 Network restored (\(self?.connectionQuality.description ?? "unknown"))")
                    NotificationCenter.default.post(name: .networkRestored, object: nil)
                } else if path.status != .satisfied && wasConnected {
                    print("📵 Network lost")
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func updateConnectionQuality(path: NWPath) {
        if path.status != .satisfied {
            connectionQuality = .offline
            return
        }
        
        // Determine quality based on connection characteristics
        if path.usesInterfaceType(.wifi) {
            // WiFi: check if expensive (tethered) or constrained (poor signal)
            if path.isConstrained {
                connectionQuality = .fair
            } else if path.isExpensive {
                connectionQuality = .good
            } else {
                connectionQuality = .excellent
            }
        } else if path.usesInterfaceType(.cellular) {
            // Cellular: heuristic based on constraints
            // In reality, would need to check actual bandwidth
            if path.isConstrained {
                connectionQuality = .poor  // Likely 3G or weak signal
            } else {
                connectionQuality = .fair  // Likely 4G/LTE
            }
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionQuality = .excellent
        } else {
            // Other connection types
            connectionQuality = .good
        }
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
}

extension Notification.Name {
    static let networkRestored = Notification.Name("networkRestored")
}

