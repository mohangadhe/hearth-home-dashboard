# Hearth

Local-first iPad dashboard prototype, with a responsive browser interface and an uncompiled native iOS HomeKit inventory bridge.

## Preview now

Run `npm start` in this directory and open http://localhost:4173 on the Mac. From an iPhone on the same home Wi-Fi, use `http://<your-mac-lan-ip>:4173` while the Mac and server remain running. The address may change with DHCP. The development server serves only `dist/`, not native source files.

All lighting, scenes, temperature, humidity, and camera panels are explicitly demo content. Room names and device labels are generic demo examples, not a network scan or a current connection. There is no external font, analytics, CDN, or cloud dependency. Demo light state persists in localStorage; the native Home inventory remains in memory.

The service worker caches the interface on secure origins (HTTPS or localhost). The plain HTTP LAN preview on an iPhone does not provide service-worker offline support. It is a development preview, not the final iPad-only installation. The native app bundles `dist/` directly and does not need this server.

## Native inventory test

1. Install full Xcode from Apple. Command Line Tools alone cannot build the iOS app.
2. Open `native/Hearth.xcodeproj`.
3. In the Hearth target's Signing & Capabilities, select your development team, choose a unique bundle identifier, and confirm the HomeKit capability is provisioned. Developer account capabilities and signing availability must be checked; do not assume a free personal team supports this entitlement or permanent installation.
4. Connect an iPhone signed into the Apple Home you want to inspect. Enable Developer Mode if Xcode requests it, select that device, and run.
5. In the dashboard select Devices → Read Apple Home inventory. Allow Apple's Home data permission prompt on the phone.
6. The Devices page shows the authorized inventory. Empty inventory can mean no homes are configured for the signed-in account. Denied permissions and delayed loading produce a message.

The bridge reads home/room/accessory names, service and characteristic metadata, reachability, and scene names. It makes no accessory writes, executes no scenes, and reads no camera streams. It only accepts requests from the bundled main page and disallows remote navigation. Actual live controls, sensor readings, camera support, and media support remain future integration work. HomeKit does not guarantee all Apple Home UI features are available to third-party apps.

## Continuous display

For an eventual dedicated iPad, configure Guided Access and Display Auto-Lock on the device. The Night View button currently changes the dashboard palette; it does not change system brightness or prevent sleep. Reboots, OS updates, and signing expiration may require intervention. A development build is not a permanent kiosk deployment.

## Validation

`npm run check` validates JavaScript syntax. The web interface is checked in the browser. Native source and project files are supplied as a scaffold: full iOS compilation, entitlement provisioning, and physical-device HomeKit behavior require Xcode and have not yet been verified.

## Repository contents

`dist/` contains the hand-authored web source and bundled assets; it is intentionally tracked. `native/` contains the Swift HomeKit bridge, entitlements, and Xcode project. No private device inventory, credentials, signing keys, or local network addresses are included.
