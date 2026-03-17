# Tabassum (Flutter + Firebase)

This workspace contains the app source in `tabassum_app/`.  
Flutter SDK is **not** available in this environment, so platform folders (`android/`, `ios/`, etc.) are intentionally not generated here.

## 1) Install Flutter locally

Install Flutter on your Linux machine (Fedora works well) and verify:

```bash
flutter --version
flutter doctor
```

## 2) Generate platform scaffolding

From inside `tabassum_app/`, generate the missing platform folders:

```bash
cd tabassum_app
flutter create .
```

## 3) Create a Firebase project

- Firebase Console: create a project
- Enable **Authentication**: Email/Password
- Create **Firestore** database
- Create **Storage** bucket

## 4) Configure FlutterFire

Install FlutterFire CLI (once):

```bash
dart pub global activate flutterfire_cli
```

Then configure (this creates `lib/firebase_options.dart`):

```bash
cd tabassum_app
flutter pub get
flutterfire configure
```

## 5) Run

```bash
cd tabassum_app
flutter run
```

## Firestore collections (MVP)

- `users/{uid}`
  - `email`
  - `role`: `customer` | `seller`
  - `createdAt`
- `shops/{id}`
  - `name`
  - `ownerId`
  - `gender`: `male` | `female`
  - `telegram`
  - `about`
  - `phone`
  - `image` (download URL)
- `categories/{id}`
  - `name`
  - `gender`: `male` | `female`
- `products/{id}`
  - `shopId`
  - `categoryId`
  - `name`
  - `price` (integer)
  - `stock` (integer)
  - `image` (download URL)
- `wishlist/{id}`
  - `userId`
  - `productId`
  - `shopId`
- `sales/{id}`
  - `shopId`
  - `productId`
  - `quantity` (integer)
  - `price` (integer)
  - `date`
- `subscriptions/{shopId}`
  - `shopId`
  - `startDate`
  - `endDate`
  - `status`: `active` | `inactive`
- `payments/{id}`
  - `shopId`
  - `amount`
  - `method`
  - `date`

## Security rules templates

See `firebase/firestore.rules` and `firebase/storage.rules` (templates you can adapt).
