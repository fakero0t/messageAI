#!/bin/bash

# Fix Xcode build errors - Run this with Xcode CLOSED

echo "🔧 Fixing Xcode build system..."
echo ""

# Step 1: Kill any running Xcode processes
echo "1️⃣ Stopping Xcode processes..."
killall Xcode 2>/dev/null || true
sleep 2

# Step 2: Clean DerivedData
echo "2️⃣ Cleaning DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData

# Step 3: Clean Swift Package Manager caches
echo "3️⃣ Cleaning Swift PM caches..."
rm -rf ~/Library/Caches/org.swift.swiftpm

# Step 4: Remove project-level SPM data
echo "4️⃣ Removing project SPM data..."
cd /Users/ary/Desktop/swift_demo
rm -rf swift_demo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
rm -rf swift_demo.xcodeproj/project.xcworkspace/xcuserdata

# Step 5: Clean build folder in project
echo "5️⃣ Cleaning project build artifacts..."
rm -rf .build
rm -rf build

echo ""
echo "✅ Done! Now:"
echo "   1. Open Xcode"
echo "   2. File → Packages → Resolve Package Versions"
echo "   3. Wait for packages to download (2-3 minutes)"
echo "   4. Build the project (Cmd+B)"
echo ""

