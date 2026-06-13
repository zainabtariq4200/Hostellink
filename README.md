# 🏠 HostelLink — Smart Hostel Community & Management App

> A full-stack Progressive Web Application (PWA) built as a Final Year Project (FYP) at Lahore College for Women University, 2026.

---

## 📱 Live Demo

🔗 **[https://hostellink-app.web.app](https://hostellink-app.web.app)**

---

## 📌 About the Project

HostelLink is a real-world hostel management and community platform that digitizes the day-to-day experience of hostel students and staff. It replaces manual paper-based registration, notice boards, and word-of-mouth borrowing with a single connected app.

The app serves **three user roles** with completely separate dashboards and access levels:

| Role | Responsibilities |
|------|-----------------|
| **Student** | Register, browse marketplace, borrow/lend items, group & private chat |
| **Warden** | Approve/reject registrations, monitor activity, moderate chat |
| **Super Admin** | Manage hostels, create warden accounts, oversee all students |

---

## ✨ Features

### 👩‍🎓 Student
- Secure registration with warden approval workflow
- Post and browse a hostel-scoped **borrow/lend feed**
- **Second-hand marketplace** — list and buy items within the hostel
- **Real-time group chat** (per hostel) with unread badge counters
- **Private one-to-one chat** with other students or warden
- Edit profile, change password, view personal activity

### 🛡️ Warden
- 7-tab management dashboard
- Review, approve, or reject student registration requests with reasons
- View all students and their borrowing/lending activity
- Moderate group chat, message students privately
- Change account password

### 🔑 Super Admin
- Hidden admin login (security through obscurity)
- Add new hostels or toggle hostel active/inactive status
- Create warden accounts for any hostel
- View all registered students across all hostels

---

## 🔒 Security

- Passwords hashed using **SHA-256 with salt** before storage
- **Firebase Authentication** for session management
- **Firestore Security Rules** — users can only access their own hostel's data
- **Brute-force lockout** — account locked for 5 minutes after 5 failed login attempts
- Automatic migration of legacy custom UIDs to Firebase Auth on first login

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) — Web/PWA |
| Backend / Database | Firebase Firestore (NoSQL) |
| Authentication | Firebase Authentication |
| File Storage | Firebase Storage |
| Hosting | Firebase Hosting (CDN) |
| Design System | Material Design 3 |

---

## 🗄️ Database Structure

11 Firestore collections:

```
users/              → student profiles and credentials
wardens/            → warden accounts
hostels/            → hostel metadata
registration_requests/  → pending approvals
borrow_requests/    → borrow/lend feed posts
marketplace/        → second-hand listings
group_messages/     → hostel group chat
private_chats/      → one-to-one conversations
messages/           → chat message documents
notifications/      → in-app alerts
admin/              → super admin config
```

---

## 📐 Architecture

```
lib/
├── main.dart
├── services/
│   └── firebase_service.dart     ← all Firestore + Auth calls (service layer)
├── screens/
│   ├── student/                  ← student-facing screens
│   ├── warden/                   ← warden dashboard tabs
│   └── admin/                    ← super admin panel
├── widgets/                      ← reusable UI components
└── models/                       ← data model classes
```

The `FirebaseService` class acts as a clean service layer — all backend calls are decoupled from UI code. This mirrors the controller/service separation pattern used in frameworks like ASP.NET Core.

---

## 📊 Project Scale

| Metric | Value |
|--------|-------|
| Screens | 20+ |
| Firestore Collections | 11 |
| Lines of Dart code | ~4,500 |
| User Roles | 3 |
| Build Type | PWA (runs in browser + installable) |

---

## 🚀 Running Locally

### Prerequisites
- Flutter SDK (3.x or later)
- Firebase CLI
- A Firebase project with Firestore, Auth, and Storage enabled

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/HostelLink.git
cd HostelLink

# 2. Install dependencies
flutter pub get

# 3. Connect your Firebase project
flutterfire configure

# 4. Run on web
flutter run -d chrome

# 5. Build for production
flutter build web
firebase deploy
```

---


## 👩‍💻 Developer

**Zainab Tariq**
BS Software Engineering — Lahore College for Women University (LCWU), 2026
📧 zainabtariq4200@gmail.com

---

## 📄 License

This project was developed as an academic Final Year Project. All rights reserved © 2026 Zainab Tariq.
