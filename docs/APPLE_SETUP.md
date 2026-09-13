# Ship Lyklaborð on your Apple team

Do this on **tommipals@gmail.com**, team **`45BXWF6V3P`**. Bundle IDs are the
ones you already own (`com.supermassiveapps.lyklabord` + keyboard / group /
iCloud / IAP). Do not copy Jökull’s ASC App ID, API keys, or TestFlight
groups.

You need: a paid Apple Developer Program membership, a Mac with **Xcode 26+**,
and this git checkout.

---

## Identifiers (already in the repo)

Create **these exact strings** in Apple’s portals. If you change a string,
change the repo to match.

| What | Value | Where it lives |
| --- | --- | --- |
| Team | `45BXWF6V3P` | `project.yml`, `docs/TestFlightExportOptions.plist` |
| App bundle ID | `com.supermassiveapps.lyklabord` | `project.yml` |
| Keyboard bundle ID | `com.supermassiveapps.lyklabord.keyboard` | `project.yml` |
| App Group | `group.com.supermassiveapps.lyklabord` | entitlements + `App/AppModel.swift` |
| iCloud container | `iCloud.com.supermassiveapps.lyklabord` | entitlements + `SyncActivation` |
| IAP product | `com.supermassiveapps.lyklabord.plus.annual` | `SubscriptionManager` + `.storekit` |
| ReplayHost (local only) | `com.supermassiveapps.lyklabord.replayhost` | `project.yml` — do not ship |

You mint later (write them down; they are **not** in git):

| What | Env / secret |
| --- | --- |
| ASC numeric App ID | `APP_ID` / `APP_STORE_CONNECT_APP_ID` |
| API key ID | `ASC_KEY_ID` / `APP_STORE_CONNECT_API_KEY_ID` |
| API issuer ID | `ASC_ISSUER_ID` / `APP_STORE_CONNECT_ISSUER_ID` |
| API `.p8` PEM | `ASC_KEY_PATH` / `APP_STORE_CONNECT_API_KEY` |
| Internal TestFlight group UUID | `INTERNAL_GROUP_ID` |
| External TestFlight group UUID | `EXTERNAL_GROUP_ID` (optional) |

---

## 1. Confirm the team

