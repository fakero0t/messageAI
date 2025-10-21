//
//  NetworkMonitorTests.swift
//  swift_demoTests
//
//  Tests for PR-11: Network Monitoring & Resilience
//

import XCTest
import Network
@testable import swift_demo

final class NetworkMonitorTests: XCTestCase {
    
    var monitor: NetworkMonitor!
    
    override func setUp() {
        super.setUp()
        // Note: NetworkMonitor is a singleton, so we're testing its shared instance
        monitor = NetworkMonitor.shared
    }
    
    // Test 1: Singleton instance
    func testSingletonInstance() {
        let instance1 = NetworkMonitor.shared
        let instance2 = NetworkMonitor.shared
        
        XCTAssertTrue(instance1 === instance2, "NetworkMonitor should be a singleton")
    }
    
    // Test 2: Initial connection state is set
    func testInitialConnectionState() {
        // Monitor should have a connection state (either true or false)
        XCTAssertNotNil(monitor.isConnected)
    }
    
    // Test 3: Connection quality description
    func testConnectionQualityDescription() {
        XCTAssertEqual(ConnectionQuality.excellent.description, "Excellent")
        XCTAssertEqual(ConnectionQuality.good.description, "Good")
        XCTAssertEqual(ConnectionQuality.fair.description, "Fair")
        XCTAssertEqual(ConnectionQuality.poor.description, "Poor")
        XCTAssertEqual(ConnectionQuality.offline.description, "Offline")
    }
    
    // Test 4: Connection quality enum equality
    func testConnectionQualityEquality() {
        let quality1 = ConnectionQuality.excellent
        let quality2 = ConnectionQuality.excellent
        let quality3 = ConnectionQuality.poor
        
        XCTAssertEqual(quality1, quality2)
        XCTAssertNotEqual(quality1, quality3)
    }
    
    // Test 5: Network restored notification name
    func testNetworkRestoredNotification() {
        let notificationName = Notification.Name.networkRestored
        XCTAssertEqual(notificationName.rawValue, "networkRestored")
    }
    
    // Test 6: Monitor can start and stop
    func testMonitorStartStop() {
        // This test verifies the methods exist and don't crash
        // Actual network monitoring is harder to test in unit tests
        XCTAssertNoThrow(monitor.startMonitoring())
        XCTAssertNoThrow(monitor.stopMonitoring())
    }
}

