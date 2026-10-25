# OBD-II app for Saudi Arabia: research (phase 1, nothing built yet)

## Competitors (App Store, checked Sep 2026)
- Car Scanner ELM OBD2: free, 4.8★ from 32.6k ratings. Readiness, freeze frame, Mode 06, custom PIDs, make profiles. Pro costs $7.99 one time. No maintenance reminders, no fuel log, no CarPlay. Its UI is dense and technical.
- OBD Fusion: $9.99, 4.7★. More than 250 PIDs, GPS logs, iCloud sync. Each make's enhanced pack (ABS/SRS/TCM) costs $14.99. CarPlay shows text only.
- BlueDriver: only works with its own $99.95 sensor. Its Repair Reports come from a database of real fixes. English only.
- FIXD: $59 sensor, and nearly everything sits behind a paywall ($99.99 a year). Users complain about recurring billing.
- Carly: built for coding BMW, VW and other German cars. Subscription only, weak on non-German makes.
- Torque: Android only, not available on iPhone.
- Infocar: strong in Korea (Hyundai/Kia), with a driving score.
- **Gap:** nobody offers native Arabic, Saudi repair prices, a used-car check report, Saudi فحص دوري prep, or alerts for summer heat.

## iOS constraints
- An iPhone only talks to BLE, Wi-Fi or MFi adapters. Classic Bluetooth (SPP) ELM327 clones do not work on iPhone.
- Recommended adapters: Vgate iCar Pro BLE 4.0 (budget), vLinker MC-IOS, OBDLink CX (BLE, best value), OBDLink MX+ (premium). Wi-Fi adapters work too, but they take over the phone's Wi-Fi connection.
- Cheap clones (v2.1) are unreliable. The app needs an adapter health check and a list of known-good adapters.
- App Store review risks: no claims that the app fixes the car, a safety disclaimer, no interacting with the screen while driving (auto-lock the UI above 10 km/h, passenger mode), and a clear Bluetooth permission purpose string. Writing or coding ECUs is risky, so phase 1 is read-only. Any AI explanation is labelled as estimated.

## GitHub
- kkonteh97/SwiftOBD2: SwiftPM, BLE and Wi-Fi, PID polling, DTC read/clear, demo mode. Base library.
- qadanm/elmulator: ELM327 emulator plus a CoreBluetooth mock, so BLE code can be tested in CI.
- Iakirmon/ios-obd2-ble-diagnostics: SwiftUI reference for multi-PID loops and SwiftData sessions.
- DTC descriptions: the open SAE J2012 generic code lists (for example the mytrile/obd-trouble-codes CSV). These need Arabic translation and a licence check.
- PIDs: Wikipedia OBD-II PIDs. Car Scanner and Torque-style extended PID CSVs (community) for Toyota and Hyundai.

## Saudi angle
- Most common cars: Toyota (Camry, Hilux, Land Cruiser, Corolla), Hyundai (Accent, Elantra, Sonata), Nissan (Patrol, Sunny), Ford, Chevrolet (Tahoe), Kia, GMC.
- Heat at 45–50°C: overheating (P0217, P0128), weak batteries (voltage below 12.2 V), AC load, fuel trims, catalytic converters (P0420).
- فحص دوري (MVPI) prep: readiness monitors, check-engine light status, emissions, battery, lights checklist.
- Price ranges in SAR, kept in a remote catalog: `catalog.json` on GitHub Pages holds DTC→cost, parts and tips, updated without an app update.

## Feature plan
**Core (free):** connect wizard, full scan (DTC stored, pending and permanent), clear codes, a car health score, Arabic and English explanations, readiness / فحص دوري check, live gauges, VIN decode, freeze frame.
**Pro:** a Saudi-dialect AI explanation and "what do I tell the mechanic", repair cost estimate in SAR, Mode 06, enhanced Toyota/Hyundai PIDs, graphs and CSV logs, trips and fuel, maintenance reminders with widgets and a Live Activity, heat alerts, multiple cars.
**Viral and social:** a shareable used-car check report (PDF + QR + link, «افحصها قبل تشتريها»), a 0–100 timer and drive score, a leaderboard among friends (invite only), and a car "health card" made for X/Snap.
**Monetization:** free core. Pro at about 14.99 SAR a month or 99 a year, or a 199 lifetime option. A one-off used-car report for 9.99. Affiliate links to adapters (Amazon.sa / Noon).

## Build plan (after approval)
1. SwiftUI app for iOS 17+, Liquid Glass with a fallback, RTL first, ar/en.
2. OBD layer: SwiftOBD2 (or a fork), with elmulator tests in GitHub Actions.
3. Offline DTC database (SQLite), plus a remote catalog on GitHub Pages.
4. AI: a proxy (Cloudflare Worker) with rate limits.
5. Release to TestFlight the same way as the previous apps.
