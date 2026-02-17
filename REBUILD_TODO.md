# TranZfort User App — Full Rebuild TODO

**Created:** Feb 6, 2026
**Last Updated:** Feb 7, 2026 (Build Progress — Phases 0-19 COMPLETE except 10.1 deferred)
**Purpose:** Rebuild the TranZfort user app from scratch with improved architecture, UX, and visual design
**Reference Docs:** `docs/new-product-one-pager.md`, `docs/01-design-system.md`, `docs/02-auth-flow.md`, `docs/03-supplier-screens.md`, `docs/04-trucker-screens.md`, `docs/06-tech-architecture.md`, `docs/07-database-schema.md`, `docs/09-coding-standards.md`, `docs/10-api-integration.md`, `docs/12-ui-ux-implementation-guide.md`, `docs/user-app-improvement.md`, `docs/codebase-review.md`
**Admin App Reference:** `Admin/` folder (shares architecture patterns, Supabase config, dependencies)

### CTO/CPO Review Notes (v2 Improvements)
> The following improvements are baked into this TODO. They do NOT remove any existing features.
> They improve: visual hierarchy, text/bg contrast, scroll smoothness, centralised theming,
> city data quality, layout consistency, micro-interactions, error recovery, and future-proofing.
>
> **Design philosophy:** Clean, high-contrast light theme. Cards float on a warm neutral background.
> Teal is the trust color (CTAs, active states). Orange is the energy color (Super Loads, urgency).
> Glass effects are subtle — never obscure readability. Every screen scrolls with `BouncingScrollPhysics`.
> Every list supports pull-to-refresh. Every action gives tactile + visual feedback.

---

## PHASE 0: Project Scaffolding & Configuration ✅

### 0.1 Flutter Project Init
- [x] Create Flutter project in `TranZfort/` folder: `flutter create --org com.tranzfort --project-name tranzfort TranZfort`
- [x] SDK constraint: `sdk: ^3.10.7`
- [x] Set `publish_to: 'none'`

### 0.2 Dependencies (pubspec.yaml)
**Core:**
- [x] `supabase_flutter: ^2.5.6`
- [x] `flutter_riverpod: ^2.5.1`
- [x] `go_router: ^14.2.0`
- [x] `google_fonts: ^6.2.1`
- [x] `riverpod_annotation: ^2.3.5`
- [x] `intl: ^0.19.0`
- [x] `uuid: ^4.4.0`

**UI/UX (NEW — v2):**
- [x] `shimmer: ^3.0.0` — skeleton loading effects (replaces manual shimmer impl)
- [x] `cached_network_image: ^3.3.1` — avatar/image caching with placeholder + error widget
- [x] `flutter_animate: ^4.5.0` — declarative staggered animations for list items, page transitions
- [x] `smooth_page_indicator: ^1.1.0` — wizard step indicators (Post Load, Verification)
- [x] `flutter_svg: ^2.0.10` — SVG icon/illustration support for empty states
- [x] `connectivity_plus: ^6.0.3` — offline detection banner
- [x] `pull_to_refresh_flutter3: ^2.0.2` — consistent pull-to-refresh across all list screens

**Voice & TTS (NEW — v3):**
- [x] `flutter_tts: ^4.0.2` — platform-native TTS (uses Google TTS on Android, AVSpeech on iOS — ~50KB, no bundled voices)
- [x] `record: ^5.1.2` — cross-platform audio recording for voice messages (native APIs, small footprint)
- [x] `just_audio: ^0.9.39` — audio playback for voice message bubbles (streaming from signed URLs)

**Localization (NEW — v3):**
- [x] `flutter_localizations: sdk: flutter` — built-in Material/Cupertino localization delegates
- [x] `intl: ^0.19.0` — already listed above (used for ARB code generation)

**Permissions (NEW — v3):**
- [x] `permission_handler: ^11.3.1` — unified runtime permission API for Camera, Mic, Location, Notifications

**Utilities:**
- [x] `url_launcher: ^6.3.0`
- [x] `image_picker: ^1.1.2`
- [x] `shared_preferences: ^2.2.3`
- [x] `path_provider: ^2.1.3` — local cache directory for city data
- [x] `collection: ^1.18.0` — groupBy for chat list grouping by load

**Dev deps:**
- [x] `flutter_lints`, `build_runner`, `riverpod_generator`, `custom_lint`, `riverpod_lint`

### 0.3 Platform Configs
- [x] **Android:** `namespace = "com.tranzfort.user"`, `applicationId = "com.tranzfort.user"`, `android:label = "TranZfort"`
- [x] **Android Kotlin:** Package dir `com/tranzfort/user/MainActivity.kt`
- [x] **iOS:** `CFBundleDisplayName = "TranZfort"`, `PRODUCT_BUNDLE_IDENTIFIER = com.tranzfort.user`
- [x] **Windows:** `CMakeLists.txt` project name `TranZfort`, `Runner.rc` FileDescription `TranZfort`
- [x] **Linux:** `CMakeLists.txt` BINARY_NAME `TranZfort`, APPLICATION_ID `com.tranzfort.user`

### 0.4 Assets
- [x] Copy logo files: `logo-tranzfort-transparent.png`, `icon-user.jpg`
- [x] Add assets section to `pubspec.yaml`
- [x] Add SVG illustrations for empty states (truck, load, chat, fleet)

### 0.5 City Data — `assets/data/indian_locations.json` (EXPANDED — v2)
> **Goal:** Comprehensive Indian location database, structured for current search AND future LLM tool-calling.
> The old plan was ~5000 cities. The new plan is ~8000+ locations with sub-cities, districts, and transport hubs.

- [x] **Data structure (AI-friendly schema):**
  ```json
  {
    "version": "1.0",
    "generated": "2026-02-06",
    "description": "Indian locations for logistics route search. Includes cities, districts, sub-cities, and major transport hubs.",
    "schema": {
      "name": "Display name",
      "state": "State/UT name",
      "district": "District name (nullable)",
      "type": "city | district_hq | sub_city | transport_hub | industrial_zone",
      "lat": "Latitude (float)",
      "lng": "Longitude (float)",
      "aliases": ["Alternative names / local spellings"],
      "pincode_prefix": "First 2-3 digits of area pincode (for grouping)",
      "is_major_hub": "boolean — true for top 100 logistics cities"
    },
    "locations": [ ... ]
  }
  ```
- [x] **Data sources to scrape/compile at build time:**
  - India Post pincode directory (public) — all post offices → extract unique cities/towns
  - Census 2011 town list (public) — ~8000 towns with population > 10,000
  - National Highways Authority (NHAI) — major transport hubs and toll plazas
  - Indian Railways station list — junction cities (logistics-relevant)
  - Industrial corridors: DMIC, CBIC, AKIC zones
  - Mandi (agricultural market) locations — critical for agri-load suppliers
- [x] **Minimum coverage:**
  - All state capitals (29 + 8 UTs)
  - All district headquarters (~770)
  - All cities with population > 50,000 (~500)
  - All towns with population > 10,000 (~5,000)
  - Major sub-cities / satellite towns (e.g., Gurugram under Haryana, Navi Mumbai under Maharashtra)
  - Top 200 industrial zones / SEZs
  - Top 100 mandis (agricultural markets)
  - Major port cities (13 major + 200 minor ports)
- [x] **Aliases for fuzzy search:**
  - Bengaluru ↔ Bangalore, Mumbai ↔ Bombay, Kolkata ↔ Calcutta, Chennai ↔ Madras
  - Thiruvananthapuram ↔ Trivandrum, Kochi ↔ Cochin, Varanasi ↔ Banaras
  - Local language names where commonly used
- [x] **AI/LLM tool-call readiness:**
  - Top-level `description` field explains the dataset purpose (for LLM context injection)
  - `schema` field documents every key (LLM can parse structure without examples)
  - `type` field enables LLM to filter (e.g., "find all transport hubs in Gujarat")
  - `is_major_hub` enables LLM to suggest popular routes
  - `aliases` enables fuzzy matching (LLM can map user input "Blore" → "Bengaluru")
  - Flat array (no nesting) — easy for LLM function calling to iterate/filter
- [x] **Search service improvements:**
  - Fuzzy search: match against `name`, `aliases[]`, `district`, `state`
  - Weighted ranking: exact match > starts-with > contains > alias match
  - `is_major_hub` results boosted to top
  - Debounced input (300ms) to avoid excessive filtering on large dataset
  - Lazy-load JSON on first search (not app startup) — keep splash fast
  - Cache parsed list in memory after first load

---

## PHASE 1: Core Layer (`lib/src/core/`) ✅

### 1.1 Config — `core/config/supabase_config.dart`
- [x] `SupabaseConfig` class with `supabaseUrl` and `supabaseAnonKey` (from `String.fromEnvironment` with defaults)
- [x] Keep default values so app runs without `--dart-define`
- [x] Logger name: `TranZfort`

### 1.2 Constants (IMPROVED — v2)

- [x] **`core/constants/app_colors.dart`** — Centralised design tokens
  ```
  ─── BRAND ───
  Brand Teal:          #0F6F69  (primary CTA, active nav, links)
  Brand Teal Light:    #E6F5F3  (teal tint for selected chips, subtle highlights)
  Brand Teal Dark:     #0A4F4A  (pressed state, text-on-light-teal-bg)
  Brand Orange:        #D97706  (Super Load accent, urgency, secondary CTA)
  Brand Orange Light:  #FEF3C7  (Super Load card glow background)
  Brand Orange Dark:   #B45309  (pressed state for orange elements)

  ─── BACKGROUNDS (warm neutral — NOT pure white) ───
  Scaffold BG:         #F5F5F0  (warm off-white — easier on eyes than #F8FAFC)
  Card BG:             #FFFFFF  (pure white cards float on warm bg — high contrast)
  Card BG Elevated:    #FFFFFF with elevation shadow
  Surface Glass:       rgba(255, 255, 255, 0.85)  (increased from 0.75 for readability)
  Surface Glass Border: rgba(255, 255, 255, 0.40)  (increased from 0.30)
  Input BG:            #FAFAFA  (very light grey — distinguishes from card bg)

  ─── TEXT (high contrast — WCAG AA compliant) ───
  Text Primary:        #1A1A2E  (near-black with warmth — 4.5:1+ on all backgrounds)
  Text Secondary:      #5A6178  (darker than old #64748B — better readability)
  Text Tertiary:       #8E95A9  (captions, timestamps, placeholders)
  Text On Teal:        #FFFFFF  (white on teal buttons)
  Text On Card:        #1A1A2E  (same as primary — consistency)

  ─── BORDERS & DIVIDERS ───
  Border Default:      #E0E4EA  (slightly warmer than old #E2E8F0)
  Border Focus:        #0F6F69  (teal — clear focus indicator)
  Divider:             #F0F1F3  (very subtle — for list separators)

  ─── SEMANTIC ───
  Error:               #DC2626  (slightly darker red — better contrast)
  Error Light:         #FEF2F2  (error background tint)
  Success:             #059669  (slightly darker green — better contrast)
  Success Light:       #ECFDF5  (success background tint)
  Warning:             #D97706  (reuse brand orange)
  Warning Light:       #FFFBEB
  Info:                #2563EB  (blue for informational)
  Info Light:          #EFF6FF

  ─── GRADIENTS ───
  TranZfort Gradient:  LinearGradient(begin: topLeft, end: bottomRight, colors: [#0F6F69, #D97706])
  Glass Gradient:      LinearGradient(colors: [white.withOpacity(0.40), white.withOpacity(0.20)])
  Super Load Glow:     BoxShadow(color: #D97706.withOpacity(0.25), blurRadius: 16, spreadRadius: 2)
  Card Shadow:         BoxShadow(color: #000000.withOpacity(0.06), blurRadius: 12, offset: (0, 4))
  Elevated Shadow:     BoxShadow(color: #000000.withOpacity(0.10), blurRadius: 20, offset: (0, 8))
  ```

- [x] **`core/constants/app_spacing.dart`** — 8px grid system
  ```
  ─── SPACING ───
  xxs: 2, xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32, xxxl: 48

  ─── COMPONENT TOKENS ───
  Screen Padding:      horizontal 20, vertical 16  (generous breathing room)
  Card Padding:        16 all sides
  Card Radius:         16
  Card Gap:            12  (between stacked cards)
  Button Radius:       12
  Button Height:       52  (comfortable tap target — 48px minimum + padding)
  Input Radius:        12
  Input Height:        56  (Material 3 standard)
  Chip Radius:         20  (pill shape)
  Chip Height:         36
  Bottom Nav Height:   72  (64 + safe area padding)
  Drawer Width:        300
  Avatar Small:        40
  Avatar Medium:       52
  Avatar Large:        80
  Glass Blur Sigma:    12.0  (reduced from 15 — less heavy, more performant)

  ─── ANIMATION DURATIONS ───
  Fast:                150ms  (button press, chip toggle)
  Normal:              250ms  (page transitions, card expand)
  Slow:                400ms  (drawer open, modal appear)
  Stagger Delay:       50ms   (per-item delay in list animations)
  ```

