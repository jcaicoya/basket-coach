# Basket Coach – Firebase MVP (Firebase + Next.js PWA)

This is a concrete, build-ready plan for the first release. It includes backlog, data model, security rules, app structure, offline/PWA setup, testing, and CI/CD. You can use this as the project README.

---

## 1) Goals & Constraints

* **Devices:** laptop (home), phone/tablet (on-site). Works offline, syncs when online.
* **Scope:** private notes for training sessions (create/read/update/delete), tags, simple search, media attachments.
* **Time-to-MVP:** \~1 week focused build.
* **Tech:** Next.js 14 (App Router) + TypeScript, Firebase Auth + Firestore + Storage + Cloud Functions (optional extras), Firebase Hosting.

---

## 2) MVP Backlog (User Stories)

### Must-have (V1.0)

1. **Sign in/out** with Email/Password or Google.
2. **Create a session** (date, location, tags) while offline; sync later.
3. **Write notes** per session (rich text-lite / markdown, checklist, rating 1–5).
4. **Attach media** (photo/video) to a session or note.
5. **List sessions** with quick filters by tag/date; client-side search.
6. **Edit/delete** sessions and notes with conflict-safe updates.
7. **Installable PWA** with offline cache + IndexedDB persistence.
8. **Basic export**: download a session (JSON).

### Nice-to-have (V1.1 – next)

* Full-text search (Edge Function + index), templates for drills, share with assistant coach, CSV/Markdown export.

---

## 3) Data Model (Firestore, Storage)

**Collections (Firestore):**

* `users/{uid}` – profile
* `users/{uid}/sessions/{sessionId}`

  * `date: Timestamp`
  * `location: string`
  * `tags: string[]`
  * `createdAt: Timestamp` (server)
  * `updatedAt: Timestamp` (server)
* `users/{uid}/sessions/{sessionId}/notes/{noteId}`

  * `text: string` (markdown/plain)
  * `checklist: {text: string, done: boolean}[]`
  * `rating: number` (1–5)
  * `createdAt: Timestamp` (server)
  * `updatedAt: Timestamp` (server)
* (optional) `users/{uid}/mediaIndex/{mediaId}` to quickly list media across sessions

**Storage (Firebase Storage):**

* `media/{uid}/{sessionId}/{uuid}.{ext}` with metadata: `{noteId?, width?, height?, duration?}`

**Indexes (examples):**

* sessions: composite on `(date desc, tags array-contains)`
* notes: `(updatedAt desc)`

---

## 4) Security Rules (v1)

### Firestore rules (minimum viable, private per user)

```ts
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() { return request.auth != null; }
    function isOwner(uid) { return request.auth != null && request.auth.uid == uid; }

    match /users/{uid} {
      allow read, write: if isOwner(uid);

      match /sessions/{sessionId} {
        allow read, write: if isOwner(uid);
        match /notes/{noteId} {
          allow read, write: if isOwner(uid);
        }
      }

      match /mediaIndex/{mediaId} {
        allow read, write: if isOwner(uid);
      }
    }
  }
}
```

### Storage rules

```ts
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function isSignedIn() { return request.auth != null; }
    function parts(path) { return path.split('/'); }

    // Path: media/{uid}/{sessionId}/{file}
    match /media/{uid}/{sessionId}/{file} {
      allow read, write: if isSignedIn() && request.auth.uid == uid;
    }
  }
}
```

---

## 5) App Structure (Next.js 14 + TS)

```
apps/web/
├─ app/
│  ├─ (auth)/
│  │  ├─ sign-in/page.tsx
│  ├─ (app)/
│  │  ├─ layout.tsx
│  │  ├─ page.tsx                 # session list + quick filters
│  │  ├─ sessions/
│  │  │  ├─ new/page.tsx          # create session
│  │  │  ├─ [sessionId]/page.tsx  # session detail + notes
│  ├─ manifest.webmanifest
│  ├─ icon.png
├─ components/
│  ├─ SessionCard.tsx
│  ├─ NoteEditor.tsx (markdown + checklist)
│  ├─ MediaPicker.tsx (camera/gallery)
│  ├─ TagPicker.tsx
│  ├─ OfflineBadge.tsx
├─ lib/
│  ├─ firebase.ts                 # SDK init
│  ├─ db.ts                       # typed CRUD helpers
│  ├─ offline.ts                  # IndexedDB + queue
│  ├─ types.ts                    # TS types for data model
│  ├─ auth.ts                     # auth helpers
├─ public/
│  ├─ sw.js                      # service worker (workbox or custom)
├─ styles/
│  ├─ globals.css
├─ tests/
│  ├─ e2e/ (Playwright)
│  ├─ unit/
├─ package.json
```

---

## 6) Key Code (snippets)

### `lib/firebase.ts`

```ts
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore, enableIndexedDbPersistence } from 'firebase/firestore';
import { getStorage } from 'firebase/storage';

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY!,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN!,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID!,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET!,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID!,
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

// Offline cache (multi-tab safe)
enableIndexedDbPersistence(db).catch(() => {/* fallback ok */});
```

### Types (`lib/types.ts`)

