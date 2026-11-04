# Iris Cam Monitor

A native macOS companion for the Iris Cam Android app.

The Mac app connects over the same local Wi-Fi network and displays Iris Cam's existing monitor interface in a dedicated macOS window. It uses the Android app's built-in authenticated HTTP monitor server, so live video, camera controls, focus/zoom pulls, exposure controls, audio monitoring, and desktop LUT preview remain compatible with the Android implementation.

## Requirements

- macOS 13 or later
- Xcode 15 or later
- Iris Cam running on the Android phone
- Mac and phone on the same Wi-Fi network

## Build

1. Open `IrisCamMonitor.xcodeproj` in Xcode.
2. Select the `IrisCamMonitor` scheme.
3. Build and run.

## Connect

1. Open the Monitor panel in Iris Cam on Android.
2. Note the displayed local IP address, port, and monitor PIN.
3. Enter the address (for example `192.168.1.25:8080`) and PIN in the Mac app.
4. Select Connect. Keep both devices on the same local network.

The app stores the last-used address locally. The PIN is kept only in memory for the current app session.

## Network and privacy

The connection is local-network HTTP, matching the Android monitor server. Do not expose the monitor port to the public internet or use it on an untrusted network. The PIN is required by the Android server for each request.

## Current implementation

This first native macOS companion provides a dedicated connection window and hosts the Android app's existing monitor page using WebKit. It intentionally reuses the established monitor protocol rather than implementing a second, potentially incompatible set of camera controls.
