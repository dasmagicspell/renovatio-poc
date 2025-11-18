# HealthKit Setup Instructions

## iOS Configuration Required

To enable HealthKit integration in your Flutter app, you need to configure the iOS project with HealthKit capabilities.

### Steps to Enable HealthKit:

1. **Open the iOS project in Xcode:**
   - Navigate to the `ios` folder in your Flutter project
   - Right-click on `Runner.xcworkspace` and select "Open in Xcode"

2. **Add HealthKit Capability:**
   - Select the "Runner" target in the project navigator
   - Go to the "Signing & Capabilities" tab
   - Click the "+ Capability" button
   - Search for and add "HealthKit"

3. **Configure HealthKit:**
   - In the HealthKit capability section, check "HealthKit" to enable it
   - The app will now have access to HealthKit APIs

4. **Build and Run:**
   - Build the project in Xcode or use `flutter run` from the terminal
   - The app will request HealthKit permissions when you navigate to the Health Data page

### Permissions Already Configured:

The following permissions have been added to `Info.plist`:
- `NSHealthShareUsageDescription`: For reading health data
- `NSHealthUpdateUsageDescription`: For writing health data (if needed in the future)

### Testing:

1. Run the app on a physical iOS device (HealthKit doesn't work in the simulator)
2. Navigate to the Health Data page
3. Grant permissions when prompted
4. The app will display heart rate data from the last hour

### Note:

- HealthKit only works on physical iOS devices, not in the simulator
- Make sure you have heart rate data in the Health app
- The app will show appropriate messages if no data is available or if permissions are denied