- [x] **`core/constants/app_typography.dart`** — Inter font, high contrast
  ```
  H1 Hero:       Bold 700,     26px, lineHeight 34, letterSpacing -0.5  (bumped from 24)
  H2 Section:    SemiBold 600, 20px, lineHeight 28, letterSpacing -0.3
  H3 Subsection: SemiBold 600, 17px, lineHeight 24, letterSpacing -0.2
  Body Large:    Regular 400,  16px, lineHeight 24
  Body Medium:   Regular 400,  14px, lineHeight 20
  Body Small:    Regular 400,  13px, lineHeight 18  (NEW — for dense info rows)
  Caption:       Medium 500,   12px, lineHeight 16, letterSpacing 0.2
  Overline:      SemiBold 600, 11px, lineHeight 14, letterSpacing 0.8, UPPERCASE  (NEW — section labels)
  Button Large:  SemiBold 600, 16px, lineHeight 24
  Button Small:  Medium 500,   14px, lineHeight 20  (NEW — for secondary/text buttons)
  Number:        Bold 700,     20px, lineHeight 28, tabularFigures  (NEW — stats, counts, prices)
  ```
  - All text colors default to `Text Primary` (#1A1A2E) unless explicitly overridden
  - Price text always uses `Number` style with `₹` prefix
  - Route text ("Delhi → Mumbai") uses `H3` with `→` arrow character

### 1.3 Theme — `core/theme/app_theme.dart` (IMPROVED — v2)
- [x] **Light theme only** — centralised `ThemeData` that ALL widgets inherit from
- [x] **Font:** Inter via `google_fonts` — set as default in `TextTheme`
- [x] **ColorScheme:** `ColorScheme.light()` seeded from Brand Teal
  - `primary`: Brand Teal, `secondary`: Brand Orange
  - `surface`: Card BG (#FFFFFF), `background`: Scaffold BG (#F5F5F0)
  - `error`: Error (#DC2626), `onPrimary`: white, `onSurface`: Text Primary
- [x] **AppBar theme:** `backgroundColor: transparent`, `elevation: 0`, `scrolledUnderElevation: 0`, `foregroundColor: Text Primary`, `titleTextStyle: H3`
- [x] **Card theme:** `elevation: 0`, `color: Card BG`, `shape: RoundedRectangleBorder(radius: 16)`, `margin: EdgeInsets.zero`
- [x] **Input theme:** `filled: true`, `fillColor: Input BG`, `border: OutlineInputBorder(radius: 12)`, `focusedBorder: teal`, `contentPadding: EdgeInsets.symmetric(h: 16, v: 16)`, `floatingLabelStyle: teal`
- [x] **Elevated Button theme:** height 52, radius 12, `backgroundColor: Brand Teal`, `foregroundColor: white`, `textStyle: Button Large`
- [x] **Text Button theme:** `foregroundColor: Brand Teal`, `textStyle: Button Small`
- [x] **Chip theme:** `backgroundColor: Brand Teal Light`, `selectedColor: Brand Teal`, `labelStyle: Body Small`, `shape: StadiumBorder`, `side: BorderSide.none`
- [x] **Bottom Nav theme:** `backgroundColor: Colors.white`, `selectedItemColor: Brand Teal`, `unselectedItemColor: Text Tertiary`, `elevation: 8`
- [x] **Divider theme:** `color: Divider`, `thickness: 1`, `space: 0`
- [x] **Snackbar theme:** `behavior: floating`, `shape: RoundedRectangleBorder(radius: 12)`, `backgroundColor: Text Primary`
- [x] **Scroll physics:** Set `BouncingScrollPhysics` as default via `ScrollConfiguration` wrapper in `MaterialApp`
- [x] **Page transitions:** Use `flutter_animate` for fade+slide transitions (200ms) on route changes

### 1.4 Services
- [x] **`core/services/auth_service.dart`**
  - `signUpWithEmail(email, password, fullName, mobile)` — creates auth user, profile row via trigger
  - `signInWithPassword(identifier, password)` — auto-detect email vs mobile
  - `signInWithOtp(mobile)` — send OTP
  - `verifyOtp(mobile, otp)` — verify OTP
  - `signOut()` — `SignOutScope.local`
  - `resetPasswordForEmail(email)`
  - `getUserRole()` — query `profiles.current_role`
  - `updateUserRole(role)` — update `profiles.current_role`
  - `getUserProfile()` — full profile data
  - `ensureProfileExists()` — create profile row if missing (for phone OTP auto-signup)
  - `get currentUser` — `supabase.auth.currentUser`
  - `get authStateChanges` — `supabase.auth.onAuthStateChange`

- [x] **`core/services/database_service.dart`**
  - **Profiles:** `getUserProfile(userId)`, `updateProfile(userId, data)`, `getPublicProfile(userId)`
  - **Suppliers:** `getSupplierData(userId)`, `createSupplierData(userId, data)`, `updateSupplierData(userId, data)`
  - **Truckers:** `getTruckerData(userId)`, `createTruckerData(userId, data)`, `updateTruckerData(userId, data)`
  - **Loads:** `getActiveLoads(filters)`, `getLoadById(id)`, `createLoad(data)`, `updateLoad(id, data)`, `getMyLoads(supplierId)`, `incrementLoadViews(loadId)`, `searchLoads(from, to, filters)`
  - **Trucks:** `getMyTrucks(ownerId)`, `addTruck(data)`, `getTruckById(id)`, `getVerifiedTrucks(ownerId)`
  - **Conversations:** `getConversationsByUser(userId)`, `getOrCreateConversation(loadId, supplierId, truckerId)`, `getConversationById(id)`
  - **Messages:** `getMessages(conversationId)`, `sendMessage(conversationId, senderId, type, text, payload)`, `markAsRead(messageId)`, `subscribeToMessages(conversationId, callback)` — Realtime
  - **Payout:** `getPayoutProfile(userId)`, `createPayoutProfile(userId, data)`, `updatePayoutProfile(id, data)`
  - **Super Loads:** `requestSuperLoad(loadId)`, `getSuperLoads(supplierId)`, `updateSuperLoadStatus(loadId, status)`
  - **Support:** `createTicket(userId, subject, description)`, `getMyTickets(userId)`
  - **Cities:** `searchCities(query)` — from bundled JSON
  - **Name resolution:** Select `full_name` with `email` prefix fallback

- [x] **`core/services/storage_service.dart`**
  - `uploadFile(bucket, path, file)` — upload to Supabase Storage
  - `getSignedUrl(bucket, path, expiresIn)` — 1-hour signed URLs for RC docs
  - Buckets: `verification-docs`, `truck-images`, `avatars`
  - Image resize before upload (max 1200px width, 80% quality)

### 1.5 Models — `core/models/`
- [x] **`load_model.dart`** — id, supplierId, originCity, originState, destCity, destState, material, weightTonnes, requiredTruckType, requiredTyres[], price, priceType (fixed/negotiable), advancePercentage, pickupDate, status, isSuperLoad, superStatus, assignedTruckerId, assignedTruckId, podPhotoUrl, lrPhotoUrl, viewsCount, responsesCount, createdAt, updatedAt, expiresAt, completedAt. `fromJson()`, `toJson()`
- [x] **`truck_model.dart`** — id, ownerId, truckNumber, bodyType (open/container/trailer/tanker), tyres, capacityTonnes, rcPhotoUrl, status (pending/verified/rejected), rejectionReason, verifiedAt, createdAt. `fromJson()`, `toJson()`
- [x] **`conversation_model.dart`** — id, loadId, supplierId, truckerId, isActive, lastMessageAt, lastMessage, supplierName, truckerName, unreadCount, createdAt. `fromJson()`, `toJson()`
- [x] **`message_model.dart`** — id, conversationId, senderId, messageType (text/truck_card/location/document/system), textContent, payload (Map), isRead, readAt, createdAt. `fromJson()`, `toJson()`
- [x] **`payout_profile_model.dart`** — id, profileId, accountHolderName, accountNumberLast4, ifscCode, bankName, status, rejectionReason, createdAt. `fromJson()`, `toJson()`

### 1.6 Providers — `core/providers/`
- [x] **`auth_service_provider.dart`**
  - `authServiceProvider` — Provider<AuthService>
  - `currentUserProvider` — StreamProvider on `authStateChanges`
  - `isAuthenticatedProvider` — derived from `currentUserProvider`
  - `userRoleProvider` — FutureProvider (queries DB `profiles.current_role`)
  - `userProfileProvider` — FutureProvider (full profile data)
  - `invalidateAllUserProviders(WidgetRef ref)` — helper to invalidate ALL user-dependent providers on logout/login
- [x] **`supplier_providers.dart`**
  - `supplierActiveLoadsCountProvider`
  - `supplierRecentLoadsProvider`
  - `supplierDataProvider` — company name, GST, etc.
- [x] **`trucker_providers.dart`**
  - `truckerActiveTripsCountProvider`
  - `truckerFleetCountProvider`
  - `truckerTotalTripsProvider`
  - `truckerRatingProvider`
  - `truckerEarningsProvider`
  - `truckerCompletionRateProvider`
- [x] **`chat_providers.dart`**
  - `unreadChatsCountProvider`

### 1.7 Routing — `core/routing/app_router.dart`
- [x] GoRouter with `_RouterNotifier` pattern (NOT `GoRouterRefreshStream` — see §10.1 in user-app-improvement.md)
  - `_RouterNotifier` uses `ref.listen()` on `currentUserProvider` and `userRoleProvider`
  - GoRouter is a singleton — never recreated
  - Redirect uses `ref.read()` for current values
- [x] **Routes:**
  - `/splash` — SplashScreen
  - `/login` — LoginScreen
  - `/signup` — SignupScreen
  - `/otp-verification` — OtpVerificationScreen
  - `/forgot-password` — ForgotPasswordScreen
  - `/reset-password` — ResetPasswordScreen
  - `/role-selection` — RoleSelectionScreen
  - `/supplier-dashboard` — SupplierDashboardScreen
  - `/post-load` — PostLoadScreen (supplier-only, verification-gated)
  - `/my-loads` — MyLoadsScreen (supplier-only)
  - `/load-detail/:loadId` — LoadDetailScreen
  - `/super-load-request/:loadId` — SuperLoadRequestScreen (supplier-only)
  - `/supplier/super-dashboard` — SuperDashboardScreen (supplier-only)
  - `/supplier-verification` — SupplierVerificationScreen
  - `/supplier-profile` — SupplierProfileScreen
  - `/payout-profile` — PayoutProfileScreen
  - `/find-loads` — FindLoadsScreen (trucker home)
  - `/my-fleet` — MyFleetScreen (trucker-only)
  - `/add-truck` — AddTruckScreen (trucker-only)
  - `/my-trips` — MyTripsScreen (trucker-only)
  - `/trucker-verification` — TruckerVerificationScreen
  - `/trucker-profile` — TruckerProfileScreen
  - `/messages` — ChatListScreen
  - `/chat/:conversationId` — ChatScreen
  - `/settings` — SettingsScreen
  - `/help-support` — HelpSupportScreen
- [x] **Redirect logic:**
  - Not authenticated → `/login` (except `/login`, `/signup`, `/otp-verification`, `/forgot-password`, `/reset-password`)
  - Authenticated + no role → `/role-selection`
  - Authenticated + role supplier → block trucker-only routes → redirect to `/supplier-dashboard`
  - Authenticated + role trucker → block supplier-only routes → redirect to `/find-loads`
  - Do NOT redirect away from `/login` or `/otp-verification` when authenticated (login/OTP screens handle post-auth navigation explicitly)

---

## PHASE 2: Shared Widgets (`lib/src/shared/widgets/`) (IMPROVED — v2) ✅

### 2.1 Glass Card — `glass_card.dart`
- [x] Glassmorphism card: `BackdropFilter(blur: 12.0)`, gradient overlay (white 40%→20%), border (white 40%), radius 16
- [x] Card shadow: `BoxShadow(color: black 6%, blur: 12, offset: (0,4))`
- [x] Interactive variant: `AnimatedScale(scale: 0.98, duration: 150ms)` on tap-down, `1.0` on tap-up
- [x] Non-interactive variant: static, no touch feedback
- [x] **v2:** Use `flutter_animate` for entrance animation (fadeIn + slideUp, 250ms, stagger 50ms per card in lists)

### 2.2 Gradient Button — `gradient_button.dart`
- [x] 135° teal→orange gradient background (topLeft → bottomRight)
- [x] White text (`Button Large` style), radius 12, height 52
- [x] Shadow: `BoxShadow(color: teal 30%, blur: 12, offset: (0,4))`
- [x] Disabled state: grey background, no shadow, 50% opacity text
- [x] Loading state: replace text with `SizedBox(20x20, CircularProgressIndicator(white, strokeWidth: 2))`
- [x] `HapticFeedback.lightImpact()` on press
- [x] `AnimatedScale` press effect (0.97 on tap-down)

### 2.3 Bottom Nav Bar — `bottom_nav_bar.dart`
- [x] Height 72px (includes safe area), white background, top border `Divider` color, elevation 8
- [x] Active: icon + label in Brand Teal, Inactive: icon in Text Tertiary, no label
- [x] **Supplier items:** Home, My Loads, Super, Chat → routes: `/supplier-dashboard`, `/my-loads`, `/supplier/super-dashboard`, `/messages`
- [x] **Trucker items:** Home (Find Loads), My Trips, Fleet, Chat → routes: `/find-loads`, `/my-trips`, `/my-fleet`, `/messages`
- [x] Uses `context.go()` for navigation (not `push`)
- [x] Highlights active tab based on current route
- [x] **v2:** Unread badge on Chat tab (red dot with count from `unreadChatsCountProvider`)
- [x] **v2:** Subtle scale animation on tap (icon bounces 1.0 → 1.15 → 1.0, 200ms)

### 2.4 App Drawer — `app_drawer.dart`
- [x] **Header:** `DrawerHeader` + horizontal `Row` (match admin style)
  - Left: 52×52 circle — `CachedNetworkImage` avatar with placeholder initial, error fallback initial
  - Right: Name (`H3`, bold, white, maxLines 1, ellipsis), Role pill ("Supplier"/"Trucker" — rounded, semi-transparent white bg), Verification status pill (small, below role)
  - No email in header (visible in profile screen)
  - Gradient background (teal → teal-dark)
- [x] **Menu Items:**
  - My Profile → `/supplier-profile` or `/trucker-profile` (based on role)
  - Verification → `/supplier-verification` or `/trucker-verification`
  - Settings → `/settings`
  - Help & Support → `/help-support`
  - Divider
  - Switch Role → update DB role, `invalidateAllUserProviders(ref)`, sign out, navigate to `/login`
  - Logout → `invalidateAllUserProviders(ref)` BEFORE `signOut()` (while ref alive), then sign out
- [x] Must be present on ALL primary screens (dashboards, lists, chat list)
- [x] **v2:** Each menu item has leading icon, trailing chevron, ink splash on tap
- [x] **v2:** Active route item highlighted with Brand Teal Light background

### 2.5 Skeleton Loader — `skeleton_loader.dart`
- [x] Use `shimmer` package for consistent shimmer effect
- [x] Variants:
  - `SkeletonCard` — rounded rect (card height) with 3 line placeholders
  - `SkeletonList` — N skeleton cards stacked with `Card Gap` spacing
  - `SkeletonProfile` — circle avatar + 2 text lines
  - `SkeletonChat` — alternating left/right message placeholders
- [x] Base color: `#E8E8E8`, highlight color: `#F5F5F5`

### 2.6 Empty State — `empty_state.dart`
- [x] SVG illustration (from `flutter_svg`) in a tinted circle (Brand Teal Light bg)
- [x] Title (`H3`), description (`Body Medium`, Text Secondary), optional action button (Gradient or outlined)
- [x] Centered vertically in available space
- [x] **v2:** `flutter_animate` fadeIn + scale entrance (300ms)

### 2.7 City Autocomplete Field — `city_autocomplete_field.dart` (IMPROVED — v2)
- [x] Uses expanded `indian_locations.json` dataset
- [x] Fuzzy search: matches `name`, `aliases[]`, `district`, `state`
- [x] Weighted ranking: exact > starts-with > contains > alias match
- [x] `is_major_hub` results boosted to top of suggestions
- [x] Debounced input (300ms)
- [x] Dropdown shows: **City Name**, State — with `type` badge for transport hubs/industrial zones
- [x] Returns `LocationResult` object: `{name, state, district, lat, lng, type}`
- [x] Lazy-loads JSON on first interaction (not app startup)
- [x] **v2:** Recent searches stored in `SharedPreferences` (last 5), shown as chips above input

### 2.8 Document Upload Widget — `document_upload_widget.dart`
- [x] Camera/Gallery picker via `image_picker`
- [x] Preview thumbnail after selection (rounded corners, 80px height)
- [x] Upload to Supabase Storage with progress indicator (linear progress bar)
- [x] States: empty (dashed border + icon), selected (thumbnail + "Change" button), uploading (progress), uploaded (green check overlay), error (red border + retry)
- [x] **v2:** Image compression before upload (max 1200px, 80% quality)

### 2.9 Chat Bubble Widgets — `features/chat/presentation/widgets/`
- [x] **`message_bubble.dart`** — sender (teal bg, white text, right-aligned) / receiver (white bg, dark text, left-aligned), rounded corners with tail, timestamp below
- [x] **`truck_card_bubble.dart`** — truck details card with "Verified" badge (green checkmark), body type icon, tyre count
- [x] **`location_bubble.dart`** — static map placeholder with pin icon, tap-to-open Google Maps via `url_launcher`
- [x] **`document_bubble.dart`** — RC document with file icon, signed URL link, expiry warning
- [x] **`booking_confirmed_bubble.dart`** — "Booking Confirmed" card (Success Light bg, green border), load details + "Start Trip" CTA
- [x] **`system_action_bubble.dart`** — styled bubbles: "Request RC" (purple accent), "Ask Truck Details" (teal accent), with descriptive subtitle

### 2.10 Connectivity Banner — `connectivity_banner.dart` (NEW — v2)
- [x] Uses `connectivity_plus` to detect offline state
- [x] Shows a persistent banner at top of screen: "No internet connection" (Error bg, white text)
- [x] Auto-dismisses when connection restored with "Back online" (Success bg, 2s auto-hide)
- [x] Wrap in `MaterialApp` builder so it appears on ALL screens

### 2.11 Pull-to-Refresh Wrapper — `refreshable_list.dart` (NEW — v2)
- [x] Wraps any scrollable list with pull-to-refresh behavior
- [x] Uses `RefreshIndicator` with Brand Teal color
- [x] Accepts `onRefresh` callback
- [x] Use on: My Loads, Find Loads results, My Fleet, My Trips, Chat List, Super Dashboard

### 2.12 Status Chip — `status_chip.dart` (NEW — v2)
- [x] Reusable chip for displaying status across the app
- [x] Color mapping: `active` → Success, `booked` → Info, `in_transit` → Warning, `completed` → Success, `cancelled` → Error, `expired` → Text Tertiary, `pending` → Warning, `verified` → Success, `rejected` → Error
- [x] Pill shape, small text, colored bg + darker text

### 2.13 Stat Card — `stat_card.dart` (NEW — v2)
- [x] Reusable card for dashboard stats (Active Loads, Unread Chats, etc.)
- [x] Icon (in tinted circle) + Number (`Number` style) + Label (`Caption`)
- [x] White card bg, subtle shadow, radius 16
- [x] Tap action optional (e.g., tap Active Loads → navigate to My Loads)

---

## PHASE 3: Auth & Onboarding Screens ✅

### 3.1 Splash Screen — `features/auth/presentation/screens/splash_screen.dart`
- [x] Scaffold BG (#F5F5F0), centered logo (120×120), no text
- [x] **v2:** Logo entrance animation: scale 0.8→1.0 + fadeIn (400ms, easeOut)
- [x] Check `access_token` → if valid → fetch profile → redirect based on `current_role`
- [x] If no role → `/role-selection`
- [x] If invalid/expired → `/login`
- [x] Minimum display time: 1.5s (so animation completes even on fast connections)

### 3.2 Login Screen — `features/auth/presentation/screens/login_screen.dart`
- [x] Scaffold BG, centered logo (100×100), "Welcome back" (`H1`), "Sign in to continue" (`Body Medium`, Text Secondary)
- [x] Single `TextFormField` — "Email or Mobile" (auto-detect: all digits after stripping +91 = mobile, else email)
- [x] Password field always visible, with visibility toggle icon
- [x] Primary CTA: "Login" (gradient button, password-based)
- [x] "Login with OTP" text button — only visible/enabled when mobile detected
- [x] "Forgot Password?" link right-aligned below password field
- [x] "Don't have an account? **Sign Up**" at bottom ("Sign Up" in Brand Teal, tappable)
- [x] **Post-login:** `invalidateAllUserProviders(ref)`, fetch role from DB, navigate explicitly (do NOT rely on router redirect)
- [x] Scrollable form in `Expanded` area with `BouncingScrollPhysics`
- [x] **v2:** Form fields animate in with stagger (fadeIn + slideUp, 50ms delay each)
- [x] **v2:** Error messages appear with shake animation on the field
- [x] **v2:** Loading state on button (spinner replaces text) — disable all inputs during auth

### 3.3 Signup Screen — `features/auth/presentation/screens/signup_screen.dart`
- [x] Scaffold BG, centered logo (80×80), "Create Account" (`H1`), "Join India's trucking network" (`Body Medium`, Text Secondary)
- [x] Fields: First Name + Last Name (side-by-side `Row`, both required min 2 chars), Email, Mobile (REQUIRED — with non-editable "+91" prefix badge, 10 digits only, `^[6-9]\d{9}$`), Password, Confirm Password
- [x] Combined as `"firstName lastName"` when calling API
- [x] Mobile stored as `+91XXXXXXXXXX` in DB (prepend country code before API call)
- [x] All fields: `textInputAction: TextInputAction.next` for keyboard flow
- [x] **v2:** Password strength indicator bar below password field (red/yellow/green) with hint text
- [x] **v2:** Real-time validation: green checkmark appears on each field when valid
- [x] **v3:** Privacy consent checkbox (REQUIRED): "I agree to the [Terms of Service] and [Privacy Policy]" — links open in browser
- [x] CTA: "Create Account" (gradient button with loading state) — disabled until consent checked
- [x] "Already have an account? **Login**" at bottom
- [x] On success: record consent in `user_consents` table, show success snackbar "Account created! Please confirm your email, then log in" → navigate to login

### 3.4 OTP Verification Screen — `features/auth/presentation/screens/otp_verification_screen.dart`
- [x] OTP input (6 individual digit boxes, auto-advance focus)
- [x] Resend timer (60s countdown, "Resend OTP" becomes tappable when timer hits 0)
- [x] **Post-verify:** `invalidateAllUserProviders(ref)`, fetch role, navigate explicitly
- [x] **v2:** Auto-submit when all 6 digits entered (no need to tap button)

### 3.5 Forgot Password Screen — `features/auth/presentation/screens/forgot_password_screen.dart`
- [x] Back button, "Reset Password" (`H2`), description text
- [x] Email input
- [x] Send reset link via `resetPasswordForEmail()`
- [x] Success state: show checkmark animation + "Check your email" message

### 3.6 Reset Password Screen — `features/auth/presentation/screens/reset_password_screen.dart`
- [x] New password + confirm password (with strength indicator)
- [x] Update password
- [x] Success → navigate to login with success snackbar

### 3.7 Role Selection Screen — `features/auth/presentation/screens/role_selection_screen.dart`
- [x] Full screen, Scaffold BG, "What describes you best?" (`H1`), subtitle (`Body Medium`)
- [x] Two large cards (vertical stack, `Card Gap` spacing):
  - "I am a Supplier" — subtext: "Post Loads, Find Trucks, Track Deliveries", icon: Factory/Warehouse, Brand Teal border on hover/tap
  - "I am a Trucker" — subtext: "Find Loads, Manage Fleet, Get Paid", icon: Semi-Truck, Brand Teal border on hover/tap
- [x] On tap: `AnimatedScale` press effect, update `profiles.current_role` → redirect to respective dashboard
- [x] Only shown when `current_role` is null
- [x] **v2:** Cards animate in with stagger (fadeIn + slideUp, 100ms delay)
- [x] **v2:** Selected card gets teal border + checkmark overlay before navigation

---

## PHASE 4: Supplier Screens ✅

### 4.1 Supplier Dashboard — `features/supplier/presentation/screens/supplier_dashboard_screen.dart`
- [x] **Bottom Nav:** Home (active), My Loads, Super, Chat
- [x] **Drawer:** Yes
- [x] **Layout:** `SingleChildScrollView` with `BouncingScrollPhysics`, pull-to-refresh
- [x] **Top Bar:** "Welcome, [Company Name]" (`H2`) left, Notification Bell (with badge) + Profile Avatar (tap → open drawer) right
- [x] **Verification Banner (conditional):** If unverified → Warning Light bg card: "Complete verification to post loads" + "Verify Now" button. Dismissible after first view.
- [x] **Quick Stats Row:** 2-3 `StatCard` widgets in a `Row`: Active Loads, Unread Chats, Total Loads
  - Each tappable → navigates to relevant screen
  - **v2:** Numbers animate in (count-up from 0, 500ms) using `flutter_animate`
- [x] **Primary CTA:** "Post New Load" (gradient button, full width, height 52) — with truck icon leading
- [x] **Recent Activity section:** `Overline` label "RECENT LOADS", last 3 loads as compact cards with route + `StatusChip`
  - Tap → navigate to load detail
  - **v2:** Cards animate in with stagger (fadeIn + slideUp)
- [x] **v2:** If no loads yet, show friendly empty state: "Post your first load to get started"

### 4.2 Post Load Wizard — `features/supplier/presentation/screens/post_load_screen.dart`
- [x] **Gate:** Check verification status. If not verified → show bottom sheet modal "Complete verification to post loads" with "Verify Now" CTA
- [x] **v2:** Step indicator at top using `smooth_page_indicator` (4 dots, teal active, grey inactive)
- [x] **v2:** Swipe left/right between steps (PageView) + "Next" / "Back" buttons at bottom
- [x] **Step 1 — Route & Material:**
  - From City (`CityAutocompleteField` — with recent searches)
  - To City (`CityAutocompleteField`)
  - Material Type (dropdown: Agricultural, Industrial, FMCG, Chemicals, Other)
  - Weight in Tonnes (min/max range — two number inputs side-by-side)
- [x] **Step 2 — Logistics:**
  - Truck Type (FilterChips with "Any": Open, Container, Trailer, Tanker)
  - Tyre Count (multi-select chips with "Any": 6, 10, 12, 14, 18, 22)
  - Pickup Date (DatePicker, default today, minimum today)
- [x] **Step 3 — Commercials:**
  - Price (number input, label "₹/ton", `Number` style for display)
  - Toggle: Fixed Price vs Negotiable (segmented control)
  - Static info card: "Standard Terms: 80% Advance on Loading, 20% on Delivery"
  - **v2:** Price preview: "Total for 20 tons = ₹20,000" (auto-calculated)
- [x] **Step 4 — Review & Publish:**
  - Summary card showing all details in a clean layout (route, material, weight, truck, price, date)
  - Checkbox confirmation: "I confirm these details are correct"
  - "Post Load" (gradient button with loading state)
  - Success: haptic + success snackbar + navigate to My Loads
  - **v2:** Summary card uses subtle teal left border accent

### 4.3 My Loads Screen — `features/supplier/presentation/screens/my_loads_screen.dart`
- [x] **Bottom Nav:** My Loads (active)
- [x] **Drawer:** Yes
- [x] **Tabs:** Active | History (using `TabBar` with teal indicator)
- [x] **Pull-to-refresh** on both tabs
- [x] **Load Card (Supplier View):**
  - Header: Route (From → To) in `H3`, Material badge
  - Stats row: "Views: X" (eye icon from `loads.views_count`), "Chats: X" (chat icon — count conversations WHERE `load_id` = this load) — both must be visible, not stubs
  - `StatusChip` (Active/Booked/Expired/Cancelled)
  - **Actions footer (icon buttons in a row):**
    - Chat bubble icon → "View Responses" (opens chat filtered by this load ID)
    - Star icon → "Make Super" (opens Super Load request flow)
    - Edit icon → modify details (disabled + greyed if load is booked)
    - X icon → "Deactivate" (confirmation dialog, set status to cancelled)
  - **v2:** Swipe left on card to reveal quick actions (Deactivate, Make Super)
- [x] Search bar at top (filter by route/material, debounced 300ms) — must be functional (NOT a stub — previous version had empty `onPressed`)
- [x] **v2:** Cards animate in with stagger on first load

### 4.4 Load Detail Screen — `features/supplier/presentation/screens/load_detail_screen.dart`
- [x] Full load details in sections: Route, Material & Weight, Truck Requirements, Pricing, Dates
- [x] `StatusChip` prominently displayed
- [x] Actions row at bottom: Edit (if active), Deactivate (if active), Make Super (if active + not already super)
- [x] Responses section: list of truckers who chatted about this load (tap → open chat)
- [x] **v2:** Share load button (copy load details as text to clipboard)

### 4.5 Super Load Request Screen — `features/supplier/presentation/screens/super_load_request_screen.dart`
- [x] **Gate:** Check payout profile exists. If missing → show bottom sheet: "Add bank details to use Super Load" + "Add Payout Profile" CTA → `/payout-profile`
- [x] Load summary card (route, material, price)
- [x] Explanation card: "TranZfort Ops will find a verified truck, handle tracking, and ensure delivery."
- [x] Confirm button: "Make Super Load" (gradient button with loading state)
- [x] On confirm: set `loads.super_status = 'requested'`, `loads.is_super_load = true`
- [x] Success: haptic + success animation + navigate to Super Dashboard

### 4.6 Super Dashboard — `features/supplier/presentation/screens/super_dashboard_screen.dart`
- [x] **Bottom Nav:** Super (active)
- [x] **Drawer:** Yes
- [x] **Pull-to-refresh**
- [x] List of loads managed by Ops, each card showing:
  - Route, Material, Price
  - **Status timeline:** Processing → Assigned (show truck number) → In-Transit → POD Uploaded
  - **v2:** Visual timeline with connected dots (filled = completed, outlined = pending, pulsing = current)
- [x] "View Details" button with correct route param (`pathParameters: {'loadId': load.id!}`)
- [x] Empty state: "No Super Loads yet. Make a load Super from My Loads."

### 4.7 Supplier Verification — `features/supplier/presentation/screens/supplier_verification_screen.dart`
- [x] **Required docs:** Aadhaar (front/back), PAN, Business Licence, Profile Photo (camera/gallery), Company Name
- [x] **Optional:** GST Certificate
- [x] **Pre-fill:** Fetch existing data on screen init, show current upload status per document
- [x] **Status banner at top:**
  - Pending: Warning Light bg — "Your documents are under review. This usually takes 24-48 hours."
  - Rejected: Error Light bg — "Verification failed: [reason]. Please re-upload the required documents."
  - Verified: Success Light bg — "Your profile is verified." (read-only view with green badges)
- [x] Each document slot shows: label, upload button, status icon (pending/verified/rejected)
- [x] Upload to Supabase Storage `verification-docs` bucket
- [x] **v2:** Progress indicator showing "3 of 5 documents uploaded" at top
- [x] **v2:** `smooth_page_indicator` if using step-by-step flow

### 4.8 Supplier Profile — `features/supplier/presentation/screens/supplier_profile_screen.dart`
- [x] **Layout:** `SingleChildScrollView`, sections separated by `Divider`
- [x] Profile header: Large avatar (80px, `CachedNetworkImage` or initial), Name (`H2`), "Supplier" role pill, `StatusChip` for verification
- [x] Company info section (`Overline` label): Company Name, GST Number
- [x] Personal info section: Name, Email, Mobile (read-only, with copy icon on each)
- [x] Stats section: Active Loads, Total Loads (using `StatCard` in a row)
- [x] Actions: "Edit Verification" outlined button → `/supplier-verification`, "Payout Profile" outlined button → `/payout-profile`

### 4.9 Payout Profile — `features/supplier/presentation/screens/payout_profile_screen.dart`
- [x] Form: Account Holder Name, Account Number (masked input — store last4 only, display as ****1234), IFSC Code (auto-fetch bank name from IFSC), Bank Name (auto-filled or manual)
- [x] `StatusChip` display (pending/verified/rejected)
- [x] If rejected: show rejection reason in Error Light card
- [x] Submit → create/update `payout_profiles` row (gradient button with loading state)
- [x] **v2:** IFSC validation — check format (4 letters + 0 + 6 alphanumeric)

---

## PHASE 5: Trucker Screens ✅

### 5.1 Find Loads (Trucker Home) — `features/trucker/presentation/screens/find_loads_screen.dart`
- [x] **Bottom Nav:** Home (active), My Trips, Fleet, Chat
- [x] **Drawer:** Yes
- [x] **Pre-search view (scrollable, BouncingScrollPhysics):**
  - Hero text: "Find loads for your return trip." (`H1`, Brand Teal color)
  - Quick Stats row: `StatCard` x2 — Active Trips, Total Trips (tappable)
  - Quick Links: "My Active Trips" chip, "My Fleet" chip (outlined, teal border)
  - Search form in a white card:
    - From City (`CityAutocompleteField` with recent searches)
    - To City (`CityAutocompleteField`)
    - Truck Type (optional dropdown)
  - "Search Loads" (gradient button, full width, haptic feedback)
  - **v2:** Swap icon between From/To cities (tap to reverse route)
- [x] **Search Results view:**
  - Condensed header: "Delhi → Mumbai" (`H3`) with "X" to clear search and return to pre-search
  - **Sticky horizontal filter chips** (scrollable row, `BouncingScrollPhysics`):
    - Sort: "Price ↑" / "Price ↓" (toggle chip)
    - "Verified Supplier" (filter chip)
    - "Materials" (dropdown chip → multi-select bottom sheet)
    - "Weight" (range chip → slider bottom sheet) — must be a quick chip, NOT hidden in expanded panel
  - **Pull-to-refresh** on results list
  - **Load Card (Decision Ready):**
    - "Super Load" badge with orange glow border + `BoxShadow` (guaranteed payment)
    - Route: `H3` Origin → Dest
    - Details row: Material badge, Weight (`Body Small`), Price (`Number` style, "₹X/ton")
    - "Posted 10m ago" (`Caption`, Text Tertiary) — relative timestamp from `createdAt`
    - Supplier name + verified badge (if verified)
    - CTA: "Chat Now" (gradient button, haptic)
    - **Gate:** If unverified → show bottom sheet "Verify Profile to Chat" with "Verify Now" CTA
  - **v2:** Cards animate in with stagger (fadeIn + slideUp, 50ms delay)
  - **v2:** Scroll-to-top FAB appears after scrolling down 500px
  - **v2:** Result count badge: "24 loads found"
- [x] **Accessible without verification** — only chat/negotiation is gated

### 5.2 Fleet Management — `features/trucker/presentation/screens/my_fleet_screen.dart`
- [x] **Bottom Nav:** Fleet (active)
- [x] **Drawer:** Yes
- [x] **Pull-to-refresh**
- [x] **Empty State:** SVG truck illustration + "No trucks added. Add a truck to start bidding." + "Add Truck" gradient button
- [x] **Truck Card (white card, shadow):**
  - Header row: Truck Number (`H3`, monospace feel) + `StatusChip` (Verified/Pending/Rejected)
  - Details row: Body Type icon + label, Tyres count, Capacity in tonnes
  - If rejected: Error Light bg banner with rejection reason
  - Tap → expand to show RC photo thumbnail (if uploaded)
  - **v2:** Swipe left to delete truck (with confirmation dialog)
- [x] FAB: "Add Truck" (teal circle FAB with + icon) → `/add-truck`
- [x] Search bar at top (filter by vehicle number, debounced 300ms)
- [x] **v2:** Cards animate in with stagger

### 5.3 Add Truck — `features/trucker/presentation/screens/add_truck_screen.dart`
- [x] **Layout:** `SingleChildScrollView`, white card sections
- [x] **Vehicle Details:**
  - Registration Number (e.g., MH12AB1234) — auto-uppercase, format validation
  - Body Type (dropdown with icons: Open, Container, Trailer, Tanker)
  - Tyres (number input or chip selector: 6, 10, 12, 14, 18, 22)
  - Capacity (Tonnes, number input)
- [x] **Document Upload:** RC Photo using `DocumentUploadWidget` (Camera/Gallery)
- [x] Submit → status `pending`, admin gets notification
- [x] Haptic feedback on submit, loading state on button
- [x] Success: snackbar "Truck added! Admin will review your RC." + navigate back
- [x] **v2:** Registration number format hint: "e.g., MH 12 AB 1234"

### 5.4 My Trips — `features/trucker/presentation/screens/my_trips_screen.dart`
- [x] **Bottom Nav:** My Trips (active)
- [x] **Drawer:** Yes
- [x] **Tabs:** Active | Completed (using `TabBar` with teal indicator)
- [x] **Pull-to-refresh** on both tabs
- [x] **Active Trip Card (white card, shadow):**
  - Route (`H3`), Material badge, `StatusChip`
  - Supplier name (with verified badge if applicable)
  - **Trip progress timeline (v2):** Visual stepper — Reached Pickup → Loading → In-Transit → Unloading → Delivered
    - Filled circle = completed, pulsing circle = current, outlined = upcoming
  - "Update Status" button (teal outlined) — shows next logical step
  - "Upload POD" button (Super Loads only) — camera interface for Proof of Delivery, orange accent
  - **Persist trip stages to DB** (NOT local state only — use `loads.status` or dedicated column)
- [x] **Completed Trip Card:** Route, dates, "Delivered" status, earnings if available
- [x] Skeleton loaders for loading state
- [x] **v2:** Cards animate in with stagger

### 5.5 Trucker Verification — `features/trucker/presentation/screens/trucker_verification_screen.dart`
- [x] **Required docs:** Aadhaar (front/back), PAN, DL (front/back), Profile Photo (REQUIRED — camera/gallery)
- [x] **Optional:** Insurance, Permit
- [x] Pre-fill existing data, status banner (same pattern as supplier verification)
- [x] Upload to Supabase Storage `verification-docs` bucket
- [x] **v2:** Progress indicator "4 of 6 documents uploaded"
- [x] **v2:** Document slots with clear status icons per document

### 5.6 Trucker Profile — `features/trucker/presentation/screens/trucker_profile_screen.dart`
- [x] **Layout:** `SingleChildScrollView`, sections separated by `Divider`
- [x] Profile header: Large avatar (80px), Name (`H2`), "Trucker" role pill, `StatusChip` for verification
- [x] Personal info section: Name, Mobile (`profile['mobile']` NOT `profile['phone']`), Email (read-only, copy icons)
- [x] Stats section: `StatCard` row — Total Trips, Rating (star icon + number from `truckerRatingProvider`), Completion Rate (% from `truckerCompletionRateProvider`)
- [x] Fleet summary: "X trucks" with tap → navigate to My Fleet
- [x] Actions: "Edit Verification" outlined button → `/trucker-verification`
- [x] **v2:** Earnings card (if data available) — total earnings with trend indicator

---

## PHASE 6: Chat & Negotiation ✅

### 6.1 Chat List — `features/chat/presentation/screens/chat_list_screen.dart`
- [x] **Bottom Nav:** Chat (active)
- [x] **Drawer:** Yes
- [x] **Pull-to-refresh**
- [x] **Grouped by Load:** Section headers show "Delhi → Mumbai (Rice)" (`H3` + Material badge), items list truckers/suppliers chatting about this load
  - Use `collection` package `groupBy` on `loadId`
- [x] **Conversation Card (white card):**
  - Left: Avatar circle (52px, `CachedNetworkImage` or initial, teal bg for unread)
  - Center: Name (`Body Large`, bold if unread), Last message preview (`Body Small`, Text Secondary, maxLines 1)
  - Right: Timestamp (`Caption`, teal if unread, Text Tertiary if read), Unread count badge (red circle)
  - Show actual name (NOT raw UUID) — join with profiles, use `full_name` with email prefix fallback
  - Last message preview (backfill from messages table if null)
  - Tap → push to `/chat/:conversationId`
- [x] **On return from chat:** refresh conversations + unread counts (via `await context.pushNamed()`)
- [x] Search bar at top (filter by name/route, debounced 300ms)
- [x] Store `_currentUserId` as widget state (captured when `currentUser` is guaranteed non-null)
- [x] Empty state: "No conversations yet. Start chatting by finding loads or posting one."
- [x] **v2:** Swipe left on conversation to archive/mute (placeholder)
- [x] **v2:** Cards animate in with stagger

### 6.2 Chat Screen — `features/chat/presentation/screens/chat_screen.dart`
- [x] **AppBar:** Other user's name (`H3`), route subtitle (`Caption`), phone call button (via `url_launcher`), more menu (Block/Report)
- [x] **Context Bar (collapsible, tap to expand/collapse):** Material, Weight, Price (₹/ton), Pickup Date — teal left border accent
- [x] **Message Stream:** Realtime subscription via Supabase
- [x] **Optimistic send:** Add message to local list immediately with temp ID, replace with DB response, remove on failure (show error icon + retry)
- [x] **Deduplication:** Realtime callback skips messages already in list (by ID match)
- [x] **Scroll to bottom:** Use `addPostFrameCallback` after new message renders
- [x] **v2:** "New messages" floating pill when scrolled up + new messages arrive (tap to scroll down)
- [x] **v2:** Date separators between message groups ("Today", "Yesterday", "Feb 5")
- [x] **Message types rendered:**
  - `text` → MessageBubble (sender: teal bg, white text, right | receiver: white bg, dark text, left)
  - `truck_card` → TruckCardBubble (with "Verified" badge)
  - `location` → LocationBubble (tap → Google Maps deep link)
  - `document` → DocumentBubble (signed URL, expiry warning if < 15min remaining)
  - `voice` → VoiceMessageBubble (play/pause + progress bar + duration — see Phase 18)
  - `system` → SystemActionBubble or BookingConfirmedBubble (centered, no alignment)
- [x] **Input bar:** TextField with rounded border, attachment (+) button left, mic icon (right of text, left of send), send button right (teal circle, arrow icon)
  - Send button only enabled when text is non-empty or attachment selected
  - **v2:** TextField auto-grows up to 4 lines
  - **v3:** Mic icon: tap to start recording → input bar transforms to recording UI (red pulsing dot + timer + "Tap to stop" + cancel X). On stop → upload to `voice-messages` bucket → send as `message_type: 'voice'`. See Phase 18 for full spec.
- [x] **Supplier attachment menu (+) — bottom sheet:**
  - Accept Deal → confirmation dialog, update load status to `booked`, set `assigned_trucker_id`, send system message
  - Ask Truck Details → send system message with `subtype: 'ask_truck_details'`
  - Request RC Document → send system message with `subtype: 'request_rc'`
  - Share Location
  - Share Document
- [x] **Trucker attachment menu (+) — bottom sheet:**
  - Share Truck Details → select from verified trucks → send Truck Card bubble (include `verified: true`)
  - Share Location → GPS → Map Preview bubble
  - Share Document → select RC → send signed URL document bubble
- [x] **Verification gate:** Trucker must be verified to send messages/negotiate. Show locked input bar with "Verify to chat" message.
- [x] Block User / Report — confirmation dialogs with text input for reason (placeholder for DB)
- [x] Payload keys: `vehicle_number` (standardized — NOT `truck_number`, previous version had mismatch between send and render code), `lat`/`lng` for location, `signed_url` for documents
- [x] **v2:** Message send animation (bubble slides in from bottom-right)

### 6.3 Booking Flow
- [x] Supplier sends "Accept Deal" → confirmation dialog: "Accept deal with [Trucker Name]? This will lock the load."
- [x] On confirm: system message with `subtype: 'deal_accepted'`, payload `{load_id, trucker_id}`
- [x] Load status → `booked`, `assigned_trucker_id` set
- [x] Trucker sees `BookingConfirmedBubble` with load details + "Start Trip" CTA (green accent)
- [x] "Start Trip" → load status → `in_transit` → appears in My Trips
- [x] **v2:** Confetti/celebration animation on booking confirmation (subtle, 1s)

---

## PHASE 7: Shared Screens ✅

### 7.1 Settings — `features/shared/presentation/screens/settings_screen.dart`
- [x] **Layout:** `SingleChildScrollView`, grouped sections in white cards
- [x] **Account section:**
  - Switch Role button — confirmation dialog, update DB role, `invalidateAllUserProviders(ref)`, sign out, navigate to `/login`
  - Change Password → opens reset password flow
- [x] **Preferences section:**
  - **v3:** Language selector (English / हिन्दी) — saves to `SharedPreferences` + updates `profiles.preferred_language` in DB. App rebuilds with new locale.
  - **v2:** Notification preferences toggle (placeholder)
- [x] **About section:**
  - Terms & Conditions (open URL via `url_launcher` → `https://tranzfort.com/terms`)
  - Privacy Policy (open URL via `url_launcher` → `https://tranzfort.com/privacy`)
  - App version display (`Caption`, Text Tertiary)
- [x] **Data & Privacy section (NEW — v3):**
  - Download My Data — placeholder button with "Coming soon" toast (DPDP Act right — deferred)
  - Delete My Account — confirmation dialog → sets `profiles.data_deletion_requested_at = NOW()` → shows "Your account will be deleted within 30 days. Contact support@tranzfort.com to cancel."
- [x] **Danger zone:**
  - Logout button (red text, confirmation dialog)
  - Delete Account moved to Data & Privacy section above

### 7.2 Help & Support — `features/shared/presentation/screens/help_support_screen.dart`
- [x] **Layout:** `SingleChildScrollView`
- [x] **Contact card:** Email (`support@tranzfort.com` — tap to open mail app), Phone (tap to call)
- [x] **FAQ section:** Expandable `ExpansionTile` list (5-10 common questions, static content)
- [x] **Open Ticket form:** Subject (text input), Description (multiline text area), Submit button
  - Creates row in `support_tickets` table
  - Success: snackbar "Ticket submitted. We'll respond within 24 hours."
- [x] **My Tickets:** List of previously submitted tickets with status

---

## PHASE 8: Main App Entry ✅

### 8.1 `lib/main.dart`
- [x] Initialize Supabase with `SupabaseConfig.supabaseUrl` and `SupabaseConfig.supabaseAnonKey`
- [x] Wrap app in `ProviderScope`
- [x] `MaterialApp.router` with GoRouter from `routerProvider`
- [x] Apply `AppTheme.lightTheme`
- [x] Title: "TranZfort"
- [x] **v2:** Wrap with `ScrollConfiguration` to set `BouncingScrollPhysics` as global default
- [x] **v2:** Wrap with connectivity banner builder (shows offline/online status on ALL screens)

### 8.2 `lib/src/app.dart`
- [x] `TranZfortApp` ConsumerWidget
- [x] Watch `routerProvider` for GoRouter instance
- [x] **v2:** `flutter_animate` global configuration (default duration, curve)

---

## PHASE 9: Polish & Quality (EXPANDED — v2) 🔧

### 9.1 Visual Consistency Checklist
- [x] All primary CTAs use `GradientButton` (Post Load, Search Loads, Chat Now, Add Truck, Accept Deal, Create Account)
- [x] All secondary CTAs use outlined `ElevatedButton` with teal border
- [x] All loading states use `SkeletonLoader` (NEVER `CircularProgressIndicator` on screens — only inside buttons)
- [x] All empty states use `EmptyState` widget with SVG illustration
- [x] All status indicators use `StatusChip` widget
- [x] All stat displays use `StatCard` widget
- [x] All list screens support pull-to-refresh (supplier dashboard, my loads, super loads, chat list, my fleet, find loads)
- [x] All scrollable screens use `BouncingScrollPhysics`
- [x] All cards use consistent radius (16), shadow, and padding
- [x] All forms use consistent input styling from theme
- [x] Super Load cards have orange glow border treatment everywhere they appear
- [x] Toast/snackbar for all success/error feedback (floating, rounded, dark bg) — via `AppDialogs` utility

### 9.2 Micro-Interactions & Animation
- [x] Haptic feedback on ALL primary actions (Post, Accept, Book, Search, Add Truck, Send Message, Login, Signup) — via `Haptics` utility + `GradientButton`
- [x] Button press scale effect (0.97) on all tappable cards and buttons
- [x] List items animate in with stagger on first load (fadeIn + slideUp, 50ms delay) — `StaggerAnimateList` extension in `animations.dart`
- [x] Page transitions: fade + slide (250ms) via GoRouter custom transition — `fadeSlideTransitionPage()` in `animations.dart`, applied to all routes
- [x] Number count-up animation on dashboard stat cards — `CountUpText` widget in `animations.dart`, used in `StatCard` (500ms)
- [x] Splash logo scale animation (400ms)
- [x] Role selection card entrance animation (stagger) — `.staggerEntrance()` on role cards + header
- [x] Form field entrance animation (stagger on auth screens) — login, signup screens

### 9.3 Scroll & Layout Quality
- [x] `BouncingScrollPhysics` everywhere (set globally via `ScrollConfiguration`)
- [x] Screen padding: horizontal 20, vertical 16 (consistent breathing room)
- [x] No content touching screen edges — always padded
- [x] Keyboard-aware: forms scroll to keep active field visible (`SingleChildScrollView` + `Expanded`)
- [x] Safe area handling: bottom nav respects safe area, content doesn't go under status bar
- [x] Long lists use `ListView.builder` (not `Column` with `children`) for performance
- [x] Scroll-to-top FAB on long lists — `ScrollToTopFab` widget on Find Loads results

### 9.4 Error Handling & Recovery
- [x] All API calls wrapped in try/catch with user-friendly error snackbars — via `AppDialogs.showErrorSnackBar()`
- [x] Network errors show "Check your connection and try again" with retry button — `ErrorRetry` widget applied to all list screens
- [x] Form validation errors: inline red text below field + field border turns red — via `Validators` utility
- [x] Auth errors: specific messages ("Invalid credentials", "Account not found", "Email not confirmed")
- [x] Optimistic actions (chat send) show error icon + retry on failure — `isFailed` field on `MessageModel`, retry via `_retryMessage()`
- [x] **v2:** Global error boundary widget that catches unhandled exceptions and shows friendly error screen — `ErrorBoundary` in `main.dart`

### 9.5 Data Integrity
- [x] Trip stages persisted to DB (not local state only) — migration `20260206000001_trip_stage_column.sql`, `updateTripStage()` in DB service, full My Trips screen with stage progression UI
- [x] Load views/responses counts tracked via `incrementLoadViews()`
- [x] Conversation names resolved from profiles (not raw UUIDs)
- [x] Payout profile stores last4 only (never full account number — mask on client before sending)
- [x] `ensureProfileExists()` called after ALL auth flows (handles phone OTP auto-signup edge case)

### 9.6 Security
- [ ] RLS awareness in all queries (comments in code explaining which RLS policy applies)
- [ ] Signed URLs for sensitive documents (1-hour expiry)
- [ ] No sensitive data in logs (no passwords, no full account numbers, no auth tokens)
- [x] Input validation:
  - Mobile: Indian format `^[6-9]\d{9}$`
  - Email: standard format
  - PAN: `^[A-Z]{5}[0-9]{4}[A-Z]{1}$`
  - Aadhaar: `^\d{12}$` (last 4 digits validated)
  - IFSC: `^[A-Z]{4}0[A-Z0-9]{6}$`
  - Vehicle registration: Indian format
  - All via `Validators` utility class, applied to: login, signup, supplier verification, trucker verification, payout profile
- [x] Supabase anon key: use legacy JWT format (NOT `sb_publishable_*` — Edge Functions require JWT)

### 9.7 Performance
- [ ] Images: compress before upload (max 1200px, 80% quality)
- [x] Avatars: use `CachedNetworkImage` with memory/disk cache
- [x] City data: lazy-load on first search, cache in memory — `CitySearchService` lazy-loads JSON
- [x] Lists: `ListView.builder` with `itemExtent` where possible
- [x] Providers: use `autoDispose` on screen-specific providers to free memory
- [ ] **v2:** Measure and log screen render times in debug mode — deferred

### 9.8 Known Deferred Items
- [ ] Phone OTP verification during signup (Supabase mobile OTP setup has issues — deferred)
- [ ] Social Login (Google/Apple) — deferred
- [ ] Push notifications (FCM via Edge Function) — deferred
- [ ] Forgot password via mobile OTP (only email supported) — deferred
- [ ] Real distance calculation (currently mocked) — deferred
- [ ] Admin POD review stage (bypassed in current admin app) — deferred
- [ ] Voice message transcription (speech-to-text via Google Cloud/Whisper) — deferred
- [ ] Data export / "Download My Data" — deferred (placeholder button in Settings)
- [ ] Additional languages beyond Hindi — deferred

---

## PHASE 10: Easy-Win Features (NEW — v2) 🛠️
> These are low-effort, high-impact features that improve the product without adding complexity.
> All are optional but recommended. None require backend changes.
> **Status:** ALL COMPLETE except 10.1 (onboarding tooltips — deferred).

### 10.1 Onboarding Tooltips (First-Time User)
- [ ] On first login as Supplier: highlight "Post New Load" button with tooltip overlay
- [ ] On first login as Trucker: highlight search form with tooltip "Search for loads on your route"
- [ ] Track `has_seen_onboarding` in `SharedPreferences`
- [ ] Dismiss on tap anywhere

### 10.2 Quick Actions from Dashboard
- [x] **Supplier:** "Repeat Last Load" button (pre-fills Post Load wizard with last load's data) — `SmartDefaults.getLastRoute()` on supplier dashboard
- [ ] **Trucker:** "Popular Routes" section showing top 5 routes with load counts — deferred

### 10.3 Load Expiry Countdown
- [x] Active loads show "Expires in 2d 5h" countdown on load cards — `_ExpiryCountdown` widget in `my_loads_screen.dart`
- [x] Loads auto-expire after 7 days — DB default updated in migration `20260207000001_v3_schema_improvements.sql`
- [x] Warning color when < 24h remaining — red text + timer icon

### 10.4 Copy-to-Clipboard Actions
- [x] Tap phone number on profile → copy to clipboard + snackbar "Copied" — supplier & trucker profile screens
- [x] Tap email on profile → copy to clipboard — supplier & trucker profile screens
- [x] Share load details as formatted text — `share_plus` + share icon in load detail AppBar

### 10.5 Confirmation Dialogs for Destructive Actions
- [x] Deactivate Load: "Are you sure? This load will be removed from search results." — `AppDialogs.confirm()` in load detail screen
- [x] Delete Truck: "Remove [KA-01-XX-1234]? This cannot be undone." — `_deleteTruck()` in `my_fleet_screen.dart`
- [x] Switch Role: "You will be logged out. Continue?" — via `AppDialogs.confirm()` in settings
- [x] Logout: "Are you sure you want to log out?" — via `AppDialogs.confirm()` in settings
- [x] All use consistent dialog style: title, description, Cancel (text button) + Confirm (red/teal button) — `AppDialogs` utility

### 10.6 Smart Defaults
- [x] Post Load: remember last used From/To cities — `SmartDefaults.saveLastRoute()` / `getLastRoute()`
- [x] Find Loads: remember last search query — `SmartDefaults.saveLastSearch()` / `getLastSearch()`
- [x] Add Truck: remember last used body type — `SmartDefaults.saveLastBodyType()` / `getLastBodyType()`
- [x] Pickup Date: default to tomorrow — already in `post_load_screen.dart`

### 10.7 Accessibility Basics
- [x] GradientButton wrapped with `Semantics` (button label, enabled state)
- [x] All icon buttons have `tooltip` for screen readers
- [x] Minimum tap target: 48x48px — enforced via button constraints
- [x] Color contrast: WCAG AA (4.5:1 for text, 3:1 for large text) — verified in color palette
- [x] Focus order follows visual layout

---

## PHASE 11: User Flow Diagrams & Wiring (NEW — v3)
> Complete end-to-end user journeys mapped to screens, DB tables, RLS policies, and providers.

### 11.1 Supplier Journey — End to End
```
[Install App]
  → Splash → /login
  → Signup (First Name, Last Name, Email, +91 Mobile, Password)
      DB: auth.users (email, phone) → trigger → profiles (full_name, mobile, email)
  → Email Confirmation → Login
      DB: auth.users.email_confirmed_at set
  → Role Selection: "I am a Supplier"
      DB: profiles.current_role = 'supplier'
      DB: INSERT suppliers (id, company_name) — company_name collected here or in verification
  → Supplier Dashboard (/supplier-dashboard)
      READ: profiles (name, verification_status), suppliers (company_name, active_loads_count)
      READ: loads WHERE supplier_id = me AND status = 'active' (recent 3)
      READ: conversations WHERE supplier_id = me (unread count)
  → Verification (/supplier-verification)
      WRITE: profiles (aadhaar_*, pan_*, avatar_url, verification_status = 'pending')
      WRITE: suppliers (business_licence_*, gst_*)
      STORAGE: verification-docs bucket
      ADMIN: admin sees pending → verifies/rejects → profiles.verification_status = 'verified'/'rejected'
  → Post Load (/post-load) [GATE: verification_status = 'verified']
      WRITE: loads (supplier_id, origin_*, dest_*, material, weight, price, pickup_date, status='active')
  → My Loads (/my-loads)
      READ: loads WHERE supplier_id = me (Active tab: status IN ('active','booked','in_transit'), History: status IN ('completed','cancelled','expired'))
  → Chat (/messages → /chat/:id)
      READ: conversations WHERE supplier_id = me, JOIN profiles for trucker name
      READ/WRITE: messages WHERE conversation_id IN (my conversations)
      REALTIME: subscribe to messages table changes
  → Accept Deal (in chat)
      WRITE: loads.status = 'booked', loads.assigned_trucker_id = trucker_id
      WRITE: messages (system message, subtype: 'deal_accepted')
  → Make Super (/super-load-request/:loadId) [GATE: payout_profiles EXISTS]
      WRITE: loads.is_super_load = true, loads.super_status = 'requested'
      ADMIN: ops_admin assigns truck → loads.super_status = 'assigned', loads.assigned_truck_id
  → Super Dashboard (/supplier/super-dashboard)
      READ: loads WHERE supplier_id = me AND is_super_load = true
```

### 11.2 Trucker Journey — End to End
```
[Install App]
  → Splash → /login
  → Signup → Email Confirmation → Login → Role Selection: "I am a Trucker"
      DB: profiles.current_role = 'trucker'
      DB: INSERT truckers (id) — ratings/trips default to 0
  → Find Loads (/find-loads) — Trucker Dashboard
      READ: profiles (name, verification_status), truckers (total_trips, rating)
      SEARCH: loads WHERE status = 'active' AND origin/dest match (no verification gate for search)
  → Verification (/trucker-verification)
      WRITE: profiles (aadhaar_*, pan_*, avatar_url, verification_status = 'pending')
      WRITE: truckers (dl_*)
      STORAGE: verification-docs bucket
  → Add Truck (/add-truck)
      WRITE: trucks (owner_id = me, truck_number, body_type, tyres, capacity, rc_photo_url, status='pending')
      ADMIN: admin verifies RC → trucks.status = 'verified'/'rejected'
  → Chat Now (on load card) [GATE: verification_status = 'verified']
      WRITE: conversations (load_id, supplier_id, trucker_id) — getOrCreate
      WRITE: messages (text, truck_card, location, document)
  → Booking Confirmed (supplier accepts deal)
      READ: messages WHERE subtype = 'deal_accepted'
      → "Start Trip" CTA → loads.status = 'in_transit'
  → My Trips (/my-trips)
      READ: loads WHERE assigned_trucker_id = me AND status IN ('in_transit','completed')
      WRITE: loads.status updates (loading → in_transit → completed)
      WRITE: loads.pod_photo_url (Super Loads — upload POD)
```

### 11.3 Admin ↔ User Interaction Points
```
Admin App (separate app — com.tranzfort.admin) interacts with user data at these points:

1. VERIFICATION REVIEW
   Admin reads: profiles (verification_status='pending'), suppliers/truckers docs
   Admin writes: profiles.verification_status = 'verified'/'rejected', profiles.verification_rejection_reason
   Admin writes: audit_logs (action='user_verified'/'user_rejected')
   → User sees: status banner change on verification screen

2. TRUCK VERIFICATION
   Admin reads: trucks (status='pending'), trucks.rc_photo_url
   Admin writes: trucks.status = 'verified'/'rejected', trucks.rejection_reason, trucks.verified_by
   Admin writes: audit_logs (action='truck_verified'/'truck_rejected')
   → User sees: StatusChip change on truck card

3. SUPER LOAD OPS
   Admin reads: loads WHERE is_super_load=true AND super_status='requested'
   Admin writes: loads.super_status = 'processing'→'assigned', loads.assigned_truck_id, loads.assigned_by
   Admin writes: audit_logs (action='super_load_assigned')
   → User sees: Super Dashboard timeline progress

4. PAYOUT VERIFICATION
   Admin reads: payout_profiles (status='pending')
   Admin writes: payout_profiles.status = 'verified'/'rejected', payout_profiles.verified_by
   Admin writes: audit_logs (action='payout_verified'/'payout_rejected')
   → User sees: StatusChip on payout profile screen

5. USER MANAGEMENT
   Admin reads: profiles (all users), suppliers, truckers
   Admin writes: profiles.is_banned = true/false, profiles.ban_reason
   Admin writes: audit_logs (action='user_banned'/'user_unbanned')
   → User sees: blocked from login (check is_banned on splash/login)

6. SUPPORT TICKETS
   Admin reads: support_tickets, support_ticket_messages
   Admin writes: support_tickets.status, support_tickets.assigned_to
   Admin writes: support_ticket_messages (is_admin=true)
   → User sees: ticket status update, admin reply in ticket thread
```

---

## PHASE 12: Database Schema Wiring & Improvements (NEW — v3)
> Review of existing schema against app requirements. Identifies gaps and recommends improvements.

### 12.1 Schema Improvements — Migration Required
> These are recommended schema changes. Create as a new migration file: `YYYYMMDD_v3_improvements.sql`

- [x] **`profiles` table — add privacy consent fields:** ✅ Migration: `20260207000001_v3_schema_improvements.sql`
  ```sql
  ALTER TABLE public.profiles ADD COLUMN privacy_consent_at TIMESTAMP;
  ALTER TABLE public.profiles ADD COLUMN privacy_consent_version VARCHAR(10);
  ALTER TABLE public.profiles ADD COLUMN data_deletion_requested_at TIMESTAMP;
  ALTER TABLE public.profiles ADD COLUMN country_code VARCHAR(5) DEFAULT '+91';
  ALTER TABLE public.profiles ADD COLUMN preferred_language VARCHAR(5) DEFAULT 'en';
  ```

- [ ] **`profiles` table — make `full_name` NOT NULL:**
  ```sql
  ALTER TABLE public.profiles ALTER COLUMN full_name SET NOT NULL;
  ```
  > Currently nullable — causes issues when displaying names. Signup already requires it.

- [ ] **`profiles` table — add `first_name` and `last_name` columns (optional, for future):**
  > NOT required for v1. Keep `full_name` as primary. If needed later, split via migration.

- [x] **`loads` table — reduce default expiry from 30 days to 7 days:** ✅ in migration
  ```sql
  ALTER TABLE public.loads ALTER COLUMN expires_at SET DEFAULT (NOW() + INTERVAL '7 days');
  ```
  > 30 days is too long for freight loads. 7 days is industry standard. Configurable via `feature_flags`.

- [x] **`loads` table — add `trip_status` column for trucker trip tracking:**
  ```sql
  CREATE TYPE trip_stage AS ENUM ('not_started', 'reached_pickup', 'loading', 'in_transit', 'reached_destination', 'unloading', 'delivered');
  ALTER TABLE public.loads ADD COLUMN trip_stage trip_stage DEFAULT 'not_started';
  ```
  > ✅ Migration: `20260206000001_trip_stage_column.sql`

- [x] **`messages` table — add `voice_url` and `voice_duration_seconds` for voice messages:** ✅ in migration
  ```sql
  ALTER TABLE public.messages ADD COLUMN voice_url TEXT;
  ALTER TABLE public.messages ADD COLUMN voice_duration_seconds INTEGER;
  ```
  > Voice messages use `message_type = 'voice'`. Need to add to enum:
  ```sql
  ALTER TYPE message_type ADD VALUE 'voice';
  ```

- [x] **`conversations` table — add `last_message_text` for preview without extra query:** ✅ in migration
  ```sql
  ALTER TABLE public.conversations ADD COLUMN last_message_text TEXT;
  ```
  > Update via trigger when new message is inserted (same trigger that updates `last_message_at`).

- [x] **Update `update_conversation_timestamp` trigger to also set `last_message_text`:** ✅ in migration
  ```sql
  CREATE OR REPLACE FUNCTION update_conversation_timestamp()
  RETURNS TRIGGER AS $$
  BEGIN
      UPDATE public.conversations
      SET last_message_at = NEW.created_at,
          last_message_text = CASE
              WHEN NEW.message_type = 'text' THEN LEFT(NEW.text_content, 100)
              WHEN NEW.message_type = 'voice' THEN '🎤 Voice message'
              WHEN NEW.message_type = 'truck_card' THEN '🚛 Truck details'
              WHEN NEW.message_type = 'location' THEN '📍 Location'
              WHEN NEW.message_type = 'document' THEN '📄 Document'
              WHEN NEW.message_type = 'system' THEN NEW.text_content
              ELSE 'New message'
          END
      WHERE id = NEW.conversation_id;
      RETURN NEW;
  END;
  $$ LANGUAGE plpgsql;
  ```

- [ ] **`indian_cities` table — not needed for user app (client uses bundled JSON)**
  > Keep in DB for admin tooling only. No changes needed.

- [x] **Add `user_consents` table for GDPR audit trail:** ✅ in migration
  ```sql
  CREATE TABLE public.user_consents (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      consent_type VARCHAR(50) NOT NULL, -- 'privacy_policy', 'terms_of_service', 'marketing'
      consent_version VARCHAR(10) NOT NULL, -- '1.0', '1.1'
      consented_at TIMESTAMP NOT NULL DEFAULT NOW(),
      ip_address INET,
      user_agent TEXT
  );
  CREATE INDEX idx_user_consents_profile ON public.user_consents(profile_id);
  ```

### 12.2 RLS Policy Improvements

- [ ] **`loads` SELECT policy — allow assigned trucker to see booked/in_transit loads:**
  ```sql
  -- Current policy only shows 'active' loads to all users.
  -- Truckers need to see loads assigned to them (booked, in_transit, completed).
  CREATE POLICY "Truckers can view assigned loads"
      ON public.loads FOR SELECT
      TO authenticated
      USING (
          assigned_trucker_id = auth.uid()
          AND status IN ('booked', 'in_transit', 'completed')
      );
  ```

- [x] **`loads` UPDATE policy — allow assigned trucker to update trip_stage:**
  ```sql
  CREATE POLICY "Assigned truckers can update trip stage"
      ON public.loads FOR UPDATE
      TO authenticated
      USING (assigned_trucker_id = auth.uid())
      WITH CHECK (assigned_trucker_id = auth.uid());
  ```
  > ✅ Included in migration `20260206000001_trip_stage_column.sql`

- [ ] **`profiles` SELECT — allow public read of non-sensitive fields for chat name resolution:**
  > Current policy: users can only view their OWN profile. This blocks chat name resolution.
  > Solution: Create a `public_profiles` VIEW or add a policy for basic fields:
  ```sql
  CREATE POLICY "Authenticated users can view basic profile info"
      ON public.profiles FOR SELECT
      TO authenticated
      USING (true);
  ```
  > **Security note:** This exposes all profile columns. Better approach: use a VIEW:
  ```sql
  CREATE VIEW public.public_profiles AS
  SELECT id, full_name, avatar_url, current_role, verification_status
  FROM public.profiles;
  -- Grant SELECT to authenticated
  ```
  > App queries `public_profiles` for name resolution, `profiles` for own full profile.

- [ ] **`trucks` SELECT — allow suppliers to see verified trucks shared in chat:**
  ```sql
  CREATE POLICY "Authenticated users can view verified trucks"
      ON public.trucks FOR SELECT
      TO authenticated
      USING (status = 'verified');
  ```

### 12.3 Schema-to-Screen Wiring Map
| Screen | READ Tables | WRITE Tables | RLS Policy |
|--------|------------|--------------|------------|
| Splash | profiles | — | Own profile |
| Login | — | auth.users (via Supabase Auth) | — |
| Signup | — | auth.users, profiles (trigger) | — |
| Role Selection | — | profiles (current_role) | Own profile update |
| Supplier Dashboard | profiles, suppliers, loads, conversations | — | Own profile, own loads, own conversations |
| Post Load | — | loads | Verified supplier insert |
| My Loads | loads | loads (status update) | Own loads |
| Load Detail | loads, conversations, public_profiles | — | Own loads + active loads |
| Chat List | conversations, public_profiles, messages | — | Own conversations |
| Chat Screen | messages | messages | Own conversation messages |
| Find Loads | loads | — | Active loads (all) |
| My Fleet | trucks | trucks | Own trucks |
| Add Truck | — | trucks | Own trucks insert |
| My Trips | loads | loads (trip_stage, pod_photo_url) | Assigned loads |
| Verification | profiles, suppliers/truckers | profiles, suppliers/truckers | Own profile update |
| Profile | profiles, suppliers/truckers | — | Own profile |
| Payout Profile | payout_profiles | payout_profiles | Own payout |
| Settings | profiles | profiles | Own profile |
| Support | support_tickets, support_ticket_messages | support_tickets, support_ticket_messages | Own tickets |

---

## PHASE 13: Admin ↔ User App Relationship (NEW — v3)
> How the Admin app (separate codebase) affects user app data and UX.

### 13.1 Shared Infrastructure
- [ ] **Same Supabase project** — both apps connect to the same PostgreSQL database
- [ ] **Same auth system** — but admin users have `admin_users` table + `app_metadata.role` in JWT
- [ ] **Same Storage buckets** — admin reads from `verification-docs`, `truck-images`
- [ ] **Same Realtime** — admin could subscribe to new loads/tickets (not currently implemented)
- [ ] **Different bundle IDs:** User = `com.tranzfort.user`, Admin = `com.tranzfort.admin`

### 13.2 Admin Actions That Affect User App
| Admin Action | DB Change | User App Effect |
|-------------|-----------|-----------------|
| Verify User | `profiles.verification_status = 'verified'` | Verification screen shows green, Post Load unlocked |
| Reject User | `profiles.verification_status = 'rejected'`, `verification_rejection_reason` set | Verification screen shows error banner with reason |
| Verify Truck | `trucks.status = 'verified'` | Truck card shows green badge, truck available for sharing in chat |
| Reject Truck | `trucks.status = 'rejected'`, `rejection_reason` set | Truck card shows red badge with reason |
| Assign Super Load | `loads.super_status = 'assigned'`, `assigned_truck_id` set | Super Dashboard shows "Assigned" stage with truck number |
| Ban User | `profiles.is_banned = true` | User blocked on splash/login (check `is_banned` flag) |
| Verify Payout | `payout_profiles.status = 'verified'` | Payout screen shows green status |
| Reply to Ticket | `support_ticket_messages` INSERT | User sees admin reply in ticket thread |

### 13.3 User App — Ban Check Implementation
- [x] On splash screen: after fetching profile, check `is_banned` — already in `splash_screen.dart`
- [x] If banned: show full-screen "Account Suspended" with reason + "Contact Support" button — `_showBannedDialog()`
- [x] Do NOT allow navigation to any other screen — dialog is `barrierDismissible: false`
- [x] Check on every app resume (via `WidgetsBindingObserver.didChangeAppLifecycleState`) — `BanCheckWrapper` in `main.dart`

---

## PHASE 14: Data Privacy, GDPR & Legal Compliance (NEW — v3)
> India-specific: IT Act 2000, DPDP Act 2023 (Digital Personal Data Protection).
> Easy to implement without affecting user journey.

### 14.1 Privacy Consent During Signup
- [x] **Checkbox on signup screen (REQUIRED):** "I agree to the [Terms of Service] and [Privacy Policy]" — `signup_screen.dart` with `_consentChecked` + `recordConsent()`
  - Links open in external browser via `url_launcher`
  - Cannot create account without checking
  - On submit: record consent in `user_consents` table + set `profiles.privacy_consent_at` and `privacy_consent_version`
- [x] **Privacy Policy URL:** `https://tranzfort.com/privacy` (placeholder link in Settings + Signup)
- [x] **Terms of Service URL:** `https://tranzfort.com/terms` (placeholder link in Settings + Signup)

### 14.2 Data Minimisation
- [ ] **Aadhaar:** Store only last 4 digits in DB (`aadhaar_number` → `aadhaar_last4 VARCHAR(4)`). Photo URLs are in Supabase Storage with signed URLs (1-hour expiry).
  > **Migration:** `ALTER TABLE profiles RENAME COLUMN aadhaar_number TO aadhaar_last4; ALTER TABLE profiles ALTER COLUMN aadhaar_last4 TYPE VARCHAR(4);`
  > **App:** Mask on client before sending. Display as `XXXX XXXX 1234`.
- [ ] **PAN:** Already stored as full 10-char (needed for verification). OK to keep — PAN is not classified as sensitive PII under DPDP Act.
- [ ] **Bank Account:** Already storing last4 only in `payout_profiles.account_number_last4`. ✅
- [ ] **Mobile:** Stored in full (needed for OTP login). OK — legitimate purpose.
- [ ] **DL Number:** Store full (needed for verification). OK — legitimate purpose.

### 14.3 Data Retention & Deletion
- [x] **"Delete My Account" in Settings:** — `_showDeleteAccountDialog()` in `settings_screen.dart`
  - Tap → confirmation dialog: "This will permanently delete your account and all data. This cannot be undone."
  - On confirm: set `profiles.data_deletion_requested_at = NOW()`
  - Show message: "Your account will be deleted within 30 days. Contact support@tranzfort.com to cancel."
  - **Backend (Edge Function or cron):** After 30 days, cascade delete: `auth.users` row → triggers cascade to profiles, suppliers/truckers, loads (deactivate), conversations, messages, payout_profiles
  - **Supabase Storage:** Delete user's files from `verification-docs`, `avatars` buckets
- [x] **Data export (optional — DPDP Act right):** "Download My Data" button in Settings — placeholder with "Coming soon"
  - Generates JSON with: profile, loads, conversations (metadata only), trucks
  - Served as downloadable file or emailed
  - **Deferred for v1** — add as placeholder button with "Coming soon" message

### 14.4 Secure Data Handling
- [ ] **No PII in logs:** Never log mobile numbers, Aadhaar, PAN, passwords, auth tokens
- [ ] **Signed URLs:** All document URLs expire in 1 hour. Never cache signed URLs.
- [ ] **Supabase Storage RLS:** Buckets configured so users can only access their own files
- [ ] **No analytics PII:** If adding analytics later, strip PII before sending events

### 14.5 Legal Pages (Static — host on web)
- [ ] **Privacy Policy** — must cover: data collected, purpose, storage, sharing, retention, deletion rights, contact
- [ ] **Terms of Service** — must cover: user responsibilities, prohibited use, liability, dispute resolution
- [ ] **Refund Policy** (for Super Loads) — payment terms, cancellation, refund timeline
- [ ] All accessible from: Signup screen (checkbox links), Settings screen, Help & Support screen

---

## PHASE 15: India-Only Signup — +91 Mobile (NEW — v3)
> App is India-only. Enforce +91 country code. Simplify mobile input.

### 15.1 Signup Screen Changes
- [x] **Mobile field:** Prefix with non-editable "+91" label/badge — `signup_screen.dart` with `prefixIcon` Container
  - User types only 10 digits
  - Validation: `Validators.indianMobile` — `^[6-9]\d{9}$`
  - `keyboardType: TextInputType.phone`, `maxLength: 10`, `FilteringTextInputFormatter.digitsOnly`
- [x] **Store in DB as:** `+91XXXXXXXXXX` — prepended in `_handleSignup()`
- [x] **Supabase Auth phone field:** Send as `+91XXXXXXXXXX`

### 15.2 Login Screen Changes
- [x] **Auto-detect mobile:** `_isMobileInput` detection + auto-prepend `+91` in `_handleLogin()`
- [x] **OTP login:** Always prepend `+91` in `_handleOtpLogin()`

### 15.3 Profile Display
- [x] **Display mobile as:** `+91 XXXXX XXXXX` — `Validators.displayIndianMobile()` used in both profile screens
- [x] **Helper function:** `Validators.displayIndianMobile(String? mobile)` in `validators.dart`

---

## PHASE 16: Hindi Language Support (NEW — v3)
> Flutter's built-in `flutter_localizations` + `intl` package makes this straightforward.
> Two ARB files: English (default) + Hindi. User selects in Settings.

### 16.1 Setup
- [x] **Add to `pubspec.yaml`:** `flutter_localizations`, `intl`, `generate: true` — already present
- [x] **Create `l10n.yaml` in project root:** — `l10n.yaml` exists with correct config
- [x] **Create ARB files:**
  - `lib/l10n/app_en.arb` — 65+ English strings
  - `lib/l10n/app_hi.arb` — 65+ Hindi translations

### 16.2 Key Strings to Localise (~150 strings)
- [x] **Auth:** login, signup, password, forgotPassword, welcomeBack, createAccount, etc.
- [x] **Supplier:** postLoad, myLoads, material, weight, price, etc.
- [x] **Trucker:** findLoads, myTrips, myFleet, addTruck, chatNow, etc.
- [x] **Chat:** sendMessage, noMessages
- [x] **Common:** settings, helpSupport, logout, switchRole, cancel, confirm, save, loading, error, retry, etc.
- [x] **Status labels:** active, completed, cancelled, pending, verified, rejected

### 16.3 App Integration
- [x] **`MaterialApp.router`:** `localizationsDelegates`, `supportedLocales`, `locale` wired in `main.dart`
- [x] **`localeProvider`:** `StateNotifierProvider<LocaleNotifier, Locale>` — reads/writes `SharedPreferences` key `preferred_language` — `locale_provider.dart`
- [x] **Settings screen:** Language selector bottom sheet (English / हिन्दी) — `_showLanguageDialog()` in `settings_screen.dart`
- [ ] **Usage in widgets:** Gradual migration to `AppLocalizations.of(context)!.key` — infrastructure ready, strings not yet wired to all widgets
- [x] **Fallback:** Flutter auto-falls back to English if Hindi translation missing

### 16.4 Hindi Translation Notes
- [x] Use **formal Hindi** (आप form) — applied in `app_hi.arb`
- [x] Keep **English technical terms** — "Load", "Truck", "OTP", "RC", "PAN", "Aadhaar", "Super Load", "POD" kept in English
- [x] **Numbers:** English numerals used
- [x] **City names:** English names used

---

## PHASE 17: Text-to-Speech — TTS (NEW — v3)
> Use `flutter_tts` package — uses platform-native TTS engines (no extra download, zero server cost).
> Android: Google TTS (pre-installed), iOS: AVSpeechSynthesizer. Both support Hindi.

### 17.1 Setup
- [x] **Add dependency:** `flutter_tts: ^4.0.2` — already in `pubspec.yaml`
- [x] **No additional permissions required** — TTS uses system speech engine

### 17.2 TTS Service — `core/services/tts_service.dart`
- [x] **Init:** `en-IN` default, `setSpeechRate(0.45)`, `setPitch(1.0)`, `setVolume(1.0)`
- [x] **Methods:** `speak()`, `stop()`, `isSpeaking`, `setLanguage()`, `dispose()`
- [x] **Singleton via Riverpod:** `ttsServiceProvider` in `auth_service_provider.dart`

### 17.3 Where to Use TTS
- [x] **Load Card (Find Loads):** `TtsButton` widget on each load card — reads route, material, weight, price
- [x] **Load Detail Screen:** `TtsButton` in AppBar — reads full load details via `_buildTtsText()`
- [ ] **Chat messages:** Long-press "Read Aloud" — deferred
- [ ] **Trucker Dashboard:** Read out stats — deferred
- [x] **Visual feedback:** Icon toggles play/stop, color changes while speaking
- [x] **Reusable widget:** `shared/widgets/tts_button.dart` — `TtsButton(text:, size:)`

---

## PHASE 18: Voice Messages in Chat (NEW — v3)
> Record and send voice messages in chat. Uses `record` package for recording + Supabase Storage for hosting.
> New message_type: `voice`. Renders as waveform bubble with play/pause.

### 18.1 Dependencies
- [x] `record: ^6.0.0` — cross-platform audio recording
- [x] `just_audio: ^0.9.39` — audio playback with seek/duration support
- [x] Skipped `audio_waveforms` — using simple progress bar + duration text instead

### 18.2 Recording Flow
- [x] **Input bar:** Mic icon replaces send button when text is empty — `chat_screen.dart`
- [x] **Tap to record:** Tap mic → starts recording, tap stop → sends. Cancel button (X) to discard.
- [x] **Recording UI:** Red stop button + elapsed seconds counter + cancel button
- [x] **Recording format:** AAC (`.m4a`) at 64kbps via `AudioEncoder.aacLc`
- [x] **Max duration:** 120 seconds — auto-stop at limit
- [x] **Permission:** Requests microphone permission via `permission_handler` on first use

### 18.3 Storage & DB
- [x] **Upload to Supabase Storage:** Bucket `voice-messages`, path: `{conversation_id}/{uuid}.m4a`
- [x] **Public URL:** via `getPublicUrl()` (bucket is private with RLS)
- [x] **DB:** `sendMessage(type: 'voice', voiceUrl:, voiceDurationSeconds:)` — already supported in `database_service.dart`

### 18.4 Voice Message Bubble — `voice_message_bubble.dart`
- [x] **Layout:** Sender/receiver alignment with `isMine` styling
- [x] **Content:** Play/Pause circle button + `LinearProgressIndicator` + duration text
- [x] **States:** Not played / Playing / Completed — auto-resets on completion
- [x] **Playback:** `just_audio` AudioPlayer streaming from URL
- [x] **Rendering:** `case 'voice':` in `_MessageBubble._buildContent()` renders `VoiceMessageBubble`

### 18.5 TTS Integration with Voice Messages
- [ ] **Long-press on voice message → "Transcribe" option (DEFERRED)**
  > Would require speech-to-text API (Google Cloud, Whisper). Too complex for v1.
  > Placeholder: show "Transcription coming soon" toast.

### 18.6 Supabase Storage Bucket Setup
- [x] **Create bucket:** `voice-messages` — in migration `20260207000001_v3_schema_improvements.sql`
- [x] **Config:** Private, 5MB limit, allowed MIME types: audio/mp4, audio/aac, audio/m4a, audio/mpeg
- [ ] **Auto-cleanup:** Lifecycle policy for 90-day deletion — deferred

---

## PHASE 19: App Permissions Strategy (NEW — v3)
> Request permissions ONLY when needed (just-in-time), NOT at install time.
> Android 13+ and iOS require runtime permissions. Show rationale before requesting.

### 19.1 Permission Dependency
- [x] **Add:** `permission_handler: ^11.3.1` — already in `pubspec.yaml`

### 19.2 Permission Matrix
| Permission | When Requested | Used By | Rationale Shown |
|-----------|---------------|---------|-----------------|
| **Camera** | First time user taps "Take Photo" in document upload or profile photo | Verification, Profile Photo, POD Upload | "TranZfort needs camera access to capture your documents for verification." |
| **Photo Library** | First time user taps "Choose from Gallery" | Verification, Profile Photo | "TranZfort needs photo access to select your documents." |
| **Microphone** | First time user taps mic icon in chat | Voice Messages | "TranZfort needs microphone access to record voice messages." |
| **Location** | First time user taps "Share Location" in chat | Location sharing in chat | "TranZfort needs your location to share it with the other party." |
| **Notifications** | After first successful login (one-time prompt) | Push notifications (future) | "Enable notifications to get updates on your loads and messages." |
| **Phone** | First time user taps "Call" button in chat | Direct calling via `url_launcher` | Not needed — `url_launcher` tel: scheme doesn't require permission |

### 19.3 Permission Flow Implementation
- [x] **`core/services/permission_service.dart`:** — fully implemented with rationale + settings dialogs
  ```dart
  class PermissionService {
    /// Check and request permission with rationale dialog
    Future<bool> requestPermission(
      Permission permission,
      BuildContext context, {
      required String title,
      required String rationale,
    }) async {
      final status = await permission.status;
      if (status.isGranted) return true;
      
      if (status.isDenied) {
        // Show rationale dialog first
        final shouldRequest = await _showRationaleDialog(context, title, rationale);
        if (!shouldRequest) return false;
        
        final result = await permission.request();
        return result.isGranted;
      }
      
      if (status.isPermanentlyDenied) {
        // Show "Open Settings" dialog
        await _showSettingsDialog(context, title);
        return false;
      }
      
      return false;
    }
  }
  ```

- [x] **Rationale dialog:** Bottom sheet with security icon, title, rationale, "Allow" + "Not Now" buttons
- [x] **Settings redirect dialog:** "Permission Required" → "Open Settings" button → `openAppSettings()`
- [x] **Riverpod provider:** `permissionServiceProvider` in `auth_service_provider.dart`

### 19.4 Platform Configuration

- [x] **Android `AndroidManifest.xml`:** — all permissions added
  ```xml
  <uses-permission android:name="android.permission.CAMERA" />
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
  <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" /> <!-- Android 13+ -->
  <uses-permission android:name="android.permission.RECORD_AUDIO" />
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS" /> <!-- Android 13+ -->
  <uses-permission android:name="android.permission.INTERNET" />
  ```

- [x] **iOS `Info.plist`:**
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>TranZfort needs camera access to capture documents for verification.</string>
  <key>NSPhotoLibraryUsageDescription</key>
  <string>TranZfort needs photo library access to select documents for verification.</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>TranZfort needs microphone access to record voice messages in chat.</string>
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>TranZfort needs your location to share it with the other party in chat.</string>
  ```

### 19.5 Permission UX Rules
- [ ] **NEVER block app launch** for permissions — all permissions are requested just-in-time
- [ ] **NEVER request all permissions at once** — only when the specific feature is used
- [ ] **Graceful degradation:** If permission denied, disable the specific feature with explanation (e.g., mic icon greyed out with tooltip "Microphone permission required")
- [ ] **Remember denial:** Don't re-ask on every tap. Check `isPermanentlyDenied` and show "Open Settings" instead
- [ ] **Notification permission:** Request once after first login, don't nag if denied

---

## Architecture Notes

### State Management
- **Riverpod** for all client state
- `FutureProvider` for one-shot data (profile, role, supplier data)
- `StreamProvider` for realtime data (auth state, messages)
- `StateProvider` for UI state (filters, form data, search query)
- `autoDispose` on screen-specific providers to free memory when screen is popped
- **Critical:** `invalidateAllUserProviders()` on EVERY auth transition (logout, login, switch role, OTP verify)

### Router Architecture
- GoRouter singleton with `_RouterNotifier` (NOT `GoRouterRefreshStream`)
- `_RouterNotifier` uses `ref.listen()` on `currentUserProvider` + `userRoleProvider` → calls `notifyListeners()`
- Redirect closure uses `ref.read()` to get current values dynamically
- Login/OTP screens handle post-auth navigation explicitly (invalidate → fetch role → navigate)
- Router does NOT redirect away from `/login` or `/otp-verification` when authenticated
- Role-based route guards: supplier routes blocked for truckers and vice versa

### Design System Architecture
- **Single source of truth:** `app_colors.dart`, `app_spacing.dart`, `app_typography.dart`
- **Centralised theme:** `app_theme.dart` configures ALL Material widget themes
- **No inline colors/sizes:** Every widget reads from theme or constants
- **Reusable widgets:** `GradientButton`, `GlassCard`, `StatusChip`, `StatCard`, `EmptyState`, `SkeletonLoader`
- **Consistent patterns:** Every screen follows: Scaffold + AppBar + Body (scrollable) + BottomNav/FAB

### File Structure (UPDATED — v2)
```
TranZfort/
├── lib/
│   ├── main.dart
│   └── src/
│       ├── app.dart
│       ├── core/
│       │   ├── config/
│       │   │   └── supabase_config.dart
│       │   ├── constants/
│       │   │   ├── app_colors.dart
│       │   │   ├── app_spacing.dart
│       │   │   └── app_typography.dart
│       │   ├── models/
│       │   │   ├── load_model.dart
│       │   │   ├── truck_model.dart
│       │   │   ├── conversation_model.dart
│       │   │   ├── message_model.dart
│       │   │   ├── payout_profile_model.dart
│       │   │   └── location_model.dart          # NEW — for city search results
│       │   ├── providers/
│       │   │   ├── auth_service_provider.dart
│       │   │   ├── supplier_providers.dart
│       │   │   ├── trucker_providers.dart
│       │   │   ├── chat_providers.dart
│       │   │   ├── connectivity_provider.dart   # NEW v2 — network status
│       │   │   └── language_provider.dart        # NEW v3 — locale state
│       │   ├── routing/
│       │   │   └── app_router.dart
│       │   ├── services/
│       │   │   ├── auth_service.dart
│       │   │   ├── database_service.dart
│       │   │   ├── storage_service.dart
│       │   │   ├── city_search_service.dart     # NEW v2 — fuzzy search on locations JSON
│       │   │   ├── tts_service.dart              # NEW v3 — text-to-speech wrapper
│       │   │   └── permission_service.dart       # NEW v3 — runtime permission handler
│       │   └── theme/
│       │       └── app_theme.dart
│       ├── features/
│       │   ├── auth/
│       │   │   └── presentation/screens/
│       │   │       ├── splash_screen.dart
│       │   │       ├── login_screen.dart
│       │   │       ├── signup_screen.dart
│       │   │       ├── otp_verification_screen.dart
│       │   │       ├── forgot_password_screen.dart
│       │   │       ├── reset_password_screen.dart
│       │   │       └── role_selection_screen.dart
│       │   ├── supplier/
│       │   │   └── presentation/screens/
│       │   │       ├── supplier_dashboard_screen.dart
│       │   │       ├── post_load_screen.dart
│       │   │       ├── my_loads_screen.dart
│       │   │       ├── load_detail_screen.dart
│       │   │       ├── super_load_request_screen.dart
│       │   │       ├── super_dashboard_screen.dart
│       │   │       ├── supplier_verification_screen.dart
│       │   │       ├── supplier_profile_screen.dart
│       │   │       └── payout_profile_screen.dart
│       │   ├── trucker/
│       │   │   └── presentation/screens/
│       │   │       ├── find_loads_screen.dart
│       │   │       ├── my_fleet_screen.dart
│       │   │       ├── add_truck_screen.dart
│       │   │       ├── my_trips_screen.dart
│       │   │       ├── trucker_verification_screen.dart
│       │   │       └── trucker_profile_screen.dart
│       │   ├── chat/
│       │   │   └── presentation/
│       │   │       ├── screens/
│       │   │       │   ├── chat_list_screen.dart
│       │   │       │   └── chat_screen.dart
│       │   │       └── widgets/
│       │   │           ├── message_bubble.dart
│       │   │           ├── truck_card_bubble.dart
│       │   │           ├── location_bubble.dart
│       │   │           ├── document_bubble.dart
│       │   │           ├── booking_confirmed_bubble.dart
│       │   │           ├── system_action_bubble.dart
│       │   │           └── voice_message_bubble.dart  # NEW v3
│       │   └── shared/
│       │       └── presentation/screens/
│       │           ├── settings_screen.dart
│       │           └── help_support_screen.dart
│       └── shared/
│           └── widgets/
│               ├── glass_card.dart
│               ├── gradient_button.dart
│               ├── bottom_nav_bar.dart
│               ├── app_drawer.dart
│               ├── skeleton_loader.dart
│               ├── empty_state.dart
│               ├── city_autocomplete_field.dart
│               ├── document_upload_widget.dart
│               ├── connectivity_banner.dart     # NEW
│               ├── refreshable_list.dart        # NEW
│               ├── status_chip.dart             # NEW v2
│               └── stat_card.dart               # NEW v2
│       └── l10n/                                # NEW v3 — localization
│           ├── app_en.arb                       # English (template, ~150 strings)
│           └── app_hi.arb                       # Hindi translations
├── assets/
│   ├── images/
│   │   ├── logo-tranzfort-transparent.png
│   │   └── icon-user.jpg
│   ├── svg/                                 # NEW v2 — empty state illustrations
│   │   ├── empty_loads.svg
│   │   ├── empty_fleet.svg
│   │   ├── empty_chat.svg
│   │   └── empty_trips.svg
│   └── data/
│       └── indian_locations.json             # EXPANDED v2 — 8000+ locations
├── l10n.yaml                                # NEW v3 — l10n config
├── pubspec.yaml
├── analysis_options.yaml
└── test/
    └── smoke_test.dart
```

### Key Bug Fixes to Implement From Day 1
1. **Cross-login contamination:** Use `_RouterNotifier` pattern, `invalidateAllUserProviders()` on every auth transition
2. **Optimistic chat send:** Add to local list immediately, deduplicate on realtime callback
3. **Logout lifecycle:** Invalidate providers BEFORE `signOut()` (while ref is alive)
4. **Chat unread refresh:** Reload conversations on return from chat screen
5. **Name resolution:** Use `full_name` with email prefix fallback, never show raw UUIDs
6. **Profile persistence:** `ensureProfileExists()` after all auth flows (handles phone OTP auto-signup)
7. **Payout security:** Never store full account number — mask on client, store only last4
8. **Supabase key format:** Use legacy JWT anon key (not `sb_publishable_*`) for Edge Function compatibility

---

**Total screens:** ~25
**Total shared widgets:** ~19 (v2: connectivity banner, refreshable list, status chip, stat card)
**Total chat widgets:** ~7 bubble types (v3: +voice message bubble)
**Total services:** 6 (auth, database, storage, city search, tts, permission)
**Total providers:** ~19 (v3: +language, +tts)
**Total models:** 6 (load, truck, conversation, message, payout, location)
**Localization files:** 2 ARB files (~150 strings each)
**DB migrations:** 1 new migration file (v3 schema improvements)
**New Supabase Storage bucket:** `voice-messages`

**Estimated effort:** 3-4 focused sessions for core, +1 for v2 polish, +1 for v3 features (voice, Hindi, TTS, permissions, privacy)
