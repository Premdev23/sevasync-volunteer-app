# Sevasync AI – Volunteer Flutter App

Mobile companion for the Sevasync AI volunteer management platform. Mirrors the web Volunteer Dashboard with full Supabase real-time backend integration.

---

## 📁 Project Structure

```
lib/
├── main.dart                          # Entry point, AuthGate
├── main_shell.dart                    # Bottom nav with live badge counts
├── theme/
│   └── app_theme.dart                 # Dark theme, AppColors
├── models/
│   └── models.dart                    # VolunteerTask, NotificationItem, VolunteerProfile
├── services/
│   └── volunteer_service.dart         # All Supabase queries + real-time streams
├── widgets/
│   └── widgets.dart                   # SevaSyncLogo, StatCard, TaskCard, NotifTile, EmptyState
└── screens/
    ├── auth/login_screen.dart         # 1. Sign-in with Supabase Auth
    ├── dashboard/dashboard_screen.dart # 2. My Dashboard (home)
    ├── tasks/tasks_screen.dart         # 3. My Tasks (tabbed: All/Active/Pending/Done)
    ├── notifications/notifications_screen.dart  # 4. Notifications + mark-read
    ├── profile/profile_screen.dart    # 5. My Profile + skills + sign-out
    └── history/task_history_screen.dart # 6. Task History + impact stats
```

---

## 🚀 Setup

### 1. Prerequisites
- Flutter SDK ≥ 3.2.0 · `flutter --version`
- Dart SDK ≥ 3.2.0

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Configure Supabase credentials
Open `lib/main.dart` and replace:
```dart
const _supabaseUrl     = 'YOUR_SUPABASE_URL';
const _supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```
with your real values from **Supabase → Settings → API**.

### 4. Run
```bash
flutter run            # picks connected device automatically
flutter run -d android
flutter run -d ios
```

---

## 🗄️ Supabase Tables Expected

| Table      | Key columns used by app                                      |
|------------|--------------------------------------------------------------|
| `profiles` | `id`, `name`, `role`, `region`, `skills[]`, `is_active`     |
| `tasks`    | `id`, `title`, `description`, `status`, `priority`, `assigned_to`, `location`, `due_at`, `created_at` |
| `messages` | `id`, `content`, `type`, `is_read`, `recipient_id`, `created_at` |

> These match the existing Sevasync web backend – no schema changes needed.

---

## 🎨 Design Tokens

| Token         | Hex       | Usage                        |
|---------------|-----------|------------------------------|
| Background    | #0B0E1A   | Scaffold background          |
| Surface       | #131929   | Cards, AppBar                |
| Surface2      | #1A2236   | Inputs, chips                |
| Border        | #2A3550   | Card borders, dividers       |
| Primary       | #6C63FF   | Purple – selected nav, CTAs  |
| Accent        | #F5C518   | Yellow – Sevasync heart logo |
| Teal          | #0D9488   | "AI" badge                   |
| Badge         | #3B82F6   | Notification count dot       |
| Success       | #22C55E   | Completed, available         |
| Warning       | #F59E0B   | Active tasks, high priority  |
| Error         | #EF4444   | Critical, sign out           |

---

## 📱 Screens

| #  | Screen          | Features                                                          |
|----|-----------------|-------------------------------------------------------------------|
| 1  | **Login**       | Email/password auth, error handling, obscure toggle              |
| 2  | **Dashboard**   | Stats grid, tasks preview, notif preview, profile card, quick actions |
| 3  | **My Tasks**    | Tab filter (All / Active / Pending / Done), status update menu   |
| 4  | **Notifications** | Unread filter chip, mark-all-read, mark-single-read on tap      |
| 5  | **Profile**     | Avatar, active toggle, skills chips, account settings, sign-out  |
| 6  | **History**     | Completed tasks, impact summary (total / critical / high)        |

---

## ⚡ Real-time

The bottom nav badges for Tasks and Notifications update in real-time via Supabase `.stream()` subscriptions — no polling needed.
