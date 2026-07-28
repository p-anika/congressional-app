# FoodRescue — Congressional App

A Flutter food rescue and donation platform connecting restaurants with people in need.

---

## Setup Steps

### 1. Flutter & Dependencies

```bash
flutter pub get
```

Requires Flutter 3.22+ and Dart 3.12+.

---

### 2. Firebase Project Configuration

1. Go to [Firebase Console](https://console.firebase.google.com) and create a new project.
2. Enable **Authentication** → Email/Password sign-in method.
3. Enable **Firestore Database** (start in production mode, then update rules as needed).
4. Register your apps:
   - **Android**: Add app with package name `com.example.congressional_app`, download `google-services.json` → place in `android/app/`.
   - **iOS**: Add app with bundle ID, download `GoogleService-Info.plist` → place in `ios/Runner/` via Xcode.
5. Install the FlutterFire CLI and run:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart`. Update `main.dart` to pass options:

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

#### Firestore Security Rules (starter)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }
    match /restaurants/{id} {
      allow read: if request.auth != null;
      allow write: if request.auth != null &&
        (resource == null || resource.data.ownerId == request.auth.uid);
    }
    // NEW: ADD THIS VOLUNTEERS BLOCK TO Firebase Console → Firestore → Rules tab
      match /volunteers/{uid} {
        allow read: if request.auth.uid == uid;
        allow write: if request.auth.uid == uid;
      }
    //
    match /foodListings/{id} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    // NEW: ADD THIS MEAL PURCHASES BLOCK TO Firebase Console → Firestore → Rules tab
      match /mealPurchases/{id} {
        allow read: if request.auth != null;
        allow create: if request.auth != null;
        allow update, delete: if false; // append-only ledger
      }
    //
    // NEW: ADD THIS PORTION CLAIMS BLOCK TO Firebase Console → Firestore → Rules tab
      match /portionClaims/{id} {
        allow read: if request.auth != null;
        allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
        allow update: if request.auth != null; // restaurant marks completed
      }
    //
  }
}
```

---

### 3. Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com) → APIs & Services → Enable:
   - **Maps SDK for Android**
   - **Maps SDK for iOS**
   - **Geocoding API**
2. Create an API key and restrict it to your app's bundle ID / SHA-1.

#### Android

Add to `android/app/src/main/AndroidManifest.xml` inside `<application>`:

```xml
<meta-data
  android:name="com.google.android.geo.API_KEY"
  android:value="YOUR_API_KEY_HERE"/>
```

Also set `minSdkVersion 21` in `android/app/build.gradle`.

#### iOS

Add to `ios/Runner/AppDelegate.swift`:

```swift
import GoogleMaps
// In application(_:didFinishLaunchingWithOptions:)
GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
```

Add location permission strings to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>FoodRescue needs your location to show nearby food.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>FoodRescue needs your location to show nearby food.</string>
```

For Android, add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

---

### 4. How to Manually Verify a Restaurant in Firestore

Restaurant verification is admin-only — the app reads `isVerified` but never writes it from the client.

1. Open Firebase Console → Firestore → `restaurants` collection.
2. Find the restaurant document (query by `ownerId` or `name`).
3. Set the `isVerified` field to `true`.
4. The restaurant's listings will immediately appear on the Map and List screens for all users.

---

## Project Structure

```
lib/
  models/           # Restaurant, FoodListing, AppUser
  providers/        # AuthProvider, RestaurantProvider, FoodListingProvider, UserProvider
  screens/
    restaurant/     # Auth, Home, Listings, Profile
    user/           # Auth, Home, Map, List, MyInfo, RestaurantDetail
  services/         # FirebaseService, LocationService
  widgets/          # AllergenChips, AllergenSelector, FoodListingCard
  theme.dart        # AppColors + buildAppTheme()
  main.dart

assets/
  images/           # Drop logo.png here (see assets/images/README.md)
```

---

## Firebase Collections

| Collection     | Key fields |
|----------------|------------|
| `users`        | id, email, role, allergies, location, phone |
| `restaurants`  | id, name, address, lat, lng, contactInfo, hoursOfOperation, isVerified, ownerId |
| `foodListings` | id, restaurantId, item, amount, feedsPeople, allergens, contains, isAvailable, createdAt, expiresAt |

---

## Notes

- No payment integration — this version is free pickup only.
- All Firestore data uses real-time `snapshots()` streams.
- Allergen warnings are shown (not hidden) — restaurants with conflicting allergens display a warning badge.
- Restaurant verification is manual: set `isVerified = true` directly in Firestore.
