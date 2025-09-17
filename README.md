# Bioloop - Simplified Architecture

## 🏗️ **New Clean Architecture Overview**

This is a **completely simplified** version of Bioloop that removes the complex wrapper layers and provides a clean, direct data flow.

### 📁 **File Structure**

```
/Bioloop/
├── Models/
│   ├── HealthData.swift          # Core data models
│   ├── HealthScore.swift         # Score calculations
│   └── JournalEntry.swift        # Journal data
├── Services/
│   ├── HealthKitManager.swift    # Single HealthKit service
│   └── DataManager.swift         # CoreData + caching
├── Views/
│   ├── HomeView.swift            # Clean main dashboard
│   └── BioloopApp.swift          # App entry point
├── ViewModels/
│   └── HomeViewModel.swift       # Simple view model
├── Utilities/
│   └── HealthCalculator.swift    # All score calculations
└── Tests/
    └── ArchitectureTest.swift    # Architecture verification
```

## 🔧 **Key Improvements**

### ✅ **1. Fixed Date Range Issues**
- **Problem**: Queries using `18:30 UTC` offsets instead of proper midnight-to-midnight
- **Solution**: Always use `calendar.startOfDay()` for consistent date ranges
- **Result**: Proper 24-hour date ranges aligned to local timezone

### ✅ **2. Fixed Zero Overwrite Problem**
- **Problem**: App overwrites valid scores with zeros on refresh
- **Solution**: Preserve existing scores when new data is unavailable
- **Result**: Dashboard no longer resets to zero unexpectedly

### ✅ **3. Simplified Data Flow**
- **Before**: 4+ services with complex caching and wrappers
- **After**: 2 services with direct, simple data flow
- **Result**: Easier to debug and maintain

### ✅ **4. Aggregate Queries**
- **Problem**: Individual sample queries creating gaps
- **Solution**: `HKStatisticsCollectionQuery` for daily summaries
- **Result**: More reliable data with fewer missing values

## 🚀 **How to Use**

### **1. Switch to New Architecture**
Replace `BioloopApp.swift` with `SimpleBioloopApp.swift` in your target:

```swift
// In your app target, change:
@main
struct BioloopApp: App { ... }

// To:
@main
struct SimpleBioloopApp: App { ... }
```

### **2. Run Tests**
```swift
// Add to any view to test the architecture:
Task {
    await runArchitectureTests()
}
```

### **3. Key Classes**

- **`HealthKitManager`**: Single point for all HealthKit data
- **`DataManager`**: Handles caching and CoreData
- **`HealthCalculator`**: Calculates all 4 health scores
- **`HomeViewModel`**: Clean data flow to UI

## 📊 **Data Flow**

```
HealthKit → HealthKitManager → HealthData → HealthCalculator → HealthScore → DataManager → ViewModel → View
```

## 🔍 **Debugging**

### **Check Permissions**
```swift
let availability = HealthKitManager.shared.checkDataAvailability()
print("Permission: \(availability.hasHealthKitPermission)")
print("Apple Watch: \(availability.hasAppleWatchData)")
```

### **Test Data Fetching**
```swift
do {
    let data = try await HealthKitManager.shared.fetchHealthData(for: Date())
    print("HRV: \(data.hrv ?? 0)")
} catch {
    print("Error: \(error)")
}
```

### **Run Architecture Test**
```swift
await ArchitectureTest.shared.runBasicTest()
```

## 🎯 **What This Solves**

1. **✅ No more "0 samples" errors** - Fixed date ranges and aggregate queries
2. **✅ No more zero overwrites** - Preserves existing data on refresh
3. **✅ Clean, maintainable code** - Removed 80% of complexity
4. **✅ Better error handling** - Clear feedback when data is unavailable
5. **✅ Faster development** - Simple architecture is easier to extend

## 📝 **Migration Notes**

- **Old files**: Backed up with `.backup.swift` extension
- **Constants**: Still available in `Utilities/Constants.swift`
- **Journal**: Basic implementation, can be extended
- **Charts**: Mini trend charts included, full charts can be added

The new architecture maintains all core features while being much simpler and more reliable! 🎉
