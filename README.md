# 🧾 CholeBature — Finance Tracker

> A clean, offline personal finance app built with Flutter. Track expenses, income, borrows, lends, budgets, and scheduled transactions, all in one place.

---

## ✨ Features

### 💰 Transactions
- Add, edit, and delete **income**, **expense**, **borrow**, and **lend** transactions
- **14 built-in categories** with icons and color coding (Food, Travel, Health, Salary, etc.)
- **Custom categories** — create your own expense/income categories with a full HSV color picker and icon picker (see [Custom Categories](#-custom-categories))
- Attach notes to any transaction
- Swipe-to-delete with confirmation dialog
- Tap any transaction to view a full **detail screen**

### ⚡ Quick Log
- **Quick Log sheet** — add multiple transactions in one go from the Transactions tab
- Each row is collapsible; expand to set title, amount, category, type, and date independently
- Live **summary strip** shows running income, expense, net, and ready-row count
- Validates all rows before saving — highlights incomplete rows inline

### 🔍 Search
- **Full-text search** across transaction title and notes, accessible from the Transactions screen
- Search result count badge with the active query
- Results shown as a flat list (no date grouping) for quick scanning
- Summary bar updates to reflect the searched subset

### 📊 Dashboard
- **Summary cards** showing Income, Expenses, Net Savings, Net Worth, Borrowed & Lent
  - Net Worth = Net Savings − what you owe + what others owe you
- **Category breakdown** pie chart with interactive touch — custom categories appear as their own slices
- **Budget progress bars** inline on the dashboard
- **Average insight card** — compares current period vs. historical average (e.g. "12% more than average month 🎉")
- Filter by **Day / Week / Month / Year / All time / Custom range**
- Navigate periods with **prev/next arrows** or tap the label to open a **calendar/month/year picker**

### 📅 Scheduled Transactions
- Schedule **one-time or recurring** transactions (Daily, Weekly, Monthly)
- **Weekly day picker** — choose specific days (Mon–Sun)
- **Variable amount** support — enter the amount at mark-done time
- **Mark Done**, **Skip Cycle**, **Pause/Resume**, and **Edit** actions
- Sections: **Overdue**, **Due Today**, **Upcoming**
- Multiple **reminder offsets** per transaction (at due time, 15 min, 1 hr, 1 day before, etc.)
- Badge count on bottom nav showing overdue items

### 🤝 Borrow & Lend
- Track money **you owe** (Borrowed) and **owed to you** (Lent)
- **Mark as Fully Settled** — automatically creates a counter-transaction
- **Partial settlement** — records partial payments and shows a progress bar
- Settled entries are read-only with a detail sheet
- Net outstanding position card showing who owes whom
- Swipe-to-delete support

### 🎨 Custom Categories
- Create **expense** or **income** custom categories with a full **HSV color picker** (hue, saturation, brightness sliders) and a curated **icon picker** (30+ icons)
- Live preview of icon + name + color before saving
- **Soft-delete** — hides the category from pickers while preserving all existing transactions that reference it; name still shown on old transactions
- **Hard-delete** — permanently removes the record (use only when no transactions reference it)
- **Restore** soft-deleted categories back to active
- Duplicate name detection (also prevents clashing with built-in category names)
- Custom categories appear in **filter chips**, the **pie chart**, and **category breakdown list**
- Managed from Settings → Manage Categories

### 🎯 Budgets
- Set **Daily (Weekday/Weekend)**, **Weekly**, or **Monthly** spending limits
- Progress bar with colour-coded status (green → amber → red)
- Shows remaining amount or how much over budget
- Period-over-period insight text ("Spent ₹500 less than last period 🎉")

### 🔒 App Lock
- **PIN** (4–6 digits) or **Password** lock
- **Auto-lock** after configurable timeout (Immediately, 15s, 30s, 1min, 5min, 15min, 30min)
- Lock triggers on app background/resume lifecycle
- Credentials stored securely using `flutter_secure_storage` with SHA-256 hashing

### 🌗 Theming
- **Light** and **Dark** modes with a GitHub-inspired neutral dark palette
- **System default** support
- Theme cycles with one tap from the dashboard or Settings
- Persisted across app restarts via `shared_preferences`

### 📤 Export & Import
- **Export all data** to a single unified CSV (transactions + scheduled + custom category definitions) — saved to Downloads and shared via share sheet
- **Import from CSV** — supports the unified backup format (with custom categories) and legacy transaction-only CSVs
- Custom categories are imported first so transactions that reference them are correctly linked
- Duplicate detection on import for transactions, scheduled items, and custom categories (skips duplicates, reports counts)
- Import preview dialog before committing

### 🔔 Notifications
- Real push notifications via `flutter_local_notifications`
- Scheduled at exact fire times (nextDue − reminderOffset)
- Graceful fallback to inexact alarms if exact alarms are not permitted
- Immediate overdue notification on app launch/resume
- Notifications cancelled and rescheduled automatically on edit/delete

### ⭐ Feedback
- In-app feedback screen with **star rating** (1–5) + optional message
- Submits silently to a Google Form in the background
- Falls back to opening the form in browser on network-blocked devices

---

## 🗂️ Folder Structure

```
lib/
├── main.dart                          # App entry, theme provider, ProviderScope
│
├── models/
│   ├── transaction_model.dart         # Transaction, TransactionCategory, TransactionType, SortOption
│   ├── future_transaction_model.dart  # FutureTransaction, RecurrenceType, FutureStatus
│   ├── borrow_lend_model.dart         # BorrowLendEntry, BorrowLendSummary, SettlementStatus
│   ├── budget_model.dart              # Budget, BudgetPeriod, BudgetResult
│   ├── custom_category_model.dart     # CustomCategory, CustomCategoryType, kCategoryIconOptions
│   └── security_model.dart           # SecuritySettings, LockType
│
├── providers/
│   ├── transaction_provider.dart      # transactionListProvider, filterProvider, summaryProvider,
│   │                                  #   borrowLendProvider, budgetListProvider, budgetResultsProvider,
│   │                                  #   averageInsightProvider, categoryExpenseEntriesProvider,
│   │                                  #   FilterState, FilterNotifier
│   ├── budget_provider.dart           # Re-exports from transaction_provider
│   ├── custom_category_provider.dart  # customCategoryProvider, CustomCategoryNotifier
│   ├── future_transaction_provider.dart # futureTransactionProvider, overdueCountProvider
│   ├── search_provider.dart           # transactionSearchProvider
│   └── security_provider.dart        # securitySettingsProvider, appLockedProvider
│
├── screens/
│   ├── splash_screen.dart             # Animated splash with loading bar
│   ├── home_shell.dart                # Bottom nav shell, lifecycle observer, lock check
│   ├── dashboard_screen.dart          # Main dashboard with filter, summary, chart
│   ├── transactions_screen.dart       # Paginated transaction list with filter bar + search
│   ├── future_transactions_screen.dart # Scheduled transactions list
│   ├── borrow_lend_screen.dart        # Borrow/lend list with summary cards
│   ├── budget_screen.dart             # Budget list and add/edit sheet
│   ├── manage_categories_screen.dart  # Custom category list, create/edit/delete sheet
│   ├── settings_screen.dart           # Theme, lock, data, feedback, about
│   ├── lock_screen.dart               # PIN pad / password input
│   ├── transaction_detail_screen.dart # Full detail view for a transaction
│   ├── add_transaction_sheet.dart     # Bottom sheet: add/edit transaction (supports custom cats)
│   ├── add_future_transaction_sheet.dart # Bottom sheet: add/edit scheduled tx
│   ├── quick_log_sheet.dart           # Bottom sheet: batch-add multiple transactions
│   └── feedback_screen.dart           # Star rating + message feedback form
│
├── services/
│   ├── database_service.dart          # SQLite singleton (sqflite), all CRUD + queries
│   ├── notification_service.dart      # flutter_local_notifications wrapper, scheduling
│   ├── security_service.dart          # flutter_secure_storage, SHA-256 hash, PIN length
│   ├── export_service.dart            # CSV export (transactions + scheduled + custom categories)
│   └── import_service.dart            # CSV import, unified + legacy format, id remapping
│
├── theme/
│   └── app_theme.dart                 # DarkColors, LightColors, CategoryColors,
│                                      #   CategoryInfo, categoryInfoMap, AppTheme, AppColors extension
│
├── utils/
│   └── formatters.dart                # formatCurrency, formatCompact, formatDate, formatTime, etc.
│
└── widgets/
    ├── summary_cards.dart             # BigCard (savings/net worth) + MiniCard (income/expense/borrow/lend)
    ├── category_chart.dart            # fl_chart PieChart — built-in + custom category slices
    ├── budget_bar.dart                # Budget progress rows for dashboard
    ├── filter_bar.dart                # Period tabs, prev/next nav, advanced filter sheet (custom cats)
    ├── transaction_tile.dart          # Swipeable transaction row
    ├── borrow_lend_tile.dart          # Borrow/lend tile with settlement actions
    ├── category_icon.dart             # Rounded icon container — resolves built-in or custom category
    └── loading_overlay.dart           # Full-screen loading overlay + AppSpinner
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter (Dart) |
| **State Management** | Riverpod (`flutter_riverpod`) |
| **Local Database** | SQLite via `sqflite` |
| **Fonts** | Google Fonts — DM Sans (`google_fonts`) |
| **Charts** | `fl_chart` |
| **Notifications** | `flutter_local_notifications` |
| **Timezone support** | `timezone` |
| **Secure Storage** | `flutter_secure_storage` |
| **Shared Preferences** | `shared_preferences` |
| **CSV** | `csv` |
| **File Picker** | `file_picker` |
| **File Sharing** | `share_plus` |
| **Path Provider** | `path_provider` |
| **HTTP** | `http` |
| **URL Launcher** | `url_launcher` |
| **Animations** | `flutter_animate` |
| **UUID** | `uuid` |
| **Hashing** | `crypto` (SHA-256) |
| **Internationalization** | `intl` |
| **Layout Helpers** | `gap` |

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>=3.x`
- Dart SDK `>=3.x`
- Android Studio / VS Code with Flutter plugin
- A connected Android or iOS device / emulator

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/your-username/cholebature.git
cd cholebature

# 2. Install dependencies
flutter pub get

# 3. Run the app
flutter run
```

### Build for Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS
flutter build ios --release
```

---

## ⚙️ Android Setup

Add the following permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Inside <manifest> -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

<!-- Inside <application> -->
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver">
    <intent-filter>
        <action android:name="com.dexterous.flutterlocalnotifications.NOTIFICATION_SCHEDULED"/>
    </intent-filter>
</receiver>
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    </intent-filter>
</receiver>
```

---

## 🗄️ Database Schema

The app uses a local SQLite database (`cholebature_v4.db`, schema version 5) with four tables:

**`transactions`**
| Column | Type | Description |
|---|---|---|
| `id` | TEXT PK | UUID |
| `title` | TEXT | Transaction title / person name |
| `amount` | REAL | Amount in ₹ |
| `category` | INTEGER | `TransactionCategory` enum index |
| `type` | INTEGER | `TransactionType` enum index |
| `date` | INTEGER | Milliseconds since epoch |
| `note` | TEXT | Optional note (also encodes settlement state) |
| `custom_category_id` | TEXT | FK to `custom_categories.id`, nullable |

**`future_transactions`**
| Column | Type | Description |
|---|---|---|
| `id` | TEXT PK | UUID |
| `title` | TEXT | Title |
| `amount` | REAL | Amount (0 = variable) |
| `category` | INTEGER | Category enum index |
| `type` | INTEGER | Type enum index |
| `note` | TEXT | Optional note |
| `recurrence_type` | INTEGER | `RecurrenceType` enum index |
| `recurrence_days` | TEXT | JSON array of weekday ints |
| `next_due` | INTEGER | Milliseconds since epoch |
| `status` | INTEGER | `FutureStatus` enum index |
| `reminder_offsets` | TEXT | JSON array of minute offsets |
| `created_at` | INTEGER | Milliseconds since epoch |

**`budgets`**
| Column | Type | Description |
|---|---|---|
| `id` | TEXT PK | UUID |
| `period` | INTEGER | `BudgetPeriod` enum index (UNIQUE) |
| `amount` | REAL | Budget limit in ₹ |
| `active` | INTEGER | 1 = active |

**`custom_categories`**
| Column | Type | Description |
|---|---|---|
| `id` | TEXT PK | UUID |
| `name` | TEXT | Display name |
| `color_value` | INTEGER | ARGB color int |
| `icon_code_point` | INTEGER | Material icon codepoint |
| `icon_font_family` | TEXT | Font family (default `MaterialIcons`) |
| `deleted` | INTEGER | 1 = soft-deleted |
| `created_at` | INTEGER | Milliseconds since epoch |
| `category_type` | INTEGER | `CustomCategoryType` enum index (0=expense, 1=income) |

---

## 📦 CSV Backup Format

Exports use a unified CSV with a `DataType` column:

```
DataType | ID | Date | Title | Type | Category | Amount (₹) | Note | ExtraJson
```

- `CustomCategory` rows — category definitions (exported first so import can resolve them before transactions)
- `Transaction` rows — normal income/expense/borrow/lend entries; `ExtraJson` carries `customCategoryId` when applicable
- `Scheduled` rows — future transactions with recurrence data in `ExtraJson`

The importer is backwards-compatible with old transaction-only CSV formats. On import, custom categories are deduplicated by name + type, and a UUID remap table ensures transactions correctly link to the local category id even when the CSV was produced on a different device.

---

## 🏗️ Architecture

```
UI (Screens / Widgets)
       ↓ watch / read
Providers (Riverpod)
       ↓ CRUD calls
Services (DatabaseService, NotificationService, SecurityService, …)
       ↓
SQLite / SecureStorage / SharedPreferences / File System
```

- **Models** are pure Dart data classes with `toMap` / `fromMap` for SQLite serialisation.
- **Providers** own all async state and expose it as `AsyncValue<T>`. Screens never touch the database directly.
- **Services** are singletons accessed without Riverpod — they handle all I/O.
- **Theme** is a context extension (`AppColors`) so any widget can use `context.appAccent`, `context.appExpense`, etc., and it automatically adapts to light/dark mode.
- **Custom categories** are resolved at the widget layer via `CategoryIcon` and `customCategoryProvider`, keeping the core `Transaction` model clean.

---

## 🔐 Security Notes

- Credentials are **never stored in plain text**. They are SHA-256 hashed before being written to `flutter_secure_storage`.
- The secure storage on Android uses `EncryptedSharedPreferences`.
- Biometric authentication is intentionally removed — PIN and password only.

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repo
2. Create your feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

---

## 👤 Author

**@siddiq0611**

---