```ts
export type Session = {
  id: string;
  date: Date;
  location?: string;
  tags: string[];
  createdAt: Date;
  updatedAt: Date;
};

export type Note = {
  id: string;
  text: string;
  checklist: { text: string; done: boolean }[];
  rating?: 1|2|3|4|5;
  createdAt: Date;
  updatedAt: Date;
};
```

### CRUD helpers (`lib/db.ts`)

```ts
import { db } from './firebase';
import {
  collection, doc, addDoc, setDoc, getDoc, getDocs, serverTimestamp,
  query, where, orderBy, limit, updateDoc, deleteDoc
} from 'firebase/firestore';

export const paths = {
  sessionsCol: (uid: string) => collection(db, `users/${uid}/sessions`),
  sessionDoc: (uid: string, sid: string) => doc(db, `users/${uid}/sessions/${sid}`),
  notesCol: (uid: string, sid: string) => collection(db, `users/${uid}/sessions/${sid}/notes`),
  noteDoc: (uid: string, sid: string, nid: string) => doc(db, `users/${uid}/sessions/${sid}/notes/${nid}`),
};

export async function createSession(uid: string, data: any){
  return addDoc(paths.sessionsCol(uid), { ...data, createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
}

export async function upsertNote(uid: string, sid: string, nid: string, data: any){
  return setDoc(paths.noteDoc(uid, sid, nid), { ...data, updatedAt: serverTimestamp() }, { merge: true });
}
```

### PWA manifest (`app/manifest.webmanifest`)

```json
{
  "name": "Basket Coach",
  "short_name": "BasketCoach",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#111827",
  "icons": [
    { "src": "/icon.png", "sizes": "512x512", "type": "image/png" }
  ]
}
```

### Simple service worker (public/sw\.js)

```js
self.addEventListener('install', (e) => { self.skipWaiting(); });
self.addEventListener('activate', (e) => { clients.claim(); });
// Optionally add runtime caching via Workbox in V1.1
```

---

## 7) Offline & Sync Strategy

* Firestore web SDK provides **offline persistence** automatically (IndexedDB).
* For **media uploads offline**: buffer in IndexedDB; enqueue upload when online.
* **Conflict handling**: last-write-wins per field (Firestore timestamps). In UI, show an “Offline” badge and a “Syncing…” state.

---

## 8) UX Flow

1. Open app → if offline, show cached session list.
2. Tap **New Session** → fill date/location/tags.
3. Add notes (markdown + checklist). Add media (camera/gallery).
4. Changes save locally; when online, sync to Firestore/Storage.
5. Session detail shows notes sorted by `updatedAt desc`.

---

## 9) Testing

* **Unit:** utilities and components (Vitest/RTL).
* **E2E:** Playwright: login flow (use emulator or stub), create/edit/delete session/note, offline mode (set `browserContext.setOffline(true)`).
* **Rules tests:** use Firestore Emulator to validate rules.

---

## 10) CI/CD

* **CI:** run lint, typecheck, tests on PRs.
* **CD:** merge to `main` → deploy preview (Firebase Hosting channels). Tag `v*` → promote to `prod`.

**GitHub Action (sample):**

```yaml
name: CI
on:
  push: { branches: [ main ] }
  pull_request: {}
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm run lint && npm run typecheck && npm test -- --ci
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          channelId: preview
          projectId: ${{ secrets.FIREBASE_PROJECT_ID }}
```

---

## 11) Environment & Emulators

**.env.local** (never commit):

```
NEXT_PUBLIC_FIREBASE_API_KEY=
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=
NEXT_PUBLIC_FIREBASE_PROJECT_ID=
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=
NEXT_PUBLIC_FIREBASE_APP_ID=
```

**Firebase Emulators** (for local dev):

* Firestore, Auth, Storage, Functions (if used). Configure via `firebase.json`.

---

## 12) Optional Cloud Functions (V1.1)

* **onUpload**: when media uploaded, extract metadata (duration/dimensions) → write to `mediaIndex`.
* **scheduled export**: nightly summary email/export (future).

**Skeleton:**

```ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
admin.initializeApp();

export const onMediaUpload = functions.storage.object().onFinalize(async (obj) => {
  const path = obj.name || '';
  const [_, uid, sessionId, file] = path.split('/');
  if (!uid || !sessionId) return;
  await admin.firestore().doc(`users/${uid}/mediaIndex/${file}`).set({
    sessionId, path, createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
});
```

---

## 13) Visual Design (quick)

* **List:** Cards by session with date, tags, note count, last updated.
* **Detail:** Sticky toolbar (Add note, Add media, Export), notes in reverse chrono.
* **Mobile-first:** large tap targets; offline banner; skeleton loaders.

---

## 14) Roadmap (V1.1+)

* Drill templates, timers, stopwatch.
* Share to specific users (RLS-like rules by adding `sharedWith` on `sessions`).
* Team mode (separate `teams/{teamId}/sessions`).
* Analytics: per-tag time, ratings over time.

---

## 15) Definition of Done (V1.0)

* Auth works on web + mobile PWA.
* Sessions/notes CRUD works offline and syncs online.
* Media capture/upload works; files are private by rules.
* Lighthouse PWA installable score ≥ 90.
* CI green; preview deploy from PR.

---

**Next step:** generate a minimal Next.js + Firebase starter with the files above and emulator setup.
