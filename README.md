# PackProof 📦🎥

**PackProof** is a Flutter mobile application designed for e-commerce sellers, dispatchers, and warehouse teams to record, organize, and upload video evidence of parcel packing and customer returns directly to Google Drive.

It safeguards sellers against order dispute fraud, missing items, damaged claims, and fraudulent returns on major e-commerce platforms and courier services (including **Daraz**, **TCS**, **Leopards Courier**, and custom logistics).

---

## ✨ Features

- 🔍 **Smart Courier & Barcode Scanner**:
  - Automatically identifies order IDs and tracking numbers from barcodes, QR codes, and URLs.
  - Built-in recognition for Pakistani & regional couriers:
    - **Daraz Express (`PK-DEX...`)**
    - **Leopards Courier (`LCS...`)**
    - **TCS Express (`TCS...`)**
    - Generic AWBs and custom order numbers.
  - Automatically ignores non-tracking numbers (e.g., product prices, dates).
  - Manual confirmation and edit dialog before recording.

- 🎥 **Dual Verification Workflows**:
  - **Record Packing**: Records the item inspection, packing, and sealing. Uploads directly into:
    `Google Drive / PackProof / YYYY-MM-DD / <Tracking-or-Order-ID> / packing_<id>_<timestamp>.mp4`
  - **Record Return**: Scans return parcels, locates the original packing folder in Google Drive, and saves the unboxing proof video in the **exact same folder** (`return_<id>_<timestamp>.mp4`).

- ☁️ **Resilient Background Upload Queue**:
  - Automatically queues uploads locally using `shared_preferences`.
  - **Crash & Interruption Recovery**: If the app is closed, suspended, or loses connection during an upload, it safely keeps the video in the pending queue and automatically resumes uploading when reopened or reconnected.
  - **Auto-Retry with Backoff**: Up to 5 automatic retries for temporary network drops or token refreshes without marking videos as failed.
  - Status filters: *All*, *Active*, *Pending*, *Done*, and *Failed* (with manual "Retry all" support).

- 📁 **Offline Storage & History**:
  - Local disk storage tracking and usage statistics in Settings.
  - Date-grouped historical view of recordings.
  - Video playback and sharing via WhatsApp, Email, etc. using `share_plus`.

- 🔐 **Google Drive Integration**:
  - OAuth 2.0 integration via `google_sign_in` using the restricted `drive.file` scope.

---

## 🛠️ Tech Stack

| Component | Technology |
|---|---|
| **Framework** | Flutter (Dart 3) |
| **State Management** | `provider` (`ChangeNotifier`, `ProxyProvider`) |
| **Barcode / QR Scanner** | `mobile_scanner` |
| **Camera & Video** | `camera`, `path_provider` |
| **Cloud Storage** | Google Drive REST API v3 via `http` |
| **Authentication** | `google_sign_in` |
| **Persistence** | `shared_preferences` |

---

## 📂 Project Structure

```text
lib/
├── controllers/          # Recording session state controller
├── modules/
│   ├── history/          # Offline video playback & local storage history
│   ├── queue/            # Upload queue management UI & status filters
│   ├── recording/        # Camera view & video recording screen
│   ├── scanner/          # Barcode/QR camera scanner with confirmation dialog
│   ├── settings/         # Account management & storage statistics
│   └── storage/          # Local disk storage analytics
├── services/
│   ├── google_auth_service.dart   # Google Sign-In & token lifecycle
│   ├── google_drive_service.dart  # Drive folder trees & multipart video uploads
│   └── upload_queue_service.dart  # Persistent queue, auto-recovery & retry logic
├── ui/
│   └── home_screen.dart           # Home dashboard, stat cards & upload banner
├── utils/
│   └── order_id_parser.dart       # Regex engine for Daraz, TCS, LCS & AWBs
└── main.dart                      # App entry point, themes & dependency providers
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `^3.11.4` (or newer Dart 3.x compatible SDK)
- Android Studio / Xcode
- A Google Cloud Platform project with **Google Drive API** enabled

### 1. Clone the repository
```bash
git clone https://github.com/danish554554/packing_proof.git
cd packing_proof
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Google Sign-In Setup

#### Android
- Add your Android app package name and SHA-1 / SHA-256 fingerprint in your Firebase / Google Cloud Console.
- Ensure `google-services.json` is located in `android/app/google-services.json`.

#### iOS
- Add the iOS app in Firebase with the bundle identifier.
- Download `GoogleService-Info.plist` and place it in `ios/Runner/`.
- Add your `REVERSED_CLIENT_ID` into `ios/Runner/Info.plist` under `CFBundleURLTypes`.

### 4. Run the app
```bash
flutter run
```

---

## 📄 License
This project is private and proprietary.