1. Open [developer.apple.com/account](https://developer.apple.com/account) as **tommipals@gmail.com**.
2. Top-right membership = **45BXWF6V3P**. If you see another team, switch.
3. [Agreements](https://developer.apple.com/account/resources/agreements/list): accept **Paid Applications** if you will sell Lyklaborð+ (banking/tax too).

---

## 2. Register identifiers

[Certificates, Identifiers & Profiles → Identifiers](https://developer.apple.com/account/resources/identifiers/list)

If `com.supermassiveapps.lyklabord` (and group / iCloud / keyboard) already
exist on **this** team, skip Register — just confirm App Groups + iCloud +
IAP are attached. If Register says another team owns an ID, transfer that
App ID onto `45BXWF6V3P` (Apple: App Transfer / identifier transfer).

### 2a. App Group

1. **+** → **App Groups** → Continue.
2. Description: `Lyklaborð`. Identifier: `group.com.supermassiveapps.lyklabord`.
3. Register.

### 2b. iCloud container

1. **+** → **iCloud Containers** → Continue.
2. Description: `Lyklaborð`. Identifier: `iCloud.com.supermassiveapps.lyklabord`.
3. Register.

### 2c. App ID (containing app)

1. **+** → **App IDs** → App → Continue.
2. Description: `Lyklaborð`. Bundle ID: **Explicit** `com.supermassiveapps.lyklabord`.
3. Enable: **App Groups**, **iCloud** (include CloudKit + iCloud Documents), **In-App Purchase**, **Push Notifications** off.
4. Register → Configure:
   - App Groups → `group.com.supermassiveapps.lyklabord`
   - iCloud → `iCloud.com.supermassiveapps.lyklabord`

### 2d. App ID (keyboard)

1. **+** → **App IDs** → App → Continue.
2. Description: `Lyklaborð Keyboard`. Bundle ID: **Explicit** `com.supermassiveapps.lyklabord.keyboard`.
3. Enable **App Groups** only. No iCloud, no IAP (extension stays offline).
4. Register → App Groups → `group.com.supermassiveapps.lyklabord`.

Automatic signing can create these on first archive if you skip 2a–2d. Doing them by hand avoids a mid-Cloud failure.

---

## 3. Create the App Store Connect record

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Apps**.
   If Lyklaborð already exists on this team with bundle
   `com.supermassiveapps.lyklabord`, reuse it — copy its numeric Apple ID
   (`APP_ID`) and skip New App. Otherwise **+** → New App.
2. Platform **iOS**. Name **Lyklaborð** (if taken, `Lyklaborð IS` or similar — you can localize later).
3. Primary language **English (US)**. Bundle ID **`com.supermassiveapps.lyklabord`**. SKU `lyklabord-ios`.
4. User Access: Full Access.
5. Copy the numeric **Apple ID** from App Information (digits, not the bundle ID). That is `APP_ID`.
6. If this bundle already has uploaded builds, set Xcode Cloud **Next Build
   Number** (and `CURRENT_PROJECT_VERSION`) above the last one. Fresh record
   stays at `1`.

### 3a. TestFlight groups

1. App → **TestFlight** → **Groups** → Create **Internal** (e.g. `Internal`). Add yourself.
2. Optional: External group after the first build exists.
3. Copy each group’s UUID from the group URL (`…/groups/<uuid>/…`) → `INTERNAL_GROUP_ID` / `EXTERNAL_GROUP_ID`.

### 3b. Lyklaborð+ (skip until you want IAP)

1. **Subscriptions** → Subscription Group `Lyklaborð+`.
2. Product ID **`com.supermassiveapps.lyklabord.plus.annual`**, 1 year, ~USD 19.99. Must match `SubscriptionManager.productID`.

---

## 4. Mac — generate the project and sign in

In the repo root:

```bash
brew install xcodegen
xcodegen generate
open Lyklabord.xcodeproj
```

In Xcode:

1. **Xcode → Settings → Accounts** → add **tommipals@gmail.com**. Team **45BXWF6V3P**.
2. Target **Lyklabord** → Signing & Capabilities: Team **45BXWF6V3P**, bundle `com.supermassiveapps.lyklabord`.
3. Target **LyklabordKeyboard**: same team, bundle `com.supermassiveapps.lyklabord.keyboard`.
4. If signing errors, click **Try Again** (automatic signing writes provisioning profiles).

You should **not** see team `RDC8539AWM`.

---

## 5. Xcode Cloud (the ship path)

Workflows live in App Store Connect, not git. `ci_scripts/` already generate the gitignored `.xcodeproj` and lock app/keyboard versions.

1. Xcode (project open, you signed in) → **Integrate → Xcode Cloud → Create Workflow**.
2. Product: Lyklabord. Grant GitHub access to **`tomas-pals/LyklabordApp`** (this repo, not Jökull’s).
3. Workflow:
   - Name: `TestFlight`
   - Start condition: **Branch Changes** → `main` (or this PR branch for a first dry run)
   - Archive: **iOS**, Release, scheme **Lyklabord**
   - Post-Actions: **TestFlight Internal Testing** → your Internal group
   - Xcode version: **latest 26+**
4. [App Store Connect → your app → Xcode Cloud → Settings](https://appstoreconnect.apple.com): **Next Build Number** = `1` (new record; `project.yml` is `1`).
5. **Start Build**. First run is often 1h+ (cold cache). Later ~30–60 min. Included quota: 25 compute hours/month.

`ci_post_clone.sh` runs `git lfs pull` then `xcodegen generate`. If Cloud can’t see GitHub LFS, the ~110MB `data/is/bin-morph.bin` stays a pointer and the keyboard ships broken — fix GitHub access, don’t skip LFS.

---

## 6. GitHub Actions fallback (optional)

Only if you want a manual `workflow_dispatch` ship. Do **not** enable a push trigger (would double-upload next to Cloud).

1. [appstoreconnect.apple.com → Users and Access → Integrations → Team Keys](https://appstoreconnect.apple.com/access/integrations/api) → **Generate API Key**.
   - Name: `lyklabord-ci`. Access: **App Manager**.
   - Download the `.p8` once. Note **Key ID** and **Issuer ID**.
2. GitHub → this repo → **Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `APP_STORE_CONNECT_API_KEY` | full PEM text of the `.p8` |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |
| `APP_STORE_CONNECT_APP_ID` | numeric Apple ID from step 3 |
| `APP_STORE_CONNECT_INTERNAL_GROUP_ID` | optional |
| `APP_STORE_CONNECT_EXTERNAL_GROUP_ID` | optional |

3. **Actions → TestFlight → Run workflow**.

Local equivalent (same secrets as env):

```bash
export APP_ID=… ASC_KEY_ID=… ASC_ISSUER_ID=…
export ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
DRY_RUN=1 ./scripts/testflight-release.sh   # plan only
./scripts/testflight-release.sh             # real archive + upload
```

---

## 7. After the first Cloud build

1. TestFlight → Internal: install on your phone, add Lyklaborð in Settings → Keyboards.
2. Confirm App Store Connect → Xcode Cloud usage (25h/month included).
3. External testers: attach the External group; Beta App Review may be required.

Headless command details: [`TESTFLIGHT.md`](TESTFLIGHT.md). Store listing copy: [`store/`](../store/).

---

## Checklist

- [ ] Signed into Apple as tommipals@gmail.com / `45BXWF6V3P`
- [ ] App Group + iCloud container + both App IDs registered
- [ ] New ASC app on bundle `com.supermassiveapps.lyklabord`; numeric `APP_ID` saved
- [ ] Internal TestFlight group created
- [ ] `xcodegen generate` + Xcode signing shows **your** team
- [ ] Xcode Cloud workflow on **this** GitHub repo
- [ ] Next Build Number = 1
- [ ] First Cloud archive in TestFlight
- [ ] (Optional) your `.p8` in GitHub secrets — never Jökull’s
