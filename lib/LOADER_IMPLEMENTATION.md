# Custom App Loader Implementation Guide

## Overview
This document explains how the custom `AppLoader` has been integrated throughout the application to provide consistent loading experiences that match your app's theme.

## Files Modified

### 1. `custom_app_loader.dart` (Already exists)
- Contains the main `AppLoader` widget with your app's theme colors
- Includes `AppLoaderOverlay` for full-screen loading overlays
- Features animated rotating loader with restaurant icon

### 2. `loader_utils.dart` (New utility file)
- Provides convenient methods to show/hide loaders
- Includes `showForOperation()` for automatic loader management
- Simplifies loader usage across the app

### 3. `main.dart` (Updated)
- Replaced default CircularProgressIndicator in StartupScreen with AppLoader
- Added AppLoader for Tilts loading in connection form

### 4. `login_screen.dart` (Updated)
- Uses AppLoaderOverlay for user fetching operations
- Shows loader during login process
- Displays loader during data synchronization

### 5. `running_orders_page.dart` (Already had loader)
- Uses AppLoader for loading orders
- Implements AppLoaderOverlay for navigation operations

### 6. `order_screen.dart` (Updated)
- Uses LoaderUtils.buildLoader() for menu loading
- Shows loader during order placement operations

### 7. `cash_bill_screen.dart` (Updated)
- Uses LoaderUtils.buildLoader() for bill data loading

## Usage Examples

### 1. Simple Loading Widget
```dart
// For stateful widgets with loading state
Widget build(BuildContext context) {
  return _isLoading 
    ? LoaderUtils.buildLoader(message: "Loading data...")
    : YourContentWidget();
}
```

### 2. Overlay Loader (Full Screen)
```dart
// Show overlay loader
LoaderUtils.show(context, message: "Processing...");

// Perform your async operation
await someAsyncOperation();

// Hide loader
LoaderUtils.hide();
```

### 3. Automatic Loader Management
```dart
// Automatically shows and hides loader
final result = await LoaderUtils.showForOperation(
  context,
  someAsyncOperation(),
  message: "Saving data...",
);
```

### 4. Custom AppLoader Widget
```dart
// Direct usage with custom parameters
AppLoader(
  message: "Custom message",
  size: 60.0,
  color: Colors.blue, // Optional custom color
)
```

## Implementation Locations

### Data Fetching Operations
- ✅ **Startup connection check** (main.dart)
- ✅ **User authentication** (login_screen.dart)
- ✅ **Data synchronization** (login_screen.dart)
- ✅ **Menu loading** (order_screen.dart)
- ✅ **Order placement** (order_screen.dart)
- ✅ **Running orders fetch** (running_orders_page.dart)
- ✅ **Bill data loading** (cash_bill_screen.dart)

### Navigation Operations
- ✅ **Opening order screens** (running_orders_page.dart)
- ✅ **Tilt loading** (main.dart)

## Theme Integration

The loader uses your app's theme colors:
- **Primary Color**: `#75E5E2` (Light Cyan)
- **Secondary Color**: `#41938F` (Teal Green) 
- **Tertiary Color**: `#0D1D20` (Very Dark Teal)
- **Background**: Semi-transparent dark overlay
- **Icon**: Restaurant icon matching your app's purpose

## Best Practices

1. **Always hide loaders**: Use try-finally blocks or LoaderUtils.showForOperation()
2. **Meaningful messages**: Provide context-specific loading messages
3. **Consistent usage**: Use LoaderUtils for standardized implementation
4. **Error handling**: Hide loaders in catch blocks
5. **User feedback**: Show appropriate messages during long operations

## Future Enhancements

To add loaders to additional screens:

1. Import the utilities:
```dart
import 'package:start_app/custom_app_loader.dart';
import 'package:start_app/loader_utils.dart';
```

2. Use appropriate method based on your needs:
   - `LoaderUtils.buildLoader()` for widget replacement
   - `LoaderUtils.show()/hide()` for overlay loading
   - `LoaderUtils.showForOperation()` for automatic management

3. Always provide meaningful loading messages that inform users about the current operation.

## Testing

Test the loader implementation by:
1. Checking all data fetching operations show appropriate loaders
2. Verifying loaders are hidden after operations complete
3. Testing error scenarios to ensure loaders don't persist
4. Confirming the loader matches your app's visual theme