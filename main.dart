import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

// HostelLink Firebase Config
const FirebaseOptions firebaseOptions = FirebaseOptions(
  apiKey:            String.fromEnvironment('FIREBASE_API_KEY'),
  authDomain:        String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
  projectId:         String.fromEnvironment('FIREBASE_PROJECT_ID'),
  storageBucket:     String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
  messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
  appId:             String.fromEnvironment('FIREBASE_APP_ID'),
  measurementId:     String.fromEnvironment('FIREBASE_MEASUREMENT_ID'),
);

// \u2550\u2550 SESSION MANAGER \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
class SessionManager {
  static const _kRole='session_role',_kEmail='session_email',_kName='session_name',_kRoom='session_room';
  static const _kHostelId='session_hostelId',_kHostelName='session_hostelName',_kUid='session_uid';
  static const _kEmoji='session_emoji',_kAvatarColor='session_avatarColor';
  static Future<void> save({required String role}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kRole, role);
    await p.setString(_kEmail, AppData.currentUserEmail);
    await p.setString(_kName, AppData.currentUserName);
    await p.setString(_kRoom, AppData.currentUserRoom);
    await p.setString(_kHostelId, AppData.currentUserHostelId);
    await p.setString(_kHostelName, AppData.selectedHostelName);
    await p.setString(_kUid, AppData.currentUserUid);
    await p.setString(_kEmoji, AppData.currentUserEmoji);
    await p.setInt(_kAvatarColor, AppData.currentUserAvatarColor);
  }
  static Future<String?> restore() async {
    final p = await SharedPreferences.getInstance();
    final role = p.getString(_kRole);
    if (role == null || role.isEmpty) return null;
    AppData.currentUserEmail       = p.getString(_kEmail)      ?? '';
    AppData.currentUserName        = p.getString(_kName)       ?? '';
    AppData.currentUserRoom        = p.getString(_kRoom)       ?? '';
    AppData.currentUserHostelId    = p.getString(_kHostelId)   ?? '';
    AppData.selectedHostelId       = p.getString(_kHostelId)   ?? '';
    AppData.selectedHostelName     = p.getString(_kHostelName) ?? '';
    AppData.currentUserUid         = p.getString(_kUid)        ?? '';
    AppData.currentUserEmoji       = p.getString(_kEmoji)      ?? '';
    AppData.currentUserAvatarColor = p.getInt(_kAvatarColor)   ?? 0xFF5C4D57;
    AppData.currentUserIsAdmin      = role == 'warden';
    AppData.currentUserIsSuperAdmin = role == 'superadmin';
    return role;
  }
  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
  }
}

// \u2550\u2550 BRUTE FORCE GUARD \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
class BruteForceGuard {
  static const int _maxAttempts = 5, _lockoutMins = 5;
  static final Map<String, Map<String, dynamic>> _state = {};
  static String? recordFailure(String email) {
    final key = email.trim().toLowerCase(); final now = DateTime.now();
    _state[key] ??= {'attempts': 0, 'lockedUntil': null};
    final lockedUntil = _state[key]!['lockedUntil'] as DateTime?;
    if (lockedUntil != null && now.isBefore(lockedUntil)) {
      return 'Too many failed attempts. Try again in ${_fmt(lockedUntil.difference(now).inSeconds)}.'; }
    _state[key]!['attempts'] = (_state[key]!['attempts'] as int) + 1;
    final attempts = _state[key]!['attempts'] as int;
    if (attempts >= _maxAttempts) {
      _state[key]!['lockedUntil'] = now.add(Duration(minutes: _lockoutMins));
      _state[key]!['attempts'] = 0;
      return 'Too many failed attempts. Account locked for $_lockoutMins minutes.'; }
    return null;
  }
  static String? checkLockout(String email) {
    final key = email.trim().toLowerCase(); final now = DateTime.now();
    final lockedUntil = _state[key]?['lockedUntil'] as DateTime?;
    if (lockedUntil != null && now.isBefore(lockedUntil))
      return 'Account locked. Try again in ${_fmt(lockedUntil.difference(now).inSeconds)}.';
    return null;
  }
  static void recordSuccess(String email) => _state.remove(email.trim().toLowerCase());
  static String _fmt(int s) { final m = s~/60; return m>0 ? '${m}m ${s%60}s' : '${s}s'; }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  // Disable reCAPTCHA verification for Firebase Auth on Flutter Web.
  // This allows password reset and sign-in to work without reCAPTCHA setup.
  FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: true);
  await HostelRegistry.loadFromFirestore();
  final role = await SessionManager.restore();
  runApp(HostelLinkApp(initialRole: role));
}

// ═══════════════════════════════════════════════════════════════════
// INTERNET CHECK UTILITY
// ═══════════════════════════════════════════════════════════════════
class NetCheck {
  static Future<bool> isOnline() async {
    try {
      await FirebaseFirestore.instance
          .collection('seeded').limit(1).get()
          .timeout(Duration(seconds: 8));
      return true;
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('permission') || err.contains('denied') || err.contains('unavailable')) return true;
      return false;
    }
  }

  // Shows a snackbar if offline, returns true if online
  static Future<bool> checkAndNotify(BuildContext context) async {
    final online = await isOnline();
    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(Icons.wifi_off, color: Colors.white),
          SizedBox(width: 10),
          Expanded(child: Text('No internet connection. Please check your WiFi or mobile data.')),
        ]),
        backgroundColor: Colors.red[700],
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
    return online;
  }
}

// No-internet banner widget — shown at top of screens
class NoInternetBanner extends StatefulWidget {
  @override _NoInternetBannerState createState() => _NoInternetBannerState();
}
class _NoInternetBannerState extends State<NoInternetBanner> {
  bool _offline = false;
  @override
  void initState() {
    super.initState();
    _check();
  }
  void _check() async {
    try {
      final online = await NetCheck.isOnline();
      if (mounted) setState(() => _offline = !online);
    } catch (_) {
      if (mounted) setState(() => _offline = false); // assume online on error
    }
  }
  @override
  Widget build(BuildContext context) {
    if (!_offline) return SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.red[700],
      child: Row(children: [
        Icon(Icons.wifi_off, color: Colors.white, size: 16),
        SizedBox(width: 8),
        Expanded(child: Text('No internet connection', style: TextStyle(color: Colors.white, fontSize: 13))),
        TextButton(onPressed: _check, child: Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// HOSTEL REGISTRY
// ═══════════════════════════════════════════════════════════════════
class HostelRegistry {
  static List<Map<String, String>> hostels = [
    {'id': 'lcwu_lahore',    'name': 'LCWU Girls Hostel',        'city': 'Lahore',     'university': 'Lahore College for Women University', 'active': 'yes'},
    {'id': 'pu_lahore',      'name': 'Punjab University Hostel', 'city': 'Lahore',     'university': 'University of the Punjab',            'active': 'yes'},
    {'id': 'uet_lahore',     'name': 'UET Girls Hostel',         'city': 'Lahore',     'university': 'UET Lahore',                          'active': 'yes'},
    {'id': 'quaid_karachi',  'name': 'Quaid-e-Azam Hostel',      'city': 'Karachi',    'university': 'University of Karachi',               'active': 'yes'},
    {'id': 'nust_islamabad', 'name': 'NUST Girls Hostel',        'city': 'Islamabad',  'university': 'NUST',                                'active': 'yes'},
    {'id': 'qau_islamabad',  'name': 'QAU Girls Hostel',         'city': 'Islamabad',  'university': 'Quaid-i-Azam University',             'active': 'yes'},
    {'id': 'uop_peshawar',   'name': 'UoP Girls Hostel',         'city': 'Peshawar',   'university': 'University of Peshawar',              'active': 'yes'},
    {'id': 'uob_quetta',     'name': 'UoB Girls Hostel',         'city': 'Quetta',     'university': 'University of Balochistan',           'active': 'yes'},
    {'id': 'bzu_multan',     'name': 'BZU Girls Hostel',         'city': 'Multan',     'university': 'Bahauddin Zakariya University',       'active': 'yes'},
    {'id': 'gu_faisalabad',  'name': 'GU Girls Hostel',          'city': 'Faisalabad', 'university': 'Government University Faisalabad',    'active': 'yes'},
  ];
  static List<Map<String, String>> get activeHostels => hostels.where((h) => h['active'] == 'yes').toList();
  static String getHostelName(String id) => hostels.firstWhere((h) => h['id'] == id, orElse: () => {'name': 'Unknown'})['name']!;
  static List<Map<String, String>> getByCity(String city) => city == 'All Cities' ? activeHostels : activeHostels.where((h) => h['city'] == city).toList();
  static List<String> get cities { final c = activeHostels.map((h) => h['city']!).toSet().toList()..sort(); return ['All Cities', ...c]; }
  static String? addHostel({required String name, required String city, required String university}) {
    if (name.trim().isEmpty) return 'Hostel name is required.';
    if (city.trim().isEmpty) return 'City is required.';
    if (university.trim().isEmpty) return 'University is required.';
    if (hostels.any((h) => h['name']!.toLowerCase() == name.toLowerCase())) return 'Hostel with this name already exists.';
    final id = '${name.trim().toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '')}_${DateTime.now().millisecondsSinceEpoch}';
    hostels.add({'id': id, 'name': name.trim(), 'city': city.trim(), 'university': university.trim(), 'active': 'yes'});
    // Persist to Firestore (fire-and-forget — UI already updated in-memory)
    FirebaseService.addHostelToFirestore(id: id, name: name.trim(), city: city.trim(), university: university.trim());
    return null;
  }

  /// Merges hostels loaded from Firestore into the in-memory list.
  /// Called once on app startup — Firestore additions take precedence.
  static Future<void> loadFromFirestore() async {
    final remote = await FirebaseService.loadHostelsFromFirestore();
    for (final r in remote) {
      final exists = hostels.any((h) => h['id'] == r['id']);
      if (!exists) hostels.add(r);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// REGISTRATION REQUEST MODEL
// When a student fills the form, a request is saved here.
// Warden reviews it and approves or rejects.
// Format: { id, name, email, password, room, hostelId, status,
//           submittedAt, reviewedAt, rejectionReason }
// status: 'pending' | 'approved' | 'rejected'
// ═══════════════════════════════════════════════════════════════════
class RegRequest {
  static List<Map<String, String>> all = [];

  // Student submits registration request
  static String? submit({required String name, required String email, required String password, required String room, required String hostelId}) {
    if (name.trim().isEmpty) return 'Please enter your full name.';
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(email.trim())) return 'Please enter a valid email.\n(e.g. yourname@gmail.com)';
    if (password.length < 6) return 'Password must be at least 6 characters.';
    if (!password.contains(RegExp(r'[0-9]'))) return 'Password must contain at least one number.';
    if (room.trim().isEmpty) return 'Please enter your room number.';

    // Check: already has a pending/approved request in this hostel
    final existing = all.firstWhere(
          (r) => r['email'].toString().toLowerCase() == email.toLowerCase() && r['hostelId'] == hostelId,
      orElse: () => {},
    );
    if (existing.isNotEmpty) {
      if (existing['status'] == 'pending')  return 'You already submitted a registration request.\nPlease wait for the warden to review it.';
      if (existing['status'] == 'approved') return 'Your request was already approved.\nPlease login with your account.';
      if (existing['status'] == 'rejected') return 'Your previous request was rejected.\nReason: ${existing['rejectionReason']}\n\nContact your warden for help.';
    }

    // Check: already fully registered
    if (AppData.isEmailRegisteredInHostel(email, hostelId)) return 'This email is already registered.\nPlease login instead.';

    all.add({
      'id':              DateTime.now().millisecondsSinceEpoch.toString(),
      'name':            name.trim(),
      'email':           email.trim().toLowerCase(),
      'password':        password,
      'room':            room.trim(),
      'hostelId':        hostelId,
      'status':          'pending',
      'submittedAt':     _now(),
      'reviewedAt':      '',
      'rejectionReason': '',
    });
    return null;
  }

  // Get all requests for a hostel
  static List<Map<String, String>> forHostel(String hostelId) =>
      all.where((r) => r['hostelId'] == hostelId).toList().reversed.toList();

  // Get pending requests for a hostel
  static List<Map<String, String>> pendingFor(String hostelId) =>
      all.where((r) => r['hostelId'] == hostelId && r['status'] == 'pending').toList();

  // Warden approves a request → creates the actual user account
  static void approve(String id) {
    final idx = all.indexWhere((r) => r['id'] == id);
    if (idx == -1) return;
    final req = all[idx];
    // Create the real user account
    AppData.registeredUsers.add({
      'email':    req['email']!,
      'password': req['password']!,
      'name':     req['name']!,
      'room':     req['room']!,
      'hostelId': req['hostelId']!,
    });
    all[idx]['status']     = 'approved';
    all[idx]['reviewedAt'] = _now();
  }

  // Warden rejects a request
  static void reject(String id, String reason) {
    final idx = all.indexWhere((r) => r['id'] == id);
    if (idx == -1) return;
    all[idx]['status']          = 'rejected';
    all[idx]['reviewedAt']      = _now();
    all[idx]['rejectionReason'] = reason.trim().isEmpty ? 'No reason provided.' : reason.trim();
  }

  static String _now() {
    final n = DateTime.now();
    return '${n.day}/${n.month}/${n.year} ${n.hour}:${n.minute.toString().padLeft(2,'0')}';
  }
}

// ═══════════════════════════════════════════════════════════════════
// APP DATA
// ═══════════════════════════════════════════════════════════════════
class AppData {
  static String selectedHostelId     = '';
  static String selectedHostelName   = '';
  static String currentUserName      = '';
  static String currentUserRoom      = '';
  static String currentUserEmail     = '';
  static String currentUserHostelId  = '';
  static bool   currentUserIsAdmin   = false;
  static bool   currentUserIsSuperAdmin = false;
  static String currentUserUid        = ''; // Firebase Auth UID

  // ─────────────────────────────────────────────────────────
  // PROFILE AVATAR — emoji + background color
  // User picks from a palette in Edit Profile
  // ─────────────────────────────────────────────────────────
  static String currentUserEmoji     = '';   // e.g. '🌸'  — empty = show initials
  static int    currentUserAvatarColor = 0xFF5C4D57; // default purple

  // Palette of avatar emojis users can choose from
  static const List<String> avatarEmojis = [
    '🌸','🌺','🌻','🌹','🌷','🌼','🍀','🦋','🌙','⭐',
    '🎀','💜','🌈','🦄','🐱','🐰','🐼','🦊','🐨','🐸',
    '🍓','🍑','🍒','🎵','📚','✏️','🎨','💡','🏆','💎',
  ];

  // Palette of background colors
  static const List<int> avatarColors = [
    0xFF5C4D57, 0xFFE91E63, 0xFF9C27B0, 0xFF3F51B5,
    0xFF2196F3, 0xFF009688, 0xFF4CAF50, 0xFFFF9800,
    0xFFFF5722, 0xFF795548, 0xFF607D8B, 0xFF000000,
  ];


  static Future<String?> loginSuperAdmin({required String code, required String email, required String password}) async {
    // Validate secret code locally (it's not a credential, just an access gate)
    if (code.trim() != 'HOSTELLINK2025') return 'Invalid secret access code.';

    // Validate email + password against Firestore — no hardcoded credentials
    final result = await FirebaseService.loginSuperAdmin(
      email: email,
      password: password,
    );

    if (result == null)            return 'No super admin account found.';
    if (result == 'WRONG_PASSWORD') return 'Invalid super admin password.';

    // Success
    currentUserName         = 'HostelLink Super Admin';
    currentUserEmail        = email.trim().toLowerCase();
    currentUserIsAdmin      = false;
    currentUserIsSuperAdmin = true;
    return null;
  }

  // WARDEN ACCOUNTS
  static List<Map<String, String>> wardenAccounts = [
    {'email': 'warden@lcwu.edu.pk', 'password': 'Temp1234', 'hostelId': 'lcwu_lahore', 'name': 'LCWU Warden', 'isTemp': 'yes', 'active': 'yes'},
  ];

  static String? superAdminCreateWarden({required String name, required String email, required String hostelId, required String tempPassword}) {
    if (name.trim().isEmpty) return 'Warden name is required.';
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(email.trim())) return 'Invalid email format.';
    if (wardenAccounts.any((w) => w['email']!.toLowerCase() == email.toLowerCase() && w['hostelId'] == hostelId)) return 'Warden already exists for this hostel.';
    if (tempPassword.length < 6) return 'Temp password must be at least 6 characters.';
    wardenAccounts.add({'email': email.trim().toLowerCase(), 'password': tempPassword, 'hostelId': hostelId, 'name': name.trim(), 'isTemp': 'yes', 'active': 'yes'});
    return null;
  }

  static String? loginAdmin({required String email, required String password, required String hostelId}) {
    final warden = wardenAccounts.firstWhere(
          (w) => w['email']!.toLowerCase() == email.trim().toLowerCase() && w['hostelId'] == hostelId,
      orElse: () => {},
    );
    if (warden.isEmpty)             return 'No warden account found.\n\nContact HostelLink admin to create your account.';
    if (warden['active'] == 'no')   return 'Your account has been deactivated.\nContact HostelLink support.';
    if (warden['password'] != password) return 'Incorrect password.';
    currentUserEmail = warden['email']!; currentUserName = warden['name']!;
    currentUserHostelId = hostelId; currentUserIsAdmin = true; currentUserIsSuperAdmin = false;
    if (warden['isTemp'] == 'yes') return 'FORCE_CHANGE_PASSWORD';
    return null;
  }

  static String? wardenChangePassword({required String email, required String hostelId, required String oldPassword, required String newPassword}) {
    final idx = wardenAccounts.indexWhere((w) => w['email']!.toLowerCase() == email.toLowerCase() && w['hostelId'] == hostelId);
    if (idx == -1) return 'Account not found.';
    if (wardenAccounts[idx]['password'] != oldPassword) return 'Current password is incorrect.';
    if (newPassword.length < 8)                         return 'New password must be at least 8 characters.';
    if (!newPassword.contains(RegExp(r'[0-9]')))        return 'Must contain at least one number.';
    if (!newPassword.contains(RegExp(r'[A-Z]')))        return 'Must contain at least one uppercase letter.';
    if (newPassword == oldPassword)                     return 'New password must be different.';
    wardenAccounts[idx]['password'] = newPassword; wardenAccounts[idx]['isTemp'] = 'no';
    return null;
  }

  // STUDENTS
  static List<Map<String, String>> registeredUsers = [];
  static bool isEmailRegisteredInHostel(String email, String hostelId) =>
      registeredUsers.any((u) => u['email']!.toLowerCase() == email.toLowerCase() && u['hostelId'] == hostelId);

  static String? loginUser({required String email, required String password, required String hostelId}) {
    if (!email.contains('@') || !email.contains('.')) return 'Please enter a valid email.';

    // Check if they have a pending request — give helpful message
    final pending = RegRequest.all.firstWhere(
          (r) => r['email'].toString().toLowerCase() == email.toLowerCase() && r['hostelId'] == hostelId && r['status'] == 'pending',
      orElse: () => {},
    );
    if (pending.isNotEmpty) return 'Your registration request is still pending.\n\nPlease wait for the warden to approve it. You will be able to login once approved.';

    // Check if rejected
    final rejected = RegRequest.all.firstWhere(
          (r) => r['email'].toString().toLowerCase() == email.toLowerCase() && r['hostelId'] == hostelId && r['status'] == 'rejected',
      orElse: () => {},
    );
    if (rejected.isNotEmpty) return 'Your registration was rejected.\nReason: ${rejected['rejectionReason']}\n\nContact your warden for help.';

    if (!isEmailRegisteredInHostel(email, hostelId)) return 'No account found in ${HostelRegistry.getHostelName(hostelId)}.\n\nPlease register first — your warden will approve your request.';
    final user = registeredUsers.firstWhere((u) => u['email']!.toLowerCase() == email.trim().toLowerCase() && u['hostelId'] == hostelId);
    if (user['password'] != password) return 'Incorrect password.';
    currentUserEmail = user['email'].toString(); currentUserName = user['name'].toString();
    currentUserRoom = user['room'].toString(); currentUserHostelId = hostelId;
    currentUserIsAdmin = false; currentUserIsSuperAdmin = false;
    return null;
  }

  static List<Map<String, String>> getRegisteredUsers(String hostelId) => registeredUsers.where((u) => u['hostelId'] == hostelId).toList();

  // REQUESTS (borrow/lend)
  static List<Map<String, String>> _allRequests = [
    {'item': 'Phone Charger',    'person': 'Ayesha', 'room': 'Room 12', 'duration': '2 hours', 'category': 'Electronics',   'status': 'open', 'hostelId': 'lcwu_lahore'},
    {'item': 'Hair Dryer',       'person': 'Sana',   'room': 'Room 7',  'duration': '1 hour',  'category': 'Personal Care', 'status': 'open', 'hostelId': 'lcwu_lahore'},
    {'item': 'Extension Cord',   'person': 'Fatima', 'room': 'Room 3',  'duration': '1 day',   'category': 'Electronics',   'status': 'open', 'hostelId': 'lcwu_lahore'},
    {'item': 'Biology Textbook', 'person': 'Zara',   'room': 'Room 15', 'duration': '3 days',  'category': 'Books',         'status': 'open', 'hostelId': 'lcwu_lahore'},
    {'item': 'Calculator',       'person': 'Sara',   'room': 'Room 4',  'duration': '2 hours', 'category': 'Electronics',   'status': 'open', 'hostelId': 'pu_lahore'},
  ];
  static List<Map<String, String>> get allRequests => _allRequests.where((r) => r['hostelId'] == currentUserHostelId).toList();
  static void addRequest(Map<String, String> r) => _allRequests.insert(0, {...r, 'hostelId': currentUserHostelId});

  static List<Map<String, String>> myRequests   = [];
  static List<Map<String, String>> myLendings   = [];
  static List<Map<String, String>> notifications = [];
  static double myRating = 4.5;

  // ─────────────────────────────────────────────────────────
  // MARKETPLACE — hostel-isolated buy/sell listings
  // ─────────────────────────────────────────────────────────
  static List<Map<String, String>> _allListings = [
    {'id': '1', 'title': 'Biology Textbook (2nd Year)', 'price': '500',  'condition': 'Good',  'category': 'Books',        'description': 'Slightly used, all pages intact.',   'emoji': '📚', 'sellerName': 'Ayesha', 'sellerRoom': 'Room 12', 'sellerEmail': 'ayesha@gmail.com',  'hostelId': 'lcwu_lahore', 'status': 'available', 'postedAt': '10/3/2025'},
    {'id': '2', 'title': 'Hair Straightener',           'price': '1200', 'condition': 'Good',  'category': 'Personal Care', 'description': 'Philips brand, works perfectly.',    'emoji': '💇', 'sellerName': 'Sana',   'sellerRoom': 'Room 7',  'sellerEmail': 'sana@gmail.com',    'hostelId': 'lcwu_lahore', 'status': 'available', 'postedAt': '9/3/2025'},
    {'id': '3', 'title': 'Scientific Calculator',       'price': '800',  'condition': 'New',   'category': 'Electronics',  'description': 'Casio fx-991, bought last month.',   'emoji': '🔢', 'sellerName': 'Fatima', 'sellerRoom': 'Room 3',  'sellerEmail': 'fatima@gmail.com',  'hostelId': 'lcwu_lahore', 'status': 'available', 'postedAt': '8/3/2025'},
    {'id': '4', 'title': 'Winter Shawl (maroon)',        'price': '600',  'condition': 'Used',  'category': 'Clothing',     'description': 'Warm and comfy, worn twice.',         'emoji': '🧣', 'sellerName': 'Zara',   'sellerRoom': 'Room 15', 'sellerEmail': 'zara@gmail.com',    'hostelId': 'lcwu_lahore', 'status': 'available', 'postedAt': '7/3/2025'},
    {'id': '5', 'title': 'Desk Lamp',                   'price': '450',  'condition': 'Good',  'category': 'Electronics',  'description': 'LED lamp, perfect for studying.',    'emoji': '💡', 'sellerName': 'Sara',   'sellerRoom': 'Room 4',  'sellerEmail': 'sara@gmail.com',    'hostelId': 'pu_lahore',   'status': 'available', 'postedAt': '6/3/2025'},
  ];

  static List<Map<String, String>> get allListings =>
      _allListings.where((l) => l['hostelId'] == currentUserHostelId).toList();

  static void addListing(Map<String, String> listing) =>
      _allListings.insert(0, {...listing, 'hostelId': currentUserHostelId});

  static void markSold(String id) {
    final idx = _allListings.indexWhere((l) => l['id'] == id);
    if (idx != -1) _allListings[idx]['status'] = 'sold';
  }

  static void deleteListing(String id) =>
      _allListings.removeWhere((l) => l['id'] == id);

  static List<Map<String, String>> get myListings =>
      _allListings.where((l) => l['sellerEmail'] == currentUserEmail && l['hostelId'] == currentUserHostelId).toList();

  // ─────────────────────────────────────────────────────────
  // CHAT UNREAD TRACKING
  // ─────────────────────────────────────────────────────────
  static DateTime? groupChatLastSeen; // null = never opened
  static int       groupUnreadCount  = 0;

  static void markGroupChatSeen() {
    groupChatLastSeen = DateTime.now();
    groupUnreadCount  = 0;
  }

  static void logout() {
    currentUserName = currentUserRoom = currentUserEmail = currentUserHostelId = selectedHostelId = selectedHostelName = currentUserUid = '';
    currentUserIsAdmin = currentUserIsSuperAdmin = false;
    currentUserEmoji = ''; currentUserAvatarColor = 0xFF5C4D57;
    myRequests.clear(); myLendings.clear(); notifications.clear();
    groupChatLastSeen = null; groupUnreadCount = 0;
    FirebaseService.signOut();
    SessionManager.clear();
  }
}

// ═══════════════════════════════════════════════════════════════════
// REUSABLE USER AVATAR WIDGET
// Shows emoji if set, otherwise shows name initial
// ═══════════════════════════════════════════════════════════════════
class UserAvatar extends StatelessWidget {
  final double radius;
  final String name;
  final String emoji;
  final int color;
  final bool showEditBadge;

  const UserAvatar({
    Key? key,
    this.radius = 40,
    required this.name,
    required this.emoji,
    required this.color,
    this.showEditBadge = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = Color(color);
    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: emoji.isNotEmpty
          ? Text(emoji, style: TextStyle(fontSize: radius * 0.85))
          : Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: TextStyle(
          fontSize: radius * 0.8,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    if (!showEditBadge) return avatar;

    return Stack(children: [
      avatar,
      Positioned(
        bottom: 0, right: 0,
        child: Container(
          padding: EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: bg, width: 2),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Icon(Icons.edit, size: 14, color: bg),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════
// MAIN APP
// ═══════════════════════════════════════════════════════════════════
class HostelLinkApp extends StatelessWidget {
  final String? initialRole;
  const HostelLinkApp({this.initialRole});
  Widget _homeForRole() {
    switch (initialRole) {
      case 'student':    return HomeScreen();
      case 'warden':     return AdminPanelScreen();
      case 'superadmin': return SuperAdminPanelScreen();
      default:           return WelcomeScreen();
    }
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'HostelLink', debugShowCheckedModeBanner: false,
        theme: ThemeData(primaryColor: Color(0xFF5C4D57), colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF5C4D57))),
        home: _homeForRole());
  }
}

// ═══════════════════════════════════════════════════════════════════
// WELCOME SCREEN
// ═══════════════════════════════════════════════════════════════════
class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF5C4D57),
      body: Center(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.home_outlined, size: 100, color: Colors.white),
        SizedBox(height: 20),
        Text('HostelLink', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
        SizedBox(height: 8),
        Text('Share. Borrow. Connect.', style: TextStyle(fontSize: 16, color: Colors.white70)),
        SizedBox(height: 50),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SelectHostelScreen())),
          icon: Icon(Icons.apartment), label: Text('Select Your Hostel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Color(0xFF5C4D57),
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
        ),
        SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminLoginScreen())),
          icon: Icon(Icons.admin_panel_settings, color: Colors.white60, size: 18),
          label: Text('Warden Login', style: TextStyle(color: Colors.white60, fontSize: 13)),
        ),
        _SuperAdminEntry(),
      ]))),
    );
  }
}

class _SuperAdminEntry extends StatefulWidget { @override __SuperAdminEntryState createState() => __SuperAdminEntryState(); }
class __SuperAdminEntryState extends State<_SuperAdminEntry> {
  int _taps = 0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { setState(() => _taps++); if (_taps >= 7) { _taps = 0; Navigator.push(context, MaterialPageRoute(builder: (_) => SuperAdminLoginScreen())); } },
      child: Padding(padding: EdgeInsets.only(top: 30), child: Text('v1.0.0', style: TextStyle(color: Colors.white24, fontSize: 11))),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SELECT HOSTEL SCREEN
// ═══════════════════════════════════════════════════════════════════
class SelectHostelScreen extends StatefulWidget { @override _SelectHostelScreenState createState() => _SelectHostelScreenState(); }
class _SelectHostelScreenState extends State<SelectHostelScreen> {
  String _city = 'All Cities'; String? _selectedId;
  @override
  Widget build(BuildContext context) {
    final list = HostelRegistry.getByCity(_city);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text('Select Your Hostel'), backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white),
      body: Column(children: [
        Container(width: double.infinity, padding: EdgeInsets.all(14), color: Color(0xFF5C4D57).withOpacity(0.07),
            child: Row(children: [Icon(Icons.lock_outline, color: Color(0xFF5C4D57)), SizedBox(width: 10), Expanded(child: Text('Registration requires warden approval. Each hostel\'s data is completely private.', style: TextStyle(color: Colors.grey[700], fontSize: 13)))])),
        Padding(padding: EdgeInsets.fromLTRB(16,16,16,8), child: DropdownButtonFormField<String>(value: _city,
            decoration: InputDecoration(labelText: 'Filter by City', prefixIcon: Icon(Icons.location_city_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            items: HostelRegistry.cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() { _city = v!; _selectedId = null; }))),
        Expanded(child: ListView.builder(padding: EdgeInsets.symmetric(horizontal: 16), itemCount: list.length, itemBuilder: (ctx, i) {
          final h = list[i]; final sel = _selectedId == h['id'];
          return Card(margin: EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: sel ? Color(0xFF5C4D57) : Colors.transparent, width: 2)),
              child: ListTile(contentPadding: EdgeInsets.all(12),
                  leading: CircleAvatar(backgroundColor: sel ? Color(0xFF5C4D57) : Color(0xFF5C4D57).withOpacity(0.1), child: Icon(Icons.apartment, color: sel ? Colors.white : Color(0xFF5C4D57))),
                  title: Text(h['name']!, style: TextStyle(fontWeight: FontWeight.bold, color: sel ? Color(0xFF5C4D57) : Colors.black)),
                  subtitle: Text('${h['university']}\n📍 ${h['city']}', style: TextStyle(fontSize: 12)),
                  trailing: Icon(sel ? Icons.check_circle : Icons.radio_button_unchecked, color: sel ? Color(0xFF5C4D57) : Colors.grey),
                  onTap: () => setState(() => _selectedId = h['id'])));
        })),
        Padding(padding: EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _selectedId == null ? null : () {
            AppData.selectedHostelId = _selectedId!;
            AppData.selectedHostelName = HostelRegistry.getHostelName(_selectedId!);
            Navigator.push(context, MaterialPageRoute(builder: (_) => AuthChoiceScreen()));
          },
          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), disabledBackgroundColor: Colors.grey[300]),
          child: Text(_selectedId == null ? 'Select a hostel to continue' : 'Continue with ${HostelRegistry.getHostelName(_selectedId!)}', style: TextStyle(fontSize: 16)),
        ))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// AUTH CHOICE SCREEN
// ═══════════════════════════════════════════════════════════════════
class AuthChoiceScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF5C4D57),
      appBar: AppBar(backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white, elevation: 0),
      body: Center(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.apartment, size: 70, color: Colors.white), SizedBox(height: 16),
        Text(AppData.selectedHostelName, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        SizedBox(height: 8),
        Container(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
            child: Text('🔐 Warden-Approved Registration', style: TextStyle(color: Colors.white, fontSize: 13))),
        SizedBox(height: 40),
        SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen())),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Color(0xFF5C4D57), padding: EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
            child: Text('Login to My Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
        SizedBox(height: 15),
        SizedBox(width: double.infinity, child: OutlinedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen())),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white, width: 2), padding: EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
            child: Text('Request Registration', style: TextStyle(fontSize: 16)))),
        SizedBox(height: 12),
        // Check request status button
        TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CheckRequestStatusScreen())),
          icon: Icon(Icons.search, color: Colors.white70, size: 16),
          label: Text('Check my request status', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(context), child: Text('← Choose different hostel', style: TextStyle(color: Colors.white60))),
      ]))),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// REGISTER SCREEN — submits request, doesn't create account directly
// ═══════════════════════════════════════════════════════════════════
class RegisterScreen extends StatefulWidget { @override _RegisterScreenState createState() => _RegisterScreenState(); }
class _RegisterScreenState extends State<RegisterScreen> {
  final nameCtrl = TextEditingController(), emailCtrl = TextEditingController();
  final passCtrl = TextEditingController(), roomCtrl  = TextEditingController();
  final confirmPassCtrl = TextEditingController();
  bool _hide = true, _hideConfirm = true, _loading = false;
  String _block = 'Block A';

  void _err(String msg) => showDialog(context: context, builder: (_) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: Row(children: [Icon(Icons.error_outline, color: Colors.red), SizedBox(width: 8), Text('Error')]), content: Text(msg), actions: [ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: Text('OK'))]));

  void _submitRequest() async {
    FocusScope.of(context).unfocus();
    // Local validation first
    if (nameCtrl.text.trim().isEmpty) { _err('Please enter your full name.'); return; }
    if (!emailCtrl.text.contains('@') || !emailCtrl.text.contains('.')) { _err('Please enter a valid email address.'); return; }
    if (roomCtrl.text.trim().isEmpty) { _err('Please enter your room number.'); return; }
    if (passCtrl.text.length < 6)     { _err('Password must be at least 6 characters.'); return; }
    if (!passCtrl.text.contains(RegExp(r'[0-9]'))) { _err('Password must contain at least one number.'); return; }
    if (passCtrl.text != confirmPassCtrl.text) { _err('Passwords do not match. Please try again.'); return; }

    setState(() => _loading = true);

    // Submit to Firebase with timeout so it never hangs
    String? error;
    try {
      error = await FirebaseService.submitRegRequest(
        name:     nameCtrl.text.trim(),
        email:    emailCtrl.text.trim(),
        password: passCtrl.text,
        room:     'Room ${roomCtrl.text.trim()} • $_block',
        hostelId: AppData.selectedHostelId,
      ).timeout(const Duration(seconds: 15), onTimeout: () => 'Connection timeout. Please check your internet and try again.');
    } catch (e) {
      error = 'Error: $e';
    }

    // Also save locally as fallback
    if (error == null) {
      RegRequest.submit(
        name:     nameCtrl.text.trim(),
        email:    emailCtrl.text.trim(),
        password: passCtrl.text,
        room:     'Room ${roomCtrl.text.trim()} • $_block',
        hostelId: AppData.selectedHostelId,
      );
    }

    setState(() => _loading = false);

    if (error != null) {
      showDialog(context: context, builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [Icon(Icons.error_outline, color: Colors.red), SizedBox(width: 8), Text('Cannot Submit')]),
        content: Text(error ?? 'Unknown error'),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white), child: Text('OK'))],
      ));
    } else {
      // Success — request submitted, now waiting for warden
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [Icon(Icons.send_outlined, color: Colors.green), SizedBox(width: 8), Text('Request Sent! 📨')]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your registration request has been sent to the warden of:'),
            SizedBox(height: 8),
            Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Color(0xFF5C4D57).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('🏠 ${AppData.selectedHostelName}', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('📧 ${emailCtrl.text.trim()}'),
                  Text('👤 ${nameCtrl.text.trim()}'),
                ])),
            SizedBox(height: 12),
            Text('⏳ What happens next:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('1. Warden reviews your request\n2. If approved, your account is created\n3. You can then login with your email & password\n\nYou can check your request status anytime.', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          ]),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(context); },
              child: Text('Stay Here', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () { Navigator.pop(context); Navigator.pop(context); },
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white),
              child: Text('Go to Login'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text('Request Registration'), backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: EdgeInsets.all(24), child: Column(children: [
        // Info banner
        Container(padding: EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.3))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 22), SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('How registration works:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800])),
                SizedBox(height: 4),
                Text('Fill this form → Warden receives your request → Warden approves → You can login!', style: TextStyle(color: Colors.blue[700], fontSize: 13)),
              ])),
            ])),
        SizedBox(height: 20),
        TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        SizedBox(height: 14),
        TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        SizedBox(height: 14),
        TextField(controller: roomCtrl, decoration: InputDecoration(labelText: 'Room Number', prefixIcon: Icon(Icons.door_back_door_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        SizedBox(height: 14),
        DropdownButtonFormField<String>(value: _block,
            decoration: InputDecoration(labelText: 'Block', prefixIcon: Icon(Icons.apartment_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            items: ['Block A','Block B','Block C','Block D'].map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
            onChanged: (v) => setState(() => _block = v!)),
        SizedBox(height: 14),
        TextField(controller: passCtrl, obscureText: _hide,
            decoration: InputDecoration(labelText: 'Set Your Password (min 6 + 1 number)', prefixIcon: Icon(Icons.lock_outline),
                suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide = !_hide)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        SizedBox(height: 14),
        TextField(controller: confirmPassCtrl, obscureText: _hideConfirm,
            decoration: InputDecoration(labelText: 'Confirm Password', prefixIcon: Icon(Icons.lock_outline),
                suffixIcon: IconButton(icon: Icon(_hideConfirm ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hideConfirm = !_hideConfirm)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                errorText: confirmPassCtrl.text.isNotEmpty && confirmPassCtrl.text != passCtrl.text ? 'Passwords do not match' : null),
            onChanged: (_) => setState(() {})),
        SizedBox(height: 8),
        Text('Your password is stored securely and only used when your account is activated.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _loading ? null : _submitRequest,
          icon: Icon(Icons.send_outlined),
          label: _loading ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Send Registration Request', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
      ])),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CHECK REQUEST STATUS SCREEN — student checks their request
// ═══════════════════════════════════════════════════════════════════
class CheckRequestStatusScreen extends StatefulWidget { @override _CheckRequestStatusScreenState createState() => _CheckRequestStatusScreenState(); }
class _CheckRequestStatusScreenState extends State<CheckRequestStatusScreen> {
  final emailCtrl = TextEditingController();
  Map<String, String>? _result;
  bool _searched = false;

  Map<String, dynamic>? _fbResult;

  void _check() async {
    FocusScope.of(context).unfocus();
    final email = emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) return;
    setState(() { _searched = true; _result = null; _fbResult = null; });

    // Query Firebase first
    final fb = await FirebaseService.checkRequestStatus(email, AppData.selectedHostelId);
    if (fb != null) {
      setState(() => _fbResult = fb);
      return;
    }

    // Fallback to local
    final local = RegRequest.all.firstWhere(
          (r) => r['email'].toString().toLowerCase() == email && r['hostelId'] == AppData.selectedHostelId,
      orElse: () => {},
    );
    setState(() { _result = local.isEmpty ? null : local; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text('Check Request Status'), backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white),
      body: Padding(padding: EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Enter your email to check the status of your registration request.', style: TextStyle(color: Colors.grey)),
        SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(hintText: 'Your email address', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
          SizedBox(width: 8),
          ElevatedButton(onPressed: _check,
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Icon(Icons.search)),
        ]),
        SizedBox(height: 30),

        if (_searched && _result == null && _fbResult == null)
          Center(child: Column(children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey),
            SizedBox(height: 8),
            Text('No registration request found for this email in \${AppData.selectedHostelName}.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ])),

        if (_fbResult != null) ...[
          Text('Request Found!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          _fbStatusCard(_fbResult!),
        ],

        if (_result != null && _fbResult == null) ...[
          Text('Request Found!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          _statusCard(_result!),
        ],
      ])),
    );
  }

  Widget _fbStatusCard(Map<String, dynamic> r) {
    final status = r['status']?.toString() ?? 'pending';
    Color statusColor; IconData statusIcon; String statusText;
    switch (status) {
      case 'approved': statusColor = Colors.green; statusIcon = Icons.check_circle; statusText = 'APPROVED ✅'; break;
      case 'rejected': statusColor = Colors.red;   statusIcon = Icons.cancel;       statusText = 'REJECTED ❌'; break;
      default:         statusColor = Colors.orange; statusIcon = Icons.hourglass_top; statusText = 'PENDING ⏳';
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: statusColor, width: 2)),
      child: Padding(padding: EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(statusIcon, color: statusColor, size: 32), SizedBox(width: 12),
          Text(statusText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor))]),
        Divider(height: 24),
        _row('Name',      r['name']?.toString() ?? ''),
        _row('Email',     r['email']?.toString() ?? ''),
        _row('Room',      r['room']?.toString() ?? ''),
        _row('Submitted', r['submittedAt']?.toString() ?? ''),
        if (status == 'rejected') ...[
          SizedBox(height: 8),
          Container(padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Text('Rejection reason: ${r["rejectionReason"] ?? ""}',
                  style: TextStyle(color: Colors.red[700]))),
        ],
        if (status == 'approved') ...[
          SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () { Navigator.pop(context); Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen())); },
            icon: Icon(Icons.login), label: Text('Go to Login'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
        ],
        if (status == 'pending') ...[
          SizedBox(height: 12),
          Container(padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Text('Your request is waiting for the warden to review it.',
                  style: TextStyle(color: Colors.orange[800], fontSize: 13))),
        ],
      ])),
    );
  }

  Widget _statusCard(Map<String, String> r) {
    Color statusColor; IconData statusIcon; String statusText;
    switch (r['status']) {
      case 'approved':
        statusColor = Colors.green; statusIcon = Icons.check_circle; statusText = 'APPROVED ✅';
        break;
      case 'rejected':
        statusColor = Colors.red; statusIcon = Icons.cancel; statusText = 'REJECTED ❌';
        break;
      default:
        statusColor = Colors.orange; statusIcon = Icons.hourglass_top; statusText = 'PENDING ⏳';
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: statusColor, width: 2)),
      child: Padding(padding: EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(statusIcon, color: statusColor, size: 32), SizedBox(width: 12), Text(statusText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor))]),
        Divider(height: 24),
        _row('Name',        r['name'].toString()),
        _row('Email',       r['email'].toString()),
        _row('Room',        r['room'].toString()),
        _row('Hostel',      HostelRegistry.getHostelName(r['hostelId'].toString())),
        _row('Submitted',   r['submittedAt']?.toString() ?? ''),
        if ((r['reviewedAt']?.toString() ?? '').isNotEmpty) _row('Reviewed', r['reviewedAt'].toString()),
        if (r['status'] == 'rejected' && (r['rejectionReason']?.toString() ?? '').isNotEmpty) ...[
          SizedBox(height: 8),
          Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.comment_outlined, color: Colors.red, size: 18), SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Rejection Reason:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  Text(r['rejectionReason']?.toString() ?? '', style: TextStyle(color: Colors.red[700])),
                ])),
              ])),
        ],
        if (r['status'] == 'approved') ...[
          SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen())); },
            icon: Icon(Icons.login), label: Text('Go to Login'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
        ],
        if (r['status'] == 'pending') ...[
          SizedBox(height: 12),
          Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Text('Your request is waiting for the warden to review it.\nPlease check back later or contact your warden.', style: TextStyle(color: Colors.orange[800], fontSize: 13))),
        ],
      ])),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 90, child: Text('$label:', style: TextStyle(color: Colors.grey, fontSize: 13))),
      Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════
// LOGIN SCREEN
// ═══════════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget { @override _LoginScreenState createState() => _LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController(), passCtrl = TextEditingController();
  bool _hide = true, _loading = false;

  void _forgotPassword() {
    final ctrl = TextEditingController(text: emailCtrl.text.trim());
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [Icon(Icons.lock_reset, color: Color(0xFF5C4D57)), SizedBox(width: 8), Text('Reset Password')]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Enter your registered email address. We\'ll send you a link to reset your password.', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
        SizedBox(height: 14),
        TextField(controller: ctrl, keyboardType: TextInputType.emailAddress, autofocus: true,
            decoration: InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white),
          onPressed: () async {
            final email = ctrl.text.trim();
            if (!email.contains('@') || !email.contains('.')) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a valid email.'), backgroundColor: Colors.red)); return;
            }
            Navigator.pop(ctx);
            bool sent = false;
            try {
              await FirebaseService.sendPasswordReset(email);
              sent = true;
            } catch (_) {
              sent = false;
            }
            showDialog(context: context, builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(children: [
                Icon(sent ? Icons.mark_email_read : Icons.error_outline, color: sent ? Colors.green : Colors.red),
                SizedBox(width: 8),
                Text(sent ? 'Reset Email Sent!' : 'Not Found'),
              ]),
              content: Text(sent
                  ? 'A password reset link has been sent to $email.\nCheck your inbox.'
                  : 'No account found for $email.\nPlease login first to activate your account.'),
              actions: [ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white), child: Text('OK'))],
            ));
          },
          child: Text('Send Reset Link'),
        ),
      ],
    ));
  }

  void _login() async {
    FocusScope.of(context).unfocus();
    final email = emailCtrl.text.trim();
    final pass  = passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) { _err('Please fill all fields.'); return; }
    if (!email.contains('@') || !email.contains('.')) { _err('Please enter a valid email address.\n(e.g. yourname@gmail.com)'); return; }
    if (pass.length < 6) { _err('Password must be at least 6 characters.'); return; }
    final lockMsg = BruteForceGuard.checkLockout(emailCtrl.text.trim());
    if (lockMsg != null) { _err(lockMsg); return; }
    setState(() => _loading = true);

    // Try Firebase login
    final result = await FirebaseService.loginStudent(
        emailCtrl.text.trim(), passCtrl.text, AppData.selectedHostelId);

    setState(() => _loading = false);

    if (result == 'WRONG_PASSWORD') {
      final lock = BruteForceGuard.recordFailure(emailCtrl.text.trim());
      _err(lock ?? 'Incorrect password. Please try again.');
      return;
    }

    if (result == null) {
      // Not in Firebase — try local fallback
      final error = AppData.loginUser(
          email: emailCtrl.text.trim(), password: passCtrl.text, hostelId: AppData.selectedHostelId);
      if (error != null) _err(error);
      else Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
      return;
    }

    // Success — result is the user map
    final userData = result as Map<String, dynamic>;
    AppData.currentUserEmail        = userData['email'] ?? '';
    AppData.currentUserName         = userData['name'] ?? '';
    AppData.currentUserRoom         = userData['room'] ?? '';
    AppData.currentUserHostelId     = userData['hostelId'] ?? '';
    AppData.currentUserEmoji        = userData['emoji'] ?? '';
    AppData.currentUserAvatarColor  = int.tryParse(userData['avatarColor'] ?? '0xFF5C4D57') ?? 0xFF5C4D57;
    AppData.currentUserUid          = userData['uid'] ?? '';
    AppData.currentUserIsAdmin      = false;
    AppData.currentUserIsSuperAdmin = false;
    AppData.selectedHostelId        = userData['hostelId'] ?? AppData.selectedHostelId;
    AppData.selectedHostelName      = HostelRegistry.getHostelName(AppData.selectedHostelId);
    BruteForceGuard.recordSuccess(emailCtrl.text.trim());
    await SessionManager.save(role: 'student');
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
  }

  void _err(String msg) => showDialog(context: context, builder: (_) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Row(children: [Icon(Icons.error_outline, color: Colors.red), SizedBox(width: 8), Text('Login Failed')]),
    content: Text(msg),
    actions: [ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white), child: Text('OK'))],
  ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.white,
      appBar: AppBar(title: Text('Login — ${AppData.selectedHostelName}'), backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white),
      body: Column(children: [
        NoInternetBanner(),
        Expanded(child: SingleChildScrollView(padding: EdgeInsets.all(24), child: Column(children: [
          SizedBox(height: 30), Icon(Icons.lock_outline, size: 70, color: Color(0xFF5C4D57)), SizedBox(height: 24),
          TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          SizedBox(height: 16),
          TextField(controller: passCtrl, obscureText: _hide, decoration: InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline),
              suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide = !_hide)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _loading ? CircularProgressIndicator(color: Colors.white) : Text('Login', style: TextStyle(fontSize: 18)))),
          SizedBox(height: 4),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _forgotPassword, child: Text('Forgot Password?', style: TextStyle(color: Color(0xFF5C4D57))))),
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen())), child: Text("Don't have an account? Request Registration", style: TextStyle(color: Color(0xFF5C4D57)))),
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CheckRequestStatusScreen())), child: Text('Check my request status', style: TextStyle(color: Colors.grey))),
        ]))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ADMIN PANEL — now has Registration Requests tab with badge
// ═══════════════════════════════════════════════════════════════════
class AdminPanelScreen extends StatefulWidget { @override _AdminPanelScreenState createState() => _AdminPanelScreenState(); }
class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final Set<String> _approvingIds = {};
  int _studentCount  = 0;
  int _chatUnread    = 0; // total unread for Chat tab badge
  StreamSubscription<QuerySnapshot>? _privateSub;
  StreamSubscription<QuerySnapshot>? _groupSub;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
    _listenChatUnread();
  }

  @override
  void dispose() {
    _privateSub?.cancel();
    _groupSub?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  void _listenChatUnread() {
    final email    = AppData.currentUserEmail;
    final hostelId = AppData.selectedHostelId;
    final myKey    = email.replaceAll('.', '_').replaceAll('@', '_');

    // Private chats unread
    _privateSub = FirebaseService.getPrivateChatsStream(email).listen((snap) {
      int total = 0;
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total += ((data['unreadCount_$myKey'] ?? 0) as num).toInt();
      }
      AppData.groupUnreadCount; // keep group count
      if (mounted) setState(() => _chatUnread = total + AppData.groupUnreadCount);
    });

    // Group chat unread
    _groupSub = FirebaseService.getGroupMessagesStream(hostelId).listen((snap) {
      final lastSeen = AppData.groupChatLastSeen;
      int count = 0;
      for (final doc in snap.docs) {
        final data   = doc.data() as Map<String, dynamic>;
        final sender = data['senderEmail'] ?? '';
        if (sender == email) continue;
        final ts = data['createdAt'];
        if (ts == null || lastSeen == null) { count++; continue; }
        if (ts is Timestamp && ts.toDate().isAfter(lastSeen)) count++;
      }
      AppData.groupUnreadCount = count;
      if (mounted) setState(() {});
    });
  }

  Widget _chatBadgeTab() {
    final unread = _tabs.index == 6 ? 0 : _chatUnread;
    if (unread == 0) return Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat');
    return Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.chat_bubble_outline, size: 18),
      SizedBox(width: 6),
      Text('Chat'),
      SizedBox(width: 4),
      Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10)),
          child: Text('$unread', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseService.getRegRequestsStream(AppData.selectedHostelId),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        final allReqs = docs.map((d) => {'id': d.id, ...d.data() as Map<String,dynamic>}).toList();
        final pending    = allReqs.where((r) => r['status'] == 'pending').toList();
        final registered = AppData.getRegisteredUsers(AppData.selectedHostelId);

        return Scaffold(
          appBar: AppBar(
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Warden Panel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(AppData.selectedHostelName, style: TextStyle(fontSize: 11, color: Colors.white70)),
            ]),
            backgroundColor: Colors.red[800], foregroundColor: Colors.white,
            actions: [IconButton(icon: Icon(Icons.logout), onPressed: () { () async { await SessionManager.clear(); AppData.logout(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WelcomeScreen())); }(); })],
            bottom: TabBar(controller: _tabs, labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: Colors.white, isScrollable: true, tabs: [
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Requests'),
                if (pending.isNotEmpty) ...[
                  SizedBox(width: 6),
                  Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10)),
                      child: Text('${pending.length}', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))),
                ],
              ])),
              Tab(text: 'Students ($_studentCount)'),
              Tab(text: 'Stats'),
              Tab(icon: Icon(Icons.swap_horiz, size: 16), text: 'Borrowing'),
              Tab(icon: Icon(Icons.volunteer_activism, size: 16), text: 'Lendings'),
              Tab(icon: Icon(Icons.storefront_outlined, size: 16), text: 'Marketplace'),
              _chatBadgeTab(),
            ]),
          ),
          body: TabBarView(controller: _tabs, children: [

            // ── TAB 1: Registration Requests (live stream) ────────
            snap.connectionState == ConnectionState.waiting
                ? Center(child: CircularProgressIndicator(color: Colors.red))
                : allReqs.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.inbox_outlined, size: 60, color: Colors.grey), SizedBox(height: 8),
              Text('No registration requests yet.', style: TextStyle(color: Colors.grey)),
            ]))
                : ListView.builder(padding: EdgeInsets.all(12), itemCount: allReqs.length, itemBuilder: (ctx, i) {
              final r = allReqs[i];
              final isPending  = r['status'] == 'pending';
              final isApproved = r['status'] == 'approved';
              Color statusColor = isPending ? Colors.orange : isApproved ? Colors.green : Colors.red;
              IconData statusIcon = isPending ? Icons.hourglass_top : isApproved ? Icons.check_circle : Icons.cancel;

              return Card(
                margin: EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: isPending ? Colors.orange.withOpacity(0.4) : Colors.transparent, width: 1.5)),
                child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(radius: 22, backgroundColor: Color(0xFF5C4D57), child: Text(r['name'].toString()[0].toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                    SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r['name'].toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(r['email'].toString(), style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ])),
                    Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(statusIcon, color: statusColor, size: 14), SizedBox(width: 4), Text(r['status'].toString().toUpperCase(), style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold))])),
                  ]),
                  SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.door_back_door_outlined, size: 14, color: Colors.grey), SizedBox(width: 4), Text(r['room'].toString(), style: TextStyle(color: Colors.grey, fontSize: 13)),
                    SizedBox(width: 16),
                    Icon(Icons.access_time, size: 14, color: Colors.grey), SizedBox(width: 4), Text(r['submittedAt']?.toString() ?? '', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                  if (r['status'] == 'rejected' && (r['rejectionReason']?.toString() ?? '').isNotEmpty) ...[
                    SizedBox(height: 6),
                    Text('Rejection reason: ${r['rejectionReason']}', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                  // Approve / Reject buttons — only for pending
                  if (isPending) ...[
                    SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: ElevatedButton.icon(
                        onPressed: _approvingIds.contains(r['id'].toString()) ? null : () async {
                          final reqId = r['id'].toString();
                          if (_approvingIds.contains(reqId)) return; // already processing
                          setState(() => _approvingIds.add(reqId));
                          final err = await FirebaseService.approveRequest(r, reqId);
                          RegRequest.approve(reqId);
                          if (mounted) {
                            setState(() => _approvingIds.remove(reqId));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(err == null ? '✅ ${r['name']} approved! Account created.' : '✅ Approved. Note: ${err}'),
                                backgroundColor: err == null ? Colors.green : Colors.orange));
                          }
                        },
                        icon: _approvingIds.contains(r['id'].toString())
                            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(Icons.check, size: 18),
                        label: Text(_approvingIds.contains(r['id'].toString()) ? 'Approving...' : 'Approve'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      )),
                      SizedBox(width: 10),
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () => _showRejectDialog(r['id'].toString()),
                        icon: Icon(Icons.close, size: 18, color: Colors.red), label: Text('Reject', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      )),
                    ]),
                  ],
                ])),
              );
            }),

            // ── TAB 2: Registered Students (Firebase) ────────────────
            FutureBuilder<List<Map<String, dynamic>>>(
                future: FirebaseService.getStudents(AppData.selectedHostelId),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting)
                    return Center(child: CircularProgressIndicator(color: Color(0xFF5C4D57)));
                  final students = snap.data ?? [];
                  // Update tab label count
                  if (students.length != _studentCount) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _studentCount = students.length);
                    });
                  }
                  if (students.isEmpty) return Center(child: Text('No students registered yet.', style: TextStyle(color: Colors.grey)));
                  return StatefulBuilder(builder: (ctx2, setLocal) => ListView.builder(padding: EdgeInsets.all(12), itemCount: students.length, itemBuilder: (ctx, i) {
                    final u = students[i];
                    return Card(margin: EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Color(0xFF5C4D57), child: Text(u['name'].toString()[0].toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          title: Text(u['name'].toString(), style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${u['email']}\nRoom: ${u['room']}'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                                icon: Icon(Icons.chat_bubble_outline, color: Colors.red[800]),
                                tooltip: 'Message student',
                                onPressed: () async {
                                  final chatId = await FirebaseService.getOrCreatePrivateChat(
                                      myEmail: AppData.currentUserEmail, myName: AppData.currentUserName,
                                      otherEmail: u['email'].toString(), otherName: u['name'].toString());
                                  Navigator.push(context, MaterialPageRoute(builder: (_) =>
                                      PrivateChatScreen(chatId: chatId, otherEmail: u['email'].toString(), otherName: u['name'].toString())));
                                }),
                            IconButton(
                              icon: Icon(Icons.person_remove_outlined, color: Colors.red[400]),
                              tooltip: 'Remove student',
                              onPressed: () => showDialog(context: context, builder: (_) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Remove Student?')]),
                                content: Text('Remove ${u['name']} from the hostel?\nThis cannot be undone.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      final uid = u['uid']?.toString() ?? '';
                                      if (uid.isNotEmpty) await FirebaseService.deleteStudent(uid);
                                      setLocal(() => students.removeAt(i));
                                      setState(() => _studentCount = students.length);
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text('${u['name']} removed.'),
                                        backgroundColor: Colors.red[700],
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ));
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                    child: Text('Remove'),
                                  ),
                                ],
                              )),
                            ),
                          ]),
                        ));
                  }));
                }),

            // ── TAB 3: Stats ──────────────────────────────────────────
            SingleChildScrollView(padding: EdgeInsets.all(20), child: Column(children: [
              SizedBox(height: 10),
              _statCard('Pending Requests', '${pending.length}', Icons.hourglass_top, Colors.orange),
              SizedBox(height: 12),
              _statCard('Registered Students', '$_studentCount', Icons.people, Color(0xFF5C4D57)),
              SizedBox(height: 12),
              _statCard('Total Requests Received', '${allReqs.length}', Icons.inbox_outlined, Colors.blue),
              SizedBox(height: 12),
              _statCard('Approved', '${allReqs.where((r) => r['status'] == 'approved').length}', Icons.check_circle, Colors.green),
              SizedBox(height: 12),
              _statCard('Rejected', '${allReqs.where((r) => r['status'] == 'rejected').length}', Icons.cancel, Colors.red),
            ])),

            // ── TAB 4: All Borrow Requests (warden view) ─────────────
            _WardenBorrowTab(),

            // ── TAB 5: All Lendings (warden view) ────────────────────
            _WardenLendingsTab(),

            // ── TAB 6: Marketplace (warden view) ─────────────────────
            _WardenMarketplaceTab(),

            // ── TAB 7: Chat ───────────────────────────────────────────
            WardenChatTab(onUnreadChanged: () { if (mounted) setState(() {}); }),
          ]),
        );
      },
    );
  }

  void _showRejectDialog(String reqId) {
    final reasonCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [Icon(Icons.cancel_outlined, color: Colors.red), SizedBox(width: 8), Text('Reject Request')]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Provide a reason so the student knows why they were rejected.'),
        SizedBox(height: 12),
        TextField(controller: reasonCtrl, maxLines: 3, decoration: InputDecoration(hintText: 'e.g. Not a registered resident, wrong hostel...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            await FirebaseService.rejectRequest(reqId, reasonCtrl.text);
            RegRequest.reject(reqId, reasonCtrl.text);
            Navigator.pop(context);
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request rejected.'), backgroundColor: Colors.red));
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: Text('Confirm Reject'),
        ),
      ],
    ));
  }

  Widget _statCard(String label, String val, IconData icon, Color color) => Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: EdgeInsets.all(14), child: Row(children: [
        CircleAvatar(backgroundColor: color.withOpacity(0.1), radius: 22, child: Icon(icon, color: color, size: 22)),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(val, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)), Text(label, style: TextStyle(color: Colors.grey, fontSize: 12))])),
      ])));
}

// ═══════════════════════════════════════════════════════════════════
// WARDEN — BORROW REQUESTS TAB (read-only overview)
// ═══════════════════════════════════════════════════════════════════
class _WardenBorrowTab extends StatefulWidget {
  @override __WardenBorrowTabState createState() => __WardenBorrowTabState();
}
class __WardenBorrowTabState extends State<_WardenBorrowTab> {
  String _search = '';
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: Icon(Icons.search, size: 20),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          SizedBox(width: 8),
          DropdownButton<String>(
            value: _filter,
            underline: SizedBox(),
            borderRadius: BorderRadius.circular(12),
            items: ['All', 'open', 'taken'].map((s) => DropdownMenuItem(value: s,
                child: Text(s == 'All' ? 'All' : s == 'open' ? 'Open' : 'Taken'))).toList(),
            onChanged: (v) => setState(() => _filter = v!),
          ),
        ]),
      ),
      Expanded(child: StreamBuilder(
        stream: FirebaseService.getBorrowRequestsStream(AppData.selectedHostelId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator(color: Colors.red[800]));
          final docs = snap.data?.docs ?? [];
          var items = docs
              .map((d) => {'docId': d.id, ...d.data() as Map<String, dynamic>})
              .where((r) => r['item'].toString().toLowerCase().contains(_search.toLowerCase()))
              .toList();
          if (_filter != 'All') items = items.where((r) => r['status'] == _filter).toList();

          if (items.isEmpty)
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.swap_horiz, size: 60, color: Colors.grey[300]),
              SizedBox(height: 10),
              Text('No borrow requests found.', style: TextStyle(color: Colors.grey)),
            ]));

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 16),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final r = items[i];
              final taken = r['status'] == 'taken';
              return Card(
                margin: EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(padding: EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(
                      backgroundColor: taken ? Colors.green.withOpacity(0.1) : Color(0xFF5C4D57).withOpacity(0.1),
                      radius: 20,
                      child: Icon(taken ? Icons.check_circle_outline : Icons.swap_horiz,
                          color: taken ? Colors.green : Color(0xFF5C4D57), size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r['item'].toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('${r['person']}  •  ${r['room']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ])),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: taken ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: taken ? Colors.green : Colors.orange),
                      ),
                      child: Text(taken ? 'Taken' : 'Open',
                          style: TextStyle(color: taken ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    _wChip(Icons.access_time, r['duration'].toString(), Colors.blue),
                    _wChip(Icons.category_outlined, r['category'].toString(), Color(0xFF5C4D57)),
                    if ((r['notes']?.toString() ?? '').isNotEmpty)
                      _wChip(Icons.notes, r['notes'].toString(), Colors.grey),
                  ]),
                  if (taken && r['lenderName'] != null) ...[
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.07), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        Icon(Icons.volunteer_activism, color: Colors.green, size: 14),
                        SizedBox(width: 6),
                        Text('Lent by ${r['lenderName']} (${r['lenderRoom'] ?? ''})',
                            style: TextStyle(color: Colors.green[700], fontSize: 12)),
                      ]),
                    ),
                  ],
                ])),
              );
            },
          );
        },
      )),
    ]);
  }

  Widget _wChip(IconData icon, String label, Color color) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color), SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 11)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════
// WARDEN — LENDINGS TAB (read-only overview of all hostel lendings)
// ═══════════════════════════════════════════════════════════════════
class _WardenLendingsTab extends StatefulWidget {
  @override __WardenLendingsTabState createState() => __WardenLendingsTabState();
}
class __WardenLendingsTabState extends State<_WardenLendingsTab> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('All Hostel Lendings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          DropdownButton<String>(
            value: _filter,
            underline: SizedBox(),
            borderRadius: BorderRadius.circular(12),
            items: ['All', 'Active', 'Returned'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _filter = v!),
          ),
        ]),
      ),
      Expanded(child: StreamBuilder(
        stream: FirebaseService.getHostelLendingsStream(AppData.selectedHostelId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator(color: Colors.red[800]));
          final docs = snap.data?.docs ?? [];
          var lendings = docs.map((d) => {'docId': d.id, ...d.data() as Map<String, dynamic>}).toList();
          if (_filter != 'All') lendings = lendings.where((l) => l['lendStatus'] == _filter).toList();

          final activeCount   = docs.where((d) => (d.data() as Map)['lendStatus'] == 'Active').length;
          final returnedCount = docs.where((d) => (d.data() as Map)['lendStatus'] == 'Returned').length;

          if (lendings.isEmpty)
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.volunteer_activism, size: 60, color: Colors.grey[300]),
              SizedBox(height: 10),
              Text('No lendings found.', style: TextStyle(color: Colors.grey)),
            ]));

          return Column(children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                _summaryChip('${docs.length} Total', Color(0xFF5C4D57)),
                SizedBox(width: 8),
                _summaryChip('$activeCount Active', Colors.green),
                SizedBox(width: 8),
                _summaryChip('$returnedCount Returned', Colors.grey),
              ]),
            ),
            Expanded(child: ListView.builder(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 16),
              itemCount: lendings.length,
              itemBuilder: (ctx, i) {
                final l = lendings[i];
                final active = l['lendStatus'] == 'Active';
                return Card(
                  margin: EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(padding: EdgeInsets.all(14), child: Row(children: [
                    CircleAvatar(
                      backgroundColor: active ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      radius: 22,
                      child: Icon(Icons.volunteer_activism, color: active ? Colors.green : Colors.grey, size: 22),
                    ),
                    SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l['item'].toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 3),
                      Text('From: ${l['lenderName'] ?? '—'}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                      Text('To: ${l['lentTo'] ?? '—'}  (${l['room'] ?? ''})', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                      Text('Date: ${l['lentDate'] ?? '—'}', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ])),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: active ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? Colors.green : Colors.grey),
                      ),
                      child: Text(active ? 'Active' : 'Returned',
                          style: TextStyle(color: active ? Colors.green : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ])),
                );
              },
            )),
          ]);
        },
      )),
    ]);
  }

  Widget _summaryChip(String label, Color color) => Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
    child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}

// ═══════════════════════════════════════════════════════════════════
// WARDEN — MARKETPLACE TAB (read-only overview)
// ═══════════════════════════════════════════════════════════════════
class _WardenMarketplaceTab extends StatefulWidget {
  @override __WardenMarketplaceTabState createState() => __WardenMarketplaceTabState();
}
class __WardenMarketplaceTabState extends State<_WardenMarketplaceTab> {
  String _search = '';
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search listings...',
                prefixIcon: Icon(Icons.search, size: 20),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          SizedBox(width: 8),
          DropdownButton<String>(
            value: _filter,
            underline: SizedBox(),
            borderRadius: BorderRadius.circular(12),
            items: ['All', 'available', 'sold'].map((s) => DropdownMenuItem(value: s,
                child: Text(s == 'All' ? 'All' : s == 'available' ? 'Available' : 'Sold'))).toList(),
            onChanged: (v) => setState(() => _filter = v!),
          ),
        ]),
      ),
      Expanded(child: StreamBuilder(
        stream: FirebaseService.getListingsStream(AppData.selectedHostelId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator(color: Colors.red[800]));
          final docs = snap.data?.docs ?? [];
          var listings = docs
              .map((d) => {'docId': d.id, ...d.data() as Map<String, dynamic>})
              .where((l) => l['title'].toString().toLowerCase().contains(_search.toLowerCase()))
              .toList();
          if (_filter != 'All') listings = listings.where((l) => l['status'] == _filter).toList();

          final availCount = docs.where((d) => (d.data() as Map)['status'] == 'available').length;
          final soldCount  = docs.where((d) => (d.data() as Map)['status'] == 'sold').length;

          if (listings.isEmpty)
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.storefront_outlined, size: 60, color: Colors.grey[300]),
              SizedBox(height: 10),
              Text('No listings found.', style: TextStyle(color: Colors.grey)),
            ]));

          return Column(children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                _summaryChip('${docs.length} Total', Color(0xFF5C4D57)),
                SizedBox(width: 8),
                _summaryChip('$availCount Available', Colors.green),
                SizedBox(width: 8),
                _summaryChip('$soldCount Sold', Colors.grey),
              ]),
            ),
            Expanded(child: ListView.builder(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 16),
              itemCount: listings.length,
              itemBuilder: (ctx, i) {
                final l = listings[i];
                final sold = l['status'] == 'sold';
                return Card(
                  margin: EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(padding: EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: sold ? Colors.grey.withOpacity(0.1) : Color(0xFF5C4D57).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text(l['emoji']?.toString() ?? '📦', style: TextStyle(fontSize: 24))),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l['title'].toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                          color: sold ? Colors.grey : Colors.black87)),
                      SizedBox(height: 3),
                      Text('Rs. ${l['price']}  •  ${l['condition']}',
                          style: TextStyle(color: Color(0xFF5C4D57), fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${l['sellerName']}  •  ${l['sellerRoom']}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      if ((l['description']?.toString() ?? '').isNotEmpty) ...[
                        SizedBox(height: 3),
                        Text(l['description'].toString(),
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ])),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: sold ? Colors.grey.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sold ? Colors.grey : Colors.green),
                      ),
                      child: Text(sold ? 'Sold' : 'Available',
                          style: TextStyle(color: sold ? Colors.grey : Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ])),
                );
              },
            )),
          ]);
        },
      )),
    ]);
  }

  Widget _summaryChip(String label, Color color) => Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
    child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}

// ═══════════════════════════════════════════════════════════════════
// WARDEN LOGIN SCREEN
// ═══════════════════════════════════════════════════════════════════
class AdminLoginScreen extends StatefulWidget { @override _AdminLoginScreenState createState() => _AdminLoginScreenState(); }
class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final emailCtrl = TextEditingController(), passCtrl = TextEditingController();
  String? _selectedHostelId; bool _hide = true, _loading = false;

  void _login() async {
    if (_selectedHostelId == null) { _err('Please select your hostel.'); return; }
    if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty) { _err('Please fill all fields.'); return; }
    final lockMsg = BruteForceGuard.checkLockout(emailCtrl.text.trim());
    if (lockMsg != null) { _err(lockMsg); return; }
    setState(() => _loading = true);

    // Try Firebase warden login first
    // Try Firebase (Firestore) login first
    final fbResult = await FirebaseService.loginWarden(emailCtrl.text.trim(), passCtrl.text, _selectedHostelId!);
    if (fbResult == 'WRONG_PASSWORD') {
      setState(() => _loading = false);
      final lock = BruteForceGuard.recordFailure(emailCtrl.text.trim());
      _err(lock ?? 'Incorrect password. Please try again.');
      return;
    }
    final fbData = fbResult as Map<String, dynamic>?;
    if (fbData != null) {
      AppData.selectedHostelId        = _selectedHostelId!;
      AppData.selectedHostelName      = HostelRegistry.getHostelName(_selectedHostelId!);
      AppData.currentUserEmail        = fbData['email']?.toString() ?? '';
      AppData.currentUserName         = fbData['name']?.toString() ?? '';
      AppData.currentUserHostelId     = _selectedHostelId!;
      AppData.currentUserIsAdmin      = true;
      AppData.currentUserIsSuperAdmin = false;
      AppData.currentUserUid          = fbData['uid']?.toString() ?? '';

      // Sync isTemp to local so fallback never triggers force-change again
      final localIdx = AppData.wardenAccounts.indexWhere(
            (w) => w['email']!.toLowerCase() == emailCtrl.text.trim().toLowerCase() && w['hostelId'] == _selectedHostelId,
      );
      final isTempFirebase = fbData['isTemp'] == true;
      if (localIdx != -1 && !isTempFirebase) {
        AppData.wardenAccounts[localIdx]['isTemp'] = 'no';
        AppData.wardenAccounts[localIdx]['password'] = passCtrl.text;
      }

      setState(() => _loading = false);
      BruteForceGuard.recordSuccess(emailCtrl.text.trim());
      await SessionManager.save(role: 'warden');
      if (isTempFirebase) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WardenChangePasswordScreen(
            email: emailCtrl.text.trim(), hostelId: _selectedHostelId!, currentPassword: passCtrl.text)));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminPanelScreen()));
      }
      return;
    }

    // Fallback to local login (only if Firebase failed — warden not in Firestore yet)
    final result = AppData.loginAdmin(email: emailCtrl.text.trim(), password: passCtrl.text, hostelId: _selectedHostelId!);
    setState(() => _loading = false);
    if (result == null) {
      // Local login worked — save warden to Firestore so future logins use Firebase
      final localWarden = AppData.wardenAccounts.firstWhere(
            (w) => w['email']!.toLowerCase() == emailCtrl.text.trim().toLowerCase() && w['hostelId'] == _selectedHostelId,
        orElse: () => {},
      );
      if (localWarden.isNotEmpty) {
        FirebaseService.createWarden(
          name: localWarden['name'] ?? '',
          email: emailCtrl.text.trim(),
          hostelId: _selectedHostelId!,
          tempPassword: passCtrl.text,
        );
      }
      AppData.selectedHostelId = _selectedHostelId!;
      AppData.selectedHostelName = HostelRegistry.getHostelName(_selectedHostelId!);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminPanelScreen()));
    } else if (result == 'FORCE_CHANGE_PASSWORD') {
      // Save warden to Firestore with isTemp=true so password change persists
      final localWarden = AppData.wardenAccounts.firstWhere(
            (w) => w['email']!.toLowerCase() == emailCtrl.text.trim().toLowerCase() && w['hostelId'] == _selectedHostelId,
        orElse: () => {},
      );
      if (localWarden.isNotEmpty) {
        FirebaseService.createWarden(
          name: localWarden['name'] ?? '',
          email: emailCtrl.text.trim(),
          hostelId: _selectedHostelId!,
          tempPassword: passCtrl.text,
        );
      }
      AppData.selectedHostelId = _selectedHostelId!;
      AppData.selectedHostelName = HostelRegistry.getHostelName(_selectedHostelId!);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WardenChangePasswordScreen(
          email: emailCtrl.text.trim(), hostelId: _selectedHostelId!, currentPassword: passCtrl.text)));
    } else {
      _err(result);
    }
  }

  void _err(String msg) => showDialog(context: context, builder: (_) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: Row(children: [Icon(Icons.error_outline, color: Colors.red), SizedBox(width: 8), Text('Error')]), content: Text(msg), actions: [ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: Text('OK'))]));

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.white,
      appBar: AppBar(title: Text('Warden Login'), backgroundColor: Colors.red[800], foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: EdgeInsets.all(24), child: Column(children: [
        SizedBox(height: 20), Icon(Icons.admin_panel_settings, size: 80, color: Colors.red[800]),
        Text('Warden Portal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red[800])),
        Text('Account created by HostelLink Super Admin', style: TextStyle(color: Colors.grey, fontSize: 12)),
        SizedBox(height: 30),
        DropdownButtonFormField<String>(value: _selectedHostelId,
            decoration: InputDecoration(labelText: 'Your Hostel', prefixIcon: Icon(Icons.apartment), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            items: HostelRegistry.activeHostels.map((h) => DropdownMenuItem(value: h['id'], child: Text(h['name']!))).toList(),
            onChanged: (v) => setState(() => _selectedHostelId = v)),
        SizedBox(height: 14),
        TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Your Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        SizedBox(height: 14),
        TextField(controller: passCtrl, obscureText: _hide, decoration: InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline),
            suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide = !_hide)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _login,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _loading ? CircularProgressIndicator(color: Colors.white) : Text('Login as Warden', style: TextStyle(fontSize: 18)))),
      ])),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WARDEN CHANGE PASSWORD SCREEN
// ═══════════════════════════════════════════════════════════════════
class WardenChangePasswordScreen extends StatefulWidget {
  final String email, hostelId, currentPassword;
  WardenChangePasswordScreen({required this.email, required this.hostelId, required this.currentPassword});
  @override _WardenChangePasswordScreenState createState() => _WardenChangePasswordScreenState();
}
class _WardenChangePasswordScreenState extends State<WardenChangePasswordScreen> {
  final newPassCtrl = TextEditingController(), confirmCtrl = TextEditingController();
  bool _hide1 = true, _hide2 = true, _loading = false;

  void _change() async {
    // Validate locally first (no Firebase yet)
    if (newPassCtrl.text != confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Passwords do not match!'), backgroundColor: Colors.red)); return;
    }
    if (newPassCtrl.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password must be at least 8 characters.'), backgroundColor: Colors.red)); return;
    }
    if (!newPassCtrl.text.contains(RegExp(r'[0-9]'))) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Must contain at least one number.'), backgroundColor: Colors.red)); return;
    }
    if (!newPassCtrl.text.contains(RegExp(r'[A-Z]'))) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Must contain at least one uppercase letter.'), backgroundColor: Colors.red)); return;
    }

    setState(() => _loading = true);

    // Update local AppData
    AppData.wardenChangePassword(
      email: widget.email, hostelId: widget.hostelId,
      oldPassword: widget.currentPassword, newPassword: newPassCtrl.text,
    );

    // Update Firestore (marks isTemp=false permanently)
    await FirebaseService.wardenChangePassword(
      email: widget.email, hostelId: widget.hostelId, newPassword: newPassCtrl.text,
    );

    setState(() => _loading = false);

    // Always open the warden panel — never show error
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('Password Set!')]),
        content: Text('Your password has been updated. Welcome to the Warden Panel!'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminPanelScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: Text('Enter Panel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.white,
        appBar: AppBar(title: Text('Set Your Password'), backgroundColor: Colors.red[800], foregroundColor: Colors.white, automaticallyImplyLeading: false),
        body: SingleChildScrollView(padding: EdgeInsets.all(24), child: Column(children: [
          SizedBox(height: 20), Icon(Icons.lock_reset, size: 80, color: Colors.orange), SizedBox(height: 12),
          Text('Change Temporary Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange)),
              child: Row(children: [Icon(Icons.warning_amber, color: Colors.orange), SizedBox(width: 8), Expanded(child: Text('You must set a personal password before continuing.', style: TextStyle(color: Colors.orange[800])))])),
          SizedBox(height: 24),
          TextField(controller: newPassCtrl, obscureText: _hide1, onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: 'New Password', prefixIcon: Icon(Icons.lock_outline),
                  suffixIcon: IconButton(icon: Icon(_hide1 ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide1 = !_hide1)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          SizedBox(height: 14),
          TextField(controller: confirmCtrl, obscureText: _hide2,
              decoration: InputDecoration(labelText: 'Confirm New Password', prefixIcon: Icon(Icons.lock_outline),
                  suffixIcon: IconButton(icon: Icon(_hide2 ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide2 = !_hide2)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          SizedBox(height: 12),
          _hint('At least 8 characters',         newPassCtrl.text.length >= 8),
          _hint('At least one number (0-9)',      newPassCtrl.text.contains(RegExp(r'[0-9]'))),
          _hint('At least one uppercase letter',  newPassCtrl.text.contains(RegExp(r'[A-Z]'))),
          SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _change,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _loading ? CircularProgressIndicator(color: Colors.white) : Text('Set Password & Continue', style: TextStyle(fontSize: 16)))),
        ])));
  }
  Widget _hint(String t, bool met) => Padding(padding: EdgeInsets.symmetric(vertical: 3), child: Row(children: [Icon(met ? Icons.check_circle : Icons.radio_button_unchecked, color: met ? Colors.green : Colors.grey, size: 18), SizedBox(width: 8), Text(t, style: TextStyle(color: met ? Colors.green : Colors.grey, fontSize: 13))]));
}

// ═══════════════════════════════════════════════════════════════════
// SUPER ADMIN LOGIN
// ═══════════════════════════════════════════════════════════════════
class SuperAdminLoginScreen extends StatefulWidget { @override _SuperAdminLoginScreenState createState() => _SuperAdminLoginScreenState(); }
class _SuperAdminLoginScreenState extends State<SuperAdminLoginScreen> {
  final codeCtrl = TextEditingController(), emailCtrl = TextEditingController(), passCtrl = TextEditingController();
  bool _hidePass = true, _hideCode = true, _loading = false;
  void _login() async {
    setState(() => _loading = true); await Future.delayed(Duration(milliseconds: 800));
    final error = await AppData.loginSuperAdmin(code: codeCtrl.text.trim(), email: emailCtrl.text.trim(), password: passCtrl.text);
    setState(() => _loading = false);
    if (error != null) { showDialog(context: context, builder: (_) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 8), Text('Access Denied')]), content: Text(error ?? 'Unknown error'), actions: [ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: Text('OK'))])); }
    else { await SessionManager.save(role: 'superadmin'); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SuperAdminPanelScreen())); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.grey[900],
        appBar: AppBar(title: Text('Restricted Access'), backgroundColor: Colors.grey[900], foregroundColor: Colors.white, elevation: 0),
        body: SingleChildScrollView(padding: EdgeInsets.all(24), child: Column(children: [
          SizedBox(height: 20), Icon(Icons.shield_outlined, size: 80, color: Colors.amber),
          Text('HostelLink Super Admin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          Text('Authorized personnel only', style: TextStyle(color: Colors.grey)), SizedBox(height: 32),
          _darkField(codeCtrl, 'Secret Access Code', Icons.key, obscure: _hideCode, toggle: () => setState(() => _hideCode = !_hideCode)),
          SizedBox(height: 14),
          _darkField(emailCtrl, 'Super Admin Email', Icons.email_outlined),
          SizedBox(height: 14),
          _darkField(passCtrl, 'Password', Icons.lock_outline, obscure: _hidePass, toggle: () => setState(() => _hidePass = !_hidePass)),
          SizedBox(height: 32),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _loading ? CircularProgressIndicator(color: Colors.black) : Text('Access Super Admin Panel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
          SizedBox(height: 20),
        ])));
  }
  Widget _darkField(TextEditingController c, String label, IconData icon, {bool obscure = false, VoidCallback? toggle}) =>
      TextField(controller: c, obscureText: obscure, style: TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: Colors.grey), prefixIcon: Icon(icon, color: Colors.amber),
              suffixIcon: toggle != null ? IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: toggle) : null,
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[700]!)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.amber))));
}

// ═══════════════════════════════════════════════════════════════════
// SUPER ADMIN PANEL
// ═══════════════════════════════════════════════════════════════════
class SuperAdminPanelScreen extends StatefulWidget { @override _SuperAdminPanelScreenState createState() => _SuperAdminPanelScreenState(); }
class _SuperAdminPanelScreenState extends State<SuperAdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override void initState() { super.initState(); _tabs = TabController(length: 4, vsync: this); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Super Admin Panel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text('HostelLink Master Control', style: TextStyle(fontSize: 11, color: Colors.amber))]),
        backgroundColor: Colors.grey[900], foregroundColor: Colors.white,
        actions: [IconButton(icon: Icon(Icons.logout), onPressed: () { () async { await SessionManager.clear(); AppData.logout(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WelcomeScreen())); }(); })],
        bottom: TabBar(controller: _tabs, labelColor: Colors.amber, unselectedLabelColor: Colors.grey, indicatorColor: Colors.amber, tabs: [Tab(icon: Icon(Icons.dashboard), text: 'Stats'), Tab(icon: Icon(Icons.apartment), text: 'Hostels'), Tab(icon: Icon(Icons.manage_accounts), text: 'Wardens'), Tab(icon: Icon(Icons.people), text: 'Students')]),
      ),
      body: TabBarView(controller: _tabs, children: [_StatsTab(), _HostelsTab(onRefresh: () => setState(() {})), _WardenTab(onRefresh: () => setState(() {})), _StudentsTab()]),
    );
  }
}

class _StatsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String,dynamic>>>(
      future: FirebaseService.getAllStudents(),
      builder: (ctx, snap) {
        final students = snap.data ?? [];
        return SingleChildScrollView(padding: EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: 10),
          Text('Platform Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 4), Text('All hostels across Pakistan', style: TextStyle(color: Colors.grey)), SizedBox(height: 20),
          Row(children: [
            Expanded(child: _sc('Active Hostels',   '${HostelRegistry.activeHostels.length}', Icons.apartment, Colors.blue)),
            SizedBox(width: 12),
            Expanded(child: _sc('Active Wardens',   '${AppData.wardenAccounts.where((w)=>w["active"]=="yes").length}', Icons.manage_accounts, Colors.green)),
          ]),
          SizedBox(height: 12),
          Row(children: [
            Expanded(child: _sc('Total Students',   '${students.length}', Icons.people, Color(0xFF5C4D57))),
            SizedBox(width: 12),
            Expanded(child: _sc('Pending Requests', '${RegRequest.all.where((r)=>r["status"]=="pending").length}', Icons.hourglass_top, Colors.orange)),
          ]),
          SizedBox(height: 24), Text('Hostel Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), SizedBox(height: 12),
          ...HostelRegistry.activeHostels.map((h) {
            final w = AppData.wardenAccounts.where((a) => a['hostelId']==h['id'] && a['active']=='yes').length;
            final s = students.where((u) => u['hostelId'] == h['id']).length;
            final p = RegRequest.pendingFor(h['id']!).length;
            return Card(margin: EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(padding: EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(h['name']!, style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${h["city"]} • ${h["university"]}', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  SizedBox(height: 8),
                  Row(children: [
                    _chip('$w Wardens', Colors.green), SizedBox(width: 8),
                    _chip('$s Students', Color(0xFF5C4D57)), SizedBox(width: 8),
                    if (p > 0) _chip('$p Pending', Colors.orange),
                  ]),
                ])));
          }).toList(),
        ]));
      },
    );
  }
  Widget _sc(String l, String v, IconData i, Color c) => Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8), child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, color: c, size: 20), SizedBox(height: 4), Text(v, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c)), SizedBox(height: 2), Text(l, style: TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center)])));
  Widget _chip(String l, Color c) => Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text(l, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.bold)));
}

class _HostelsTab extends StatefulWidget { final VoidCallback onRefresh; _HostelsTab({required this.onRefresh}); @override __HostelsTabState createState() => __HostelsTabState(); }
class __HostelsTabState extends State<_HostelsTab> {
  final nc = TextEditingController(), cc = TextEditingController(), uc = TextEditingController();
  void _add() { final e = HostelRegistry.addHostel(name: nc.text, city: cc.text, university: uc.text); if (e != null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e), backgroundColor: Colors.red)); return; } nc.clear(); cc.clear(); uc.clear(); setState(() {}); widget.onRefresh(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Hostel added!'), backgroundColor: Colors.green)); }
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Add New Hostel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 12),
      TextField(controller: nc, decoration: InputDecoration(labelText: 'Hostel Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))), SizedBox(height: 10),
      TextField(controller: cc, decoration: InputDecoration(labelText: 'City', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))), SizedBox(height: 10),
      TextField(controller: uc, decoration: InputDecoration(labelText: 'University', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))), SizedBox(height: 12),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _add, icon: Icon(Icons.add), label: Text('Add Hostel'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
      Divider(height: 30), Text('All Hostels (${HostelRegistry.hostels.length})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 10),
      ...HostelRegistry.hostels.map((h) { bool a = h['active'] == 'yes'; return Card(margin: EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: ListTile(leading: CircleAvatar(backgroundColor: a ? Colors.green[50] : Colors.grey[200], child: Icon(Icons.apartment, color: a ? Colors.green : Colors.grey)), title: Text(h['name']!, style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${h['city']} • ${h['university']}', style: TextStyle(fontSize: 12)), trailing: Switch(value: a, activeColor: Colors.green, onChanged: (_) { setState(() { h['active'] = a ? 'no' : 'yes'; }); FirebaseService.setHostelActive(h['id']!, !a); widget.onRefresh(); }))); }).toList(),
    ]));
  }
}

class _WardenTab extends StatefulWidget { final VoidCallback onRefresh; _WardenTab({required this.onRefresh}); @override __WardenTabState createState() => __WardenTabState(); }
class __WardenTabState extends State<_WardenTab> {
  final nc = TextEditingController(), ec = TextEditingController(), pc = TextEditingController(); String? _hid;
  void _create() {
    if (_hid == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select hostel.'), backgroundColor: Colors.red)); return; }
    final e = AppData.superAdminCreateWarden(name: nc.text, email: ec.text, hostelId: _hid!, tempPassword: pc.text);
    if (e != null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e), backgroundColor: Colors.red)); return; }
    showDialog(context: context, builder: (_) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('Warden Created!')]), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Share privately with the warden:'), SizedBox(height: 8), Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Hostel: ${HostelRegistry.getHostelName(_hid!)}', style: TextStyle(fontWeight: FontWeight.bold)), Text('Email: ${ec.text.trim()}'), Text('Temp Password: ${pc.text}'), SizedBox(height: 6), Text('⚠️ They must change password on first login.', style: TextStyle(color: Colors.orange, fontSize: 12))])),]), actions: [ElevatedButton(onPressed: () { Navigator.pop(context); nc.clear(); ec.clear(); pc.clear(); setState(() => _hid = null); }, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white), child: Text('OK, noted!'))]));
    setState(() {}); widget.onRefresh();
  }
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Create Warden Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 4),
      Text('Warden must change temp password on first login.', style: TextStyle(color: Colors.grey, fontSize: 12)), SizedBox(height: 14),
      DropdownButtonFormField<String>(value: _hid, decoration: InputDecoration(labelText: 'Select Hostel', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: HostelRegistry.activeHostels.map((h) => DropdownMenuItem(value: h['id'], child: Text(h['name']!))).toList(), onChanged: (v) => setState(() => _hid = v)),
      SizedBox(height: 10),
      TextField(controller: nc, decoration: InputDecoration(labelText: 'Warden Full Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))), SizedBox(height: 10),
      TextField(controller: ec, decoration: InputDecoration(labelText: 'Warden Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))), SizedBox(height: 10),
      TextField(controller: pc, decoration: InputDecoration(labelText: 'Temporary Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))), SizedBox(height: 14),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _create, icon: Icon(Icons.person_add), label: Text('Create Warden'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
      Divider(height: 30), Text('All Wardens (${AppData.wardenAccounts.length})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 10),
      ...AppData.wardenAccounts.map((w) { bool a = w['active'] == 'yes'; bool t = w['isTemp'] == 'yes'; return Card(margin: EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: ListTile(leading: CircleAvatar(backgroundColor: a ? Color(0xFF5C4D57).withOpacity(0.1) : Colors.grey[200], child: Icon(Icons.manage_accounts, color: a ? Color(0xFF5C4D57) : Colors.grey)), title: Text(w['name']!, style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(w['email']!), Text(HostelRegistry.getHostelName(w['hostelId']!), style: TextStyle(fontSize: 11)), if (t) Text('⚠️ Has not logged in yet', style: TextStyle(color: Colors.orange, fontSize: 11)), if (!t && a) Text('✅ Active', style: TextStyle(color: Colors.green, fontSize: 11))]), trailing: Switch(value: a, activeColor: Colors.green, onChanged: (_) { setState(() { AppData.wardenAccounts[AppData.wardenAccounts.indexOf(w)]['active'] = a ? 'no' : 'yes'; }); }))); }).toList(),
    ]));
  }
}

class _StudentsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: FirebaseService.getAllStudents(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator(color: Color(0xFF5C4D57)));
        final students = snap.data ?? [];
        if (students.isEmpty)
          return Center(child: Text('No students registered yet.', style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: students.length,
          itemBuilder: (ctx, i) {
            final u = students[i];
            final name     = u['name']?.toString() ?? '';
            final email    = u['email']?.toString() ?? '';
            final room     = u['room']?.toString() ?? '';
            final hostelId = u['hostelId']?.toString() ?? '';
            return Card(
              margin: EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Color(0xFF5C4D57),
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                title: Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('$email\n$room\n🏠 ${HostelRegistry.getHostelName(hostelId)}'),
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// HOME SCREEN + TABS
// ═══════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget { @override _HomeScreenState createState() => _HomeScreenState(); }
class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _privateUnread = 0;

  StreamSubscription<QuerySnapshot>? _privateSub;
  StreamSubscription<QuerySnapshot>? _groupSub;

  @override
  void initState() {
    super.initState();
    _seedSampleData();
    _listenUnread();
  }

  Future<void> _seedSampleData() async {
    final hostelId = AppData.currentUserHostelId;
    if (hostelId.isNotEmpty) await FirebaseService.seedSampleData(hostelId);
  }

  void _listenUnread() {
    final email    = AppData.currentUserEmail;
    final hostelId = AppData.currentUserHostelId.isNotEmpty
        ? AppData.currentUserHostelId : AppData.selectedHostelId;
    final myKey = email.replaceAll('.', '_').replaceAll('@', '_');

    // Private chats — sum all unreadCount_<myKey> fields
    _privateSub = FirebaseService.getPrivateChatsStream(email).listen((snap) {
      int total = 0;
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total += ((data['unreadCount_$myKey'] ?? 0) as num).toInt();
      }
      if (mounted) setState(() => _privateUnread = total);
    });

    // Group chat — count messages from others newer than last-seen timestamp
    _groupSub = FirebaseService.getGroupMessagesStream(hostelId).listen((snap) {
      final lastSeen = AppData.groupChatLastSeen;
      int count = 0;
      for (final doc in snap.docs) {
        final data   = doc.data() as Map<String, dynamic>;
        final sender = data['senderEmail'] ?? '';
        if (sender == email) continue;
        final ts = data['createdAt'];
        if (ts == null || lastSeen == null) { count++; continue; }
        if (ts is Timestamp && ts.toDate().isAfter(lastSeen)) count++;
      }
      AppData.groupUnreadCount = count;
      if (mounted) setState(() {});
    });
  }

  int get _totalChatUnread => _tab == 3 ? 0 : _privateUnread + AppData.groupUnreadCount;

  @override
  void dispose() {
    _privateSub?.cancel();
    _groupSub?.cancel();
    super.dispose();
  }

  Widget _badgeIcon(IconData icon, int count) {
    if (count == 0) return Icon(icon);
    return Stack(clipBehavior: Clip.none, children: [
      Icon(icon),
      Positioned(
        right: -7, top: -4,
        child: Container(
          padding: EdgeInsets.all(3),
          constraints: BoxConstraints(minWidth: 16, minHeight: 16),
          decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onRefresh: () => setState(() {})),
      MyRequestsPage(onRefresh: () => setState(() {})),
      MarketplacePage(onRefresh: () => setState(() {})),
      ChatListPage(onGroupOpened: () { if (mounted) setState(() {}); }),
      ProfilePage(onRefresh: () => setState(() {})),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('HostelLink', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(AppData.selectedHostelName, style: TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white, automaticallyImplyLeading: false,
        leading: Padding(
          padding: EdgeInsets.all(8),
          child: GestureDetector(
            onTap: () { setState(() => _tab = 4); },
            child: UserAvatar(radius: 18, name: AppData.currentUserName, emoji: AppData.currentUserEmoji, color: AppData.currentUserAvatarColor),
          ),
        ),
        actions: [Stack(children: [IconButton(icon: Icon(Icons.notifications_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen()))), if (AppData.notifications.isNotEmpty) Positioned(right: 8, top: 8, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Center(child: Text('${AppData.notifications.length}', style: TextStyle(color: Colors.white, fontSize: 10)))))])],
      ),
      body: pages[_tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        selectedItemColor: Color(0xFF5C4D57),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _tab = i),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home),                                         label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt),                                     label: 'Requests'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront_outlined),                          label: 'Market'),
          BottomNavigationBarItem(icon: _badgeIcon(Icons.chat_bubble_outline, _totalChatUnread),  label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person),                                       label: 'Profile'),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(backgroundColor: Color(0xFF5C4D57), child: Icon(Icons.add, color: Colors.white),
          onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRequestScreen())); setState(() {}); })
          : _tab == 2
          ? FloatingActionButton(backgroundColor: Colors.green, child: Icon(Icons.sell_outlined, color: Colors.white),
          onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => CreateListingScreen())); setState(() {}); })
          : _tab == 3
          ? FloatingActionButton(backgroundColor: Color(0xFF5C4D57), child: Icon(Icons.edit, color: Colors.white),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewPrivateChatScreen())))
          : null,
    );
  }
}


// ═══════════════════════════════════════════════════════════════════
// HOME PAGE — browse borrow requests + post your own
// ═══════════════════════════════════════════════════════════════════
class HomePage extends StatefulWidget {
  final VoidCallback onRefresh;
  HomePage({required this.onRefresh});
  @override _HomePageState createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Search bar
      Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search requests...',
            prefixIcon: Icon(Icons.search),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          ),
        ),
      ),

      // Live list
      Expanded(child: StreamBuilder(
        stream: FirebaseService.getBorrowRequestsStream(AppData.currentUserHostelId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator(color: Color(0xFF5C4D57)));

          final docs = snap.data?.docs ?? [];
          final items = docs
              .map((d) => {'docId': d.id, ...d.data() as Map<String, dynamic>})
              .where((r) =>
          r['status'] == 'open' &&   // ← ADD THIS LINE
              r['item'].toString().toLowerCase().contains(_search.toLowerCase()))
              .toList();

          if (items.isEmpty)
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
              SizedBox(height: 12),
              Text('No requests yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
              SizedBox(height: 4),
              Text('Tap + to post what you need', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ]));

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 80),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final r = items[i];
              final isOwn = r['posterEmail'] == AppData.currentUserEmail;
              return _requestCard(r, isOwn);
            },
          );
        },
      )),
    ]);
  }

  Widget _requestCard(Map<String, dynamic> r, bool isOwn) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            backgroundColor: Color(0xFF5C4D57).withOpacity(0.1),
            radius: 22,
            child: Text(
              r['person'].toString().isNotEmpty ? r['person'].toString()[0].toUpperCase() : '?',
              style: TextStyle(color: Color(0xFF5C4D57), fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r['item'].toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 2),
            Text('${r['person']}  •  ${r['room']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ])),
          if (isOwn)
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red[300]),
              onPressed: () async {
                await FirebaseService.deleteBorrowRequest(r['docId']);
              },
            ),
        ]),
        SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          _chip(Icons.access_time, r['duration'].toString(), Colors.blue),
          _chip(Icons.category_outlined, r['category'].toString(), Color(0xFF5C4D57)),
          if ((r['notes']?.toString() ?? '').isNotEmpty)
            _chip(Icons.notes, r['notes'].toString(), Colors.grey),
        ]),
        if (!isOwn) ...[
          SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () => _confirmLend(r),
            icon: Icon(Icons.volunteer_activism, size: 18),
            label: Text('Lend This Item'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
          )),
        ],
        if (isOwn) ...[
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('Your request — waiting for someone to lend', style: TextStyle(color: Colors.orange[700], fontSize: 12)),
          ),
        ],
      ])),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ]),
    );
  }

  void _confirmLend(Map<String, dynamic> r) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Confirm Lending'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('You are agreeing to lend:'),
        SizedBox(height: 10),
        Container(padding: EdgeInsets.all(12),
          decoration: BoxDecoration(color: Color(0xFF5C4D57).withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r['item'].toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            SizedBox(height: 4),
            Text('To: ${r['person']}  (${r['room']})', style: TextStyle(color: Colors.grey[700])),
            Text('Duration: ${r['duration']}', style: TextStyle(color: Colors.grey[700])),
          ]),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            // Mark request as taken AND save who is lending
            await FirebaseService.updateBorrowRequestStatus(r['docId'], 'taken',
              lenderName: AppData.currentUserName,
              lenderRoom: AppData.currentUserRoom,
            );
            // Save to lendings collection so lender sees it in My Lendings
            await FirebaseService.addLending({
              'item':        r['item'],
              'person':      r['person'],
              'room':        r['room'],
              'duration':    r['duration'],
              'category':    r['category'],
              'lentTo':      r['person'],
              'lentToEmail': r['posterEmail'] ?? '',
              'lentDate':    DateTime.now().toString().substring(0, 10),
              'lendStatus':  'Active',
              'lenderEmail': AppData.currentUserEmail,
              'lenderName':  AppData.currentUserName,
              'hostelId':    AppData.currentUserHostelId,
              'requestDocId': r['docId'],
            });
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Done! ${r['person']} will be notified.'), backgroundColor: Colors.green));
          },
          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white),
          child: Text('Yes, I will Lend'),
        ),
      ],
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════
// MY REQUESTS PAGE — 2 sub-tabs: My Requests + My Lendings
// ═══════════════════════════════════════════════════════════════════
class MyRequestsPage extends StatefulWidget {
  final VoidCallback onRefresh;
  MyRequestsPage({required this.onRefresh});
  @override _MyRequestsPageState createState() => _MyRequestsPageState();
}
class _MyRequestsPageState extends State<MyRequestsPage> with SingleTickerProviderStateMixin {
  late TabController _t;
  @override void initState() { super.initState(); _t = TabController(length: 2, vsync: this); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TabBar(
        controller: _t,
        labelColor: Color(0xFF5C4D57),
        unselectedLabelColor: Colors.grey,
        indicatorColor: Color(0xFF5C4D57),
        tabs: [Tab(icon: Icon(Icons.download_outlined, size: 18), text: 'My Requests'),
          Tab(icon: Icon(Icons.upload_outlined,   size: 18), text: 'My Lendings')],
      ),
      Expanded(child: TabBarView(controller: _t, children: [
        _myRequestsTab(),
        _myLendingsTab(),
      ])),
    ]);
  }

  // ── Sub-tab 1: Requests I posted (items I need) ───────────────
  Widget _myRequestsTab() {
    return StreamBuilder(
      stream: FirebaseService.getMyBorrowRequestsStream(AppData.currentUserEmail, AppData.currentUserHostelId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator(color: Color(0xFF5C4D57)));
        final docs = snap.data?.docs ?? [];
        final reqs = docs.map((d) => {'docId': d.id, ...d.data() as Map<String, dynamic>}).toList();
        if (reqs.isEmpty)
          return _empty('You have not posted any requests yet.\nGo to Home tab and tap + to post what you need.');
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: reqs.length,
          itemBuilder: (ctx, i) {
            final r = reqs[i];
            final taken = r['status'] == 'taken';
            return Card(
              margin: EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(padding: EdgeInsets.all(16), child: Row(children: [
                CircleAvatar(
                  backgroundColor: taken ? Colors.green.withOpacity(0.12) : Color(0xFF5C4D57).withOpacity(0.1),
                  radius: 22,
                  child: Icon(taken ? Icons.check_circle_outline : Icons.hourglass_top_outlined,
                      color: taken ? Colors.green : Color(0xFF5C4D57), size: 22),
                ),
                SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r['item'].toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 3),
                  Text('⏱ ${r['duration']}   📦 ${r['category']}', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  SizedBox(height: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: taken ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: taken
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('✅ Will be lent by:', style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('👤 ${r['lenderName'] ?? 'A hostelmate'}', style: TextStyle(color: Colors.green[800], fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('🚪 ${r['lenderRoom'] ?? ''}', style: TextStyle(color: Colors.green[700], fontSize: 12)),
                    ])
                        : Text('⏳ Waiting for a lender', style: TextStyle(color: Colors.orange[700], fontSize: 12)),
                  ),
                ])),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red[300], size: 22),
                  onPressed: () async { await FirebaseService.deleteBorrowRequest(r['docId']); },
                ),
              ])),
            );
          },
        );
      },
    );
  }

  // ── Sub-tab 2: Items I lent to others ────────────────────────
  Widget _myLendingsTab() {
    return StreamBuilder(
      stream: FirebaseService.getMyLendingsStream(AppData.currentUserEmail, AppData.currentUserHostelId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator(color: Colors.green));
        final docs = snap.data?.docs ?? [];
        final lendings = docs.map((d) => {'docId': d.id, ...d.data() as Map<String, dynamic>}).toList();
        if (lendings.isEmpty)
          return _empty('You have not lent anything yet.\nGo to Home tab and tap Lend on someone\'s request.');
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: lendings.length,
          itemBuilder: (ctx, i) {
            final l = lendings[i];
            final active = l['lendStatus'] == 'Active';
            return Card(
              margin: EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(
                    backgroundColor: Colors.green.withOpacity(0.1),
                    radius: 22,
                    child: Icon(Icons.volunteer_activism, color: Colors.green, size: 22),
                  ),
                  SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l['item'].toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    SizedBox(height: 3),
                    Text('Lent to: ${l['lentTo']}  (${l['room']})', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    Text('Date: ${l['lentDate']}', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ])),
                ]),
                SizedBox(height: 12),
                active
                    ? SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: () async {
                    await FirebaseService.markLendingReturned(l['docId']);
                    _rateDialog(l['lentTo'].toString());
                  },
                  icon: Icon(Icons.check_circle_outline, size: 18),
                  label: Text('Mark as Returned'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ))
                    : Row(children: [
                  Icon(Icons.check_circle, color: Colors.grey, size: 18),
                  SizedBox(width: 6),
                  Text('Returned', style: TextStyle(color: Colors.grey)),
                ]),
              ])),
            );
          },
        );
      },
    );
  }

  Widget _empty(String msg) => Center(child: Padding(padding: EdgeInsets.all(32), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
    SizedBox(height: 12),
    Text(msg, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
  ])));

  void _rateDialog(String name) {
    int stars = 5;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Rate your experience'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('How was lending to $name?'),
        SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) =>
            GestureDetector(
              onTap: () => ss(() => stars = i + 1),
              child: Icon(i < stars ? Icons.star : Icons.star_border, color: Colors.amber, size: 36),
            ))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Skip')),
        ElevatedButton(
          onPressed: () { Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⭐ Rated $stars stars!'), backgroundColor: Colors.amber[700]));
          },
          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white),
          child: Text('Submit'),
        ),
      ],
    )));
  }
}

// ═══════════════════════════════════════════════════════════════════
// PROFILE PAGE
// ═══════════════════════════════════════════════════════════════════
class ProfilePage extends StatefulWidget { final VoidCallback onRefresh; ProfilePage({required this.onRefresh}); @override _ProfilePageState createState() => _ProfilePageState(); }
class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: EdgeInsets.all(24), child: Column(children: [
      SizedBox(height: 10),
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen())).then((_) => setState(() {})),
        child: UserAvatar(radius: 55, name: AppData.currentUserName, emoji: AppData.currentUserEmoji, color: AppData.currentUserAvatarColor, showEditBadge: true),
      ),
      SizedBox(height: 8),
      TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen())).then((_) => setState(() {})),
          child: Text('Change profile picture', style: TextStyle(color: Color(0xFF5C4D57), fontSize: 13))),
      Text(AppData.currentUserName.isNotEmpty ? AppData.currentUserName : 'User', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      Text(AppData.currentUserRoom.isNotEmpty ? AppData.currentUserRoom : 'No room set', style: TextStyle(color: Colors.grey)),
      Text(AppData.selectedHostelName, style: TextStyle(color: Color(0xFF5C4D57), fontSize: 13)),
      SizedBox(height: 24),
      _m(Icons.edit_outlined, 'Edit Profile', () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen())).then((_) => setState(() {}))),
      _m(Icons.help_outline, 'Help & Support', () => showDialog(context: context, builder: (_) => AlertDialog(title: Text('Support'), content: Text('Email: hostellink@support.com'), actions: [ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white), child: Text('Close'))]))),
      SizedBox(height: 16),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        onPressed: () async { await SessionManager.clear(); AppData.logout(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WelcomeScreen())); },
        icon: Icon(Icons.logout, color: Colors.red),
        label: Text('Logout', style: TextStyle(color: Colors.red, fontSize: 16)),
        style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red), padding: EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      )),
    ]));
  }
  Widget _m(IconData i, String t, VoidCallback f) => Card(margin: EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: ListTile(leading: Icon(i, color: Color(0xFF5C4D57)), title: Text(t), trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey), onTap: f));
}

// ═══════════════════════════════════════════════════════════════════
// CREATE REQUEST SCREEN
// ═══════════════════════════════════════════════════════════════════
class CreateRequestScreen extends StatefulWidget { @override _CreateRequestScreenState createState() => _CreateRequestScreenState(); }
class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _itemCtrl     = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  String _category = 'Electronics';
  bool _loading = false;

  final _categories = ['Electronics', 'Books', 'Personal Care', 'Kitchen', 'Clothing', 'General'];

  void _submit() async {
    if (_itemCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter item name.'), backgroundColor: Colors.red)); return;
    }
    if (_durationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter how long you need it.'), backgroundColor: Colors.red)); return;
    }
    setState(() => _loading = true);
    await FirebaseService.addBorrowRequest({
      'item':        _itemCtrl.text.trim(),
      'person':      AppData.currentUserName,
      'room':        AppData.currentUserRoom,
      'duration':    _durationCtrl.text.trim(),
      'category':    _category,
      'notes':       _notesCtrl.text.trim(),
      'status':      'open',
      'posterEmail': AppData.currentUserEmail,
      'hostelId':    AppData.currentUserHostelId,
    });
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request posted!'), backgroundColor: Colors.green));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text('Post a Request'), backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('What do you need to borrow?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 20),
        TextField(controller: _itemCtrl,
            decoration: InputDecoration(labelText: 'Item Name *', hintText: 'e.g. Phone Charger, Hair Dryer',
                prefixIcon: Icon(Icons.inventory_2_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _category = v!),
        ),
        SizedBox(height: 16),
        TextField(controller: _durationCtrl,
            decoration: InputDecoration(labelText: 'How long do you need it? *', hintText: 'e.g. 2 hours, 1 day',
                prefixIcon: Icon(Icons.access_time), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        SizedBox(height: 16),
        TextField(controller: _notesCtrl, maxLines: 2,
            decoration: InputDecoration(labelText: 'Extra notes (optional)', hintText: 'Any extra details...',
                prefixIcon: Icon(Icons.notes), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        SizedBox(height: 28),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _loading ? CircularProgressIndicator(color: Colors.white) : Text('Post Request', style: TextStyle(fontSize: 17)),
        )),
      ])),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MARKETPLACE — buy/sell only
// ═══════════════════════════════════════════════════════════════════
class MarketplacePage extends StatefulWidget {
  final VoidCallback onRefresh;
  MarketplacePage({required this.onRefresh});
  @override _MarketplacePageState createState() => _MarketplacePageState();
}
class _MarketplacePageState extends State<MarketplacePage> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Search bar
      Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search items for sale...',
            prefixIcon: Icon(Icons.search),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          ),
        ),
      ),

      // Live listings
      Expanded(child: StreamBuilder(
        stream: FirebaseService.getListingsStream(AppData.currentUserHostelId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator(color: Colors.green));

          final docs = snap.data?.docs ?? [];
          final items = docs
              .map((d) => {'docId': d.id, ...d.data() as Map<String, dynamic>})
              .where((l) =>
          l['title'].toString().toLowerCase().contains(_search.toLowerCase()) ||
              l['description'].toString().toLowerCase().contains(_search.toLowerCase()))
              .toList();

          if (items.isEmpty)
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.storefront_outlined, size: 64, color: Colors.grey[300]),
              SizedBox(height: 12),
              Text('Nothing for sale yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
              SizedBox(height: 4),
              Text('Tap + to sell something', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ]));

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 80),
            itemCount: items.length,
            itemBuilder: (ctx, i) => _listingCard(items[i]),
          );
        },
      )),
    ]);
  }

  Widget _listingCard(Map<String, dynamic> l) {
    final isOwn = l['sellerEmail'] == AppData.currentUserEmail;
    final isSold = l['status'] == 'sold';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: isSold ? 0 : 2,
      color: isSold ? Colors.grey[50] : Colors.white,
      child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 54, height: 54,
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(l['emoji']?.toString() ?? '📦', style: TextStyle(fontSize: 28)))),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l['title'].toString(),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isSold ? Colors.grey : Colors.black)),
            SizedBox(height: 3),
            Text('PKR ${l['price']}',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isSold ? Colors.grey : Colors.green)),
            SizedBox(height: 3),
            Row(children: [
              _condBadge(l['condition']?.toString() ?? ''),
              SizedBox(width: 8),
              if (isSold) Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text('SOLD', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold))),
            ]),
          ])),
        ]),
        SizedBox(height: 8),
        Text(l['description'].toString(), style: TextStyle(color: Colors.grey[700], fontSize: 13)),
        SizedBox(height: 6),
        Text('${l['sellerName']}  •  ${l['sellerRoom']}  •  ${l['postedAt']}',
            style: TextStyle(color: Colors.grey[400], fontSize: 12)),

        // Buttons
        if (!isSold) ...[
          SizedBox(height: 12),
          if (!isOwn) Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () => _contactDialog(l),
              icon: Icon(Icons.chat_bubble_outline, size: 17),
              label: Text('Contact Seller'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: EdgeInsets.symmetric(vertical: 10)),
            )),
          ]),
          if (isOwn) Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () => _markSoldDialog(l),
              icon: Icon(Icons.check_circle_outline, size: 17),
              label: Text('Mark as Sold'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: EdgeInsets.symmetric(vertical: 10)),
            )),
            SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () async { await FirebaseService.deleteListing(l['docId']); },
              icon: Icon(Icons.delete_outline, size: 17, color: Colors.red),
              label: Text('Delete', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: EdgeInsets.symmetric(vertical: 10)),
            ),
          ]),
        ],
      ])),
    );
  }

  Widget _condBadge(String cond) {
    final color = cond == 'New' ? Colors.green : cond == 'Good' ? Colors.blue : Colors.orange;
    return Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.4))),
        child: Text(cond, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)));
  }

  void _contactDialog(Map<String, dynamic> l) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [Icon(Icons.chat_bubble_outline, color: Colors.green), SizedBox(width: 8), Text('Contact Seller')]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l['title'].toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text('PKR ${l['price']}', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
        Divider(height: 20),
        _infoRow(Icons.person_outline, l['sellerName'].toString()),
        _infoRow(Icons.door_back_door_outlined, l['sellerRoom'].toString()),
        _infoRow(Icons.email_outlined, l['sellerEmail'].toString()),
        SizedBox(height: 10),
        Container(padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.07), borderRadius: BorderRadius.circular(10)),
            child: Text('Visit her room or email her to discuss the purchase.', style: TextStyle(color: Colors.green[800], fontSize: 12))),
      ]),
      actions: [ElevatedButton(onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: Text('Got it'))],
    ));
  }

  void _markSoldDialog(Map<String, dynamic> l) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Mark as Sold?'),
      content: Text('Mark "${l['title']}" as sold? It will stay visible but show as SOLD.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: () async { await FirebaseService.markListingSold(l['docId']); Navigator.pop(context); },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
          child: Text('Yes, Mark Sold'),
        ),
      ],
    ));
  }

  Widget _infoRow(IconData icon, String text) => Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [Icon(icon, size: 16, color: Colors.grey), SizedBox(width: 8), Text(text, style: TextStyle(fontSize: 13))]));
}

// ═══════════════════════════════════════════════════════════════════
// CREATE LISTING SCREEN — sell an item
// ═══════════════════════════════════════════════════════════════════
class CreateListingScreen extends StatefulWidget { @override _CreateListingScreenState createState() => _CreateListingScreenState(); }
class _CreateListingScreenState extends State<CreateListingScreen> {
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  String _category  = 'Books';
  String _condition = 'Good';
  String _emoji     = '📦';
  bool _loading = false;

  final _emojis     = ['📚','💻','📱','🔢','💡','🧴','👗','🧣','👟','🎒','🍳','🪑','🛏️','📦','🎵','🎨','⚽','🧸','💄','🪞'];
  final _categories = ['Books', 'Electronics', 'Personal Care', 'Clothing', 'Kitchen', 'Furniture', 'Sports', 'Other'];
  final _conditions = ['New', 'Good', 'Used'];

  void _submit() async {
    if (_titleCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter item title.'), backgroundColor: Colors.red)); return; }
    if (_priceCtrl.text.trim().isEmpty || int.tryParse(_priceCtrl.text.trim()) == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a valid price.'), backgroundColor: Colors.red)); return; }
    if (_descCtrl.text.trim().isEmpty)  { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please add a description.'), backgroundColor: Colors.red)); return; }
    setState(() => _loading = true);
    final now = DateTime.now();
    await FirebaseService.addListing({
      'title':       _titleCtrl.text.trim(),
      'price':       _priceCtrl.text.trim(),
      'condition':   _condition,
      'category':    _category,
      'description': _descCtrl.text.trim(),
      'emoji':       _emoji,
      'sellerName':  AppData.currentUserName,
      'sellerRoom':  AppData.currentUserRoom,
      'sellerEmail': AppData.currentUserEmail,
      'hostelId':    AppData.currentUserHostelId,
      'status':      'available',
      'postedAt':    '${now.day}/${now.month}/${now.year}',
    });
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Listing posted!'), backgroundColor: Colors.green));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text('Sell an Item'), backgroundColor: Colors.green, foregroundColor: Colors.white,
          actions: [TextButton(onPressed: _loading ? null : _submit, child: Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))]),
      body: SingleChildScrollView(padding: EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Emoji picker
        Text('Item Emoji', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _emojis.map((e) {
          final sel = _emoji == e;
          return GestureDetector(onTap: () => setState(() => _emoji = e),
              child: Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: sel ? Colors.green.withOpacity(0.15) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? Colors.green : Colors.transparent, width: 2)),
                  child: Center(child: Text(e, style: TextStyle(fontSize: 22)))));
        }).toList()),
        SizedBox(height: 20),
        TextField(controller: _titleCtrl, decoration: InputDecoration(labelText: 'Item Title *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        SizedBox(height: 14),
        TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Price (PKR) *', prefixIcon: Icon(Icons.monetization_on_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        SizedBox(height: 14),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: _category, decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _category = v!))),
          SizedBox(width: 12),
          Expanded(child: DropdownButtonFormField<String>(value: _condition, decoration: InputDecoration(labelText: 'Condition', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
              items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _condition = v!))),
        ]),
        SizedBox(height: 14),
        TextField(controller: _descCtrl, maxLines: 3, decoration: InputDecoration(labelText: 'Description *', hintText: 'Describe the item...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        SizedBox(height: 28),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _loading ? CircularProgressIndicator(color: Colors.white) : Text('Post Listing', style: TextStyle(fontSize: 17)),
        )),
      ])),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════
// CHAT — Group Chat + Private Messaging
// ═══════════════════════════════════════════════════════════════════

// ── Chat List Page (tab) ─────────────────────────────────────────
class ChatListPage extends StatefulWidget {
  final VoidCallback? onGroupOpened;
  ChatListPage({this.onGroupOpened});
  @override _ChatListPageState createState() => _ChatListPageState();
}
class _ChatListPageState extends State<ChatListPage> {

  void _openGroupChat(BuildContext context) async {
    AppData.markGroupChatSeen();
    widget.onGroupOpened?.call();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatScreen()));
    // On return, mark seen again in case new msgs arrived while inside
    AppData.markGroupChatSeen();
    widget.onGroupOpened?.call();
    if (mounted) setState(() {});
  }

  void _openPrivateChat(BuildContext context, String chatId, String otherEmail, String otherName, String myKey) async {
    // Clear unread for this chat in Firestore
    await FirebaseService.clearPrivateChatUnread(chatId: chatId, myKey: myKey);
    await Navigator.push(context, MaterialPageRoute(
        builder: (_) => PrivateChatScreen(chatId: chatId, otherEmail: otherEmail, otherName: otherName)));
    await FirebaseService.clearPrivateChatUnread(chatId: chatId, myKey: myKey);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final groupUnread = AppData.groupUnreadCount;
    return ListView(padding: EdgeInsets.all(16), children: [
      SizedBox(height: 8),
      Text('Chat', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF5C4D57))),
      SizedBox(height: 4),
      Text('Talk with hostelmates & warden', style: TextStyle(color: Colors.grey, fontSize: 13)),
      SizedBox(height: 20),

      // Group Chat card
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: Stack(clipBehavior: Clip.none, children: [
            CircleAvatar(radius: 26, backgroundColor: Color(0xFF5C4D57),
                child: Icon(Icons.groups, color: Colors.white, size: 28)),
            if (groupUnread > 0) Positioned(right: -4, top: -4,
                child: Container(
                    padding: EdgeInsets.all(4),
                    constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                    child: Text(groupUnread > 99 ? '99+' : '$groupUnread',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center))),
          ]),
          title: Text('Hostel Group Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text('Everyone in ${AppData.selectedHostelName}', style: TextStyle(fontSize: 12, color: Colors.grey)),
          trailing: groupUnread > 0
              ? Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
              child: Text('$groupUnread new', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))
              : Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: () => _openGroupChat(context),
        ),
      ),

      SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Private Messages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewPrivateChatScreen())),
          icon: Icon(Icons.add, size: 18, color: Color(0xFF5C4D57)),
          label: Text('New', style: TextStyle(color: Color(0xFF5C4D57))),
        ),
      ]),
      SizedBox(height: 8),

      // Private chats stream
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.getPrivateChatsStream(AppData.currentUserEmail),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator(color: Color(0xFF5C4D57)));
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty)
            return Center(child: Padding(padding: EdgeInsets.all(30), child: Column(children: [
              Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
              SizedBox(height: 8),
              Text('No private chats yet.', style: TextStyle(color: Colors.grey)),
              Text('Tap + New to start a conversation.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ])));
          return Column(children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final participants = List<String>.from(data['participants'] ?? []);
            final otherEmail = participants.firstWhere((e) => e != AppData.currentUserEmail, orElse: () => '');
            final otherName  = data['participantNames']?[otherEmail] ?? otherEmail;
            final lastMsg    = data['lastMessage'] ?? 'No messages yet';
            final lastTime   = data['lastMessageTime'] ?? '';
            final unread     = (data['unreadCount_${AppData.currentUserEmail.replaceAll('.', '_').replaceAll('@', '_')}'] ?? 0) as int;
            return Card(
              margin: EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Color(0xFF9E6B70),
                    child: Text(otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                title: Text(otherName, style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12)),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(lastTime.length > 5 ? lastTime.substring(0, 5) : lastTime, style: TextStyle(fontSize: 10, color: Colors.grey)),
                  if (unread > 0) ...[
                    SizedBox(height: 4),
                    Container(padding: EdgeInsets.all(5), decoration: BoxDecoration(color: Color(0xFF5C4D57), shape: BoxShape.circle),
                        child: Text('$unread', style: TextStyle(color: Colors.white, fontSize: 10))),
                  ]
                ]),
                onTap: () {
                  final myKey = AppData.currentUserEmail.replaceAll('.', '_').replaceAll('@', '_');
                  _openPrivateChat(context, doc.id, otherEmail, otherName, myKey);
                },
              ),
            );
          }).toList());
        },
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════
// WARDEN CHAT TAB — Group + Private messages for warden
// ═══════════════════════════════════════════════════════════════════
class WardenChatTab extends StatefulWidget {
  final VoidCallback? onUnreadChanged;
  WardenChatTab({this.onUnreadChanged});
  @override _WardenChatTabState createState() => _WardenChatTabState();
}
class _WardenChatTabState extends State<WardenChatTab> {

  void _openGroupChat() async {
    AppData.markGroupChatSeen();
    widget.onUnreadChanged?.call();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatScreen()));
    AppData.markGroupChatSeen();
    widget.onUnreadChanged?.call();
    if (mounted) setState(() {});
  }

  void _openPrivateChat(String chatId, String otherEmail, String otherName) async {
    final myKey = AppData.currentUserEmail.replaceAll('.', '_').replaceAll('@', '_');
    await FirebaseService.clearPrivateChatUnread(chatId: chatId, myKey: myKey);
    await Navigator.push(context, MaterialPageRoute(
        builder: (_) => PrivateChatScreen(chatId: chatId, otherEmail: otherEmail, otherName: otherName)));
    await FirebaseService.clearPrivateChatUnread(chatId: chatId, myKey: myKey);
    widget.onUnreadChanged?.call();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final groupUnread = AppData.groupUnreadCount;
    return ListView(padding: EdgeInsets.all(16), children: [
      SizedBox(height: 8),
      Text('Chat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red[800])),
      SizedBox(height: 4),
      Text('Message students & monitor group chat', style: TextStyle(color: Colors.grey, fontSize: 13)),
      SizedBox(height: 16),

      // ── Group Chat card ─────────────────────────────────────
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: Stack(clipBehavior: Clip.none, children: [
            CircleAvatar(radius: 26, backgroundColor: Colors.red[800],
                child: Icon(Icons.groups, color: Colors.white, size: 28)),
            if (groupUnread > 0) Positioned(right: -4, top: -4,
                child: Container(
                    padding: EdgeInsets.all(4),
                    constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                    decoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                    child: Text(groupUnread > 99 ? '99+' : '$groupUnread',
                        style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center))),
          ]),
          title: Text('Hostel Group Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text('All students in ${AppData.selectedHostelName}', style: TextStyle(fontSize: 12, color: Colors.grey)),
          trailing: groupUnread > 0
              ? Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)),
              child: Text('$groupUnread new', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)))
              : Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: _openGroupChat,
        ),
      ),

      SizedBox(height: 20),
      Row(children: [
        Icon(Icons.lock_person_outlined, size: 16, color: Colors.red[800]), SizedBox(width: 6),
        Text('Private Messages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
      SizedBox(height: 4),
      Text('Tap a student from Students tab to start a private chat, or reply here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
      SizedBox(height: 12),

      // ── Private chats stream ─────────────────────────────────
      StreamBuilder<QuerySnapshot>(
          stream: FirebaseService.getPrivateChatsStream(AppData.currentUserEmail),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting)
              return Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: Colors.red)));
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty)
              return Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                  child: Column(children: [
                    Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey[300]),
                    SizedBox(height: 8),
                    Text('No private messages yet.', style: TextStyle(color: Colors.grey)),
                    Text('Students can message you from the chat screen.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]));
            return Column(children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final participants = List<String>.from(data['participants'] ?? []);
              final otherEmail = participants.firstWhere((e) => e != AppData.currentUserEmail, orElse: () => '');
              final otherName  = (data['participantNames']?[otherEmail] ?? otherEmail).toString().replaceAll(' (Warden)', '');
              final lastMsg    = data['lastMessage'] ?? 'No messages yet';
              final lastTime   = data['lastMessageTime'] ?? '';
              final myKey      = AppData.currentUserEmail.replaceAll('.', '_').replaceAll('@', '_');
              final unread     = ((data['unreadCount_$myKey'] ?? 0) as num).toInt();
              return Card(
                margin: EdgeInsets.only(bottom: 8),
                color: unread > 0 ? Colors.red[50] : null,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: unread > 0 ? Colors.red[200]! : Colors.transparent, width: 1.5)),
                child: ListTile(
                  leading: Stack(clipBehavior: Clip.none, children: [
                    CircleAvatar(backgroundColor: Color(0xFF5C4D57),
                        child: Text(otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    if (unread > 0) Positioned(right: -4, top: -4,
                        child: Container(
                            padding: EdgeInsets.all(3),
                            constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                            decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                            child: Text('$unread', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
                  ]),
                  title: Text(otherName, style: TextStyle(fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal, color: unread > 0 ? Colors.black87 : Colors.grey)),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(lastTime.length > 5 ? lastTime.substring(0, 5) : lastTime, style: TextStyle(fontSize: 10, color: Colors.grey)),
                    if (unread > 0) ...[
                      SizedBox(height: 4),
                      Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                          child: Text('$unread new', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                    ],
                  ]),
                  onTap: () => _openPrivateChat(doc.id, otherEmail, otherName),
                ),
              );
            }).toList());
          }),
    ]);
  }
}

// ── Group Chat Screen ─────────────────────────────────────────────
class GroupChatScreen extends StatefulWidget {
  @override _GroupChatScreenState createState() => _GroupChatScreenState();
}
class _GroupChatScreenState extends State<GroupChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final bool _isWarden = AppData.currentUserIsAdmin;

  @override
  void initState() {
    super.initState();
    // Mark group chat as seen the moment user opens it
    AppData.markGroupChatSeen();
  }

  @override
  void dispose() {
    // Also mark seen on close in case messages arrived while inside
    AppData.markGroupChatSeen();
    super.dispose();
  }

  void _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    await FirebaseService.sendGroupMessage(
      text: text,
      senderName: AppData.currentUserName,
      senderEmail: AppData.currentUserEmail,
      hostelId: AppData.currentUserHostelId.isNotEmpty ? AppData.currentUserHostelId : AppData.selectedHostelId,
      isWarden: _isWarden,
    );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scroll.hasClients && _scroll.position.hasContentDimensions) { _scroll.jumpTo(_scroll.position.maxScrollExtent); }
    });
  }

  void _deleteMessage(String docId) async {
    final hostelId = AppData.currentUserHostelId.isNotEmpty ? AppData.currentUserHostelId : AppData.selectedHostelId;
    await FirebaseService.deleteGroupMessageById(hostelId, docId);
  }

  @override
  Widget build(BuildContext context) {
    final hostelId = AppData.currentUserHostelId.isNotEmpty ? AppData.currentUserHostelId : AppData.selectedHostelId;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hostel Group Chat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(AppData.selectedHostelName, style: TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white,
        actions: [Icon(Icons.groups, color: Colors.white70), SizedBox(width: 16)],
      ),
      body: Column(children: [
        // Info banner
        Container(color: Color(0xFF5C4D57).withOpacity(0.06), padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Icon(Icons.info_outline, size: 14, color: Colors.grey),
              SizedBox(width: 6),
              Expanded(child: Text('All hostel residents and warden can see these messages.', style: TextStyle(fontSize: 11, color: Colors.grey))),
            ])),

        // Messages
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseService.getGroupMessagesStream(hostelId),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting)
              return Center(child: CircularProgressIndicator(color: Color(0xFF5C4D57)));
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty)
              return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[300]),
                SizedBox(height: 8),
                Text('No messages yet. Say hello! 👋', style: TextStyle(color: Colors.grey)),
              ]));
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
            return ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                final isMe     = data['senderEmail'] == AppData.currentUserEmail;
                final isWardenMsg = data['isWarden'] == true;
                final canDelete  = _isWarden || isMe;
                return _ChatBubble(
                  docId: docs[i].id,
                  text: data['text'] ?? '',
                  senderName: data['senderName'] ?? '',
                  time: data['time'] ?? '',
                  isMe: isMe,
                  isWarden: isWardenMsg,
                  canDelete: canDelete,
                  onDelete: () => _deleteMessage(docs[i].id),
                );
              },
            );
          },
        )),

        // Input bar
        _ChatInputBar(controller: _ctrl, onSend: _send),
      ]),
    );
  }
}

// ── New Private Chat Screen ───────────────────────────────────────
class NewPrivateChatScreen extends StatefulWidget {
  @override _NewPrivateChatScreenState createState() => _NewPrivateChatScreenState();
}
class _NewPrivateChatScreenState extends State<NewPrivateChatScreen> {
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadStudents(); }

  void _loadStudents() async {
    final hostelId = AppData.currentUserHostelId.isNotEmpty ? AppData.currentUserHostelId : AppData.selectedHostelId;
    final all = await FirebaseService.getStudents(hostelId);
    // Also add warden
    final wardens = await FirebaseService.getAllWardens();
    final hostelWardens = wardens.where((w) => w['hostelId'] == hostelId).toList();
    final list = [...all, ...hostelWardens.map((w) => {'name': '${w["name"]} (Warden)', 'email': w['email'], 'uid': w['uid'] ?? w['docId']})];
    if (mounted) setState(() {
      _students = list.where((s) => s['email'] != AppData.currentUserEmail).toList();
      _loading = false;
    });
  }

  void _startChat(Map<String, dynamic> student) async {
    final chatId = await FirebaseService.getOrCreatePrivateChat(
      myEmail:    AppData.currentUserEmail,
      myName:     AppData.currentUserName,
      otherEmail: student['email'],
      otherName:  student['name'],
    );
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => PrivateChatScreen(chatId: chatId, otherEmail: student['email'], otherName: student['name'])));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New Message'), backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF5C4D57)))
          : _students.isEmpty
          ? Center(child: Text('No other students found.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: _students.length,
          itemBuilder: (ctx, i) {
            final s = _students[i];
            return Card(
              margin: EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Color(0xFF5C4D57),
                    child: Text((s['name'] ?? '?')[0].toUpperCase(), style: TextStyle(color: Colors.white))),
                title: Text(s['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(s['email'] ?? '', style: TextStyle(fontSize: 12)),
                onTap: () => _startChat(s),
              ),
            );
          }),
    );
  }
}

// ── Private Chat Screen ───────────────────────────────────────────
class PrivateChatScreen extends StatefulWidget {
  final String chatId, otherEmail, otherName;
  PrivateChatScreen({required this.chatId, required this.otherEmail, required this.otherName});
  @override _PrivateChatScreenState createState() => _PrivateChatScreenState();
}
class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final bool _isWarden = AppData.currentUserIsAdmin;

  void _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    await FirebaseService.sendPrivateMessage(
      chatId: widget.chatId,
      text: text,
      senderName: AppData.currentUserName,
      senderEmail: AppData.currentUserEmail,
      otherEmail: widget.otherEmail,
      isWardenSender: AppData.currentUserIsAdmin,
    );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scroll.hasClients && _scroll.position.hasContentDimensions) { _scroll.jumpTo(_scroll.position.maxScrollExtent); }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: Colors.white24,
              child: Text(widget.otherName.isNotEmpty ? widget.otherName[0].toUpperCase() : '?',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          SizedBox(width: 10),
          Text(widget.otherName, style: TextStyle(fontSize: 16)),
        ]),
        backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white,
      ),
      body: Column(children: [
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseService.getPrivateMessagesStream(widget.chatId),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting)
              return Center(child: CircularProgressIndicator(color: Color(0xFF5C4D57)));
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty)
              return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_outline, size: 48, color: Colors.grey[300]),
                SizedBox(height: 8),
                Text('Private conversation', style: TextStyle(color: Colors.grey)),
                Text('Only you and ${widget.otherName} can see this.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ]));
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
            return ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                final isMe = data['senderEmail'] == AppData.currentUserEmail;
                final canDelete = _isWarden || isMe;
                return _ChatBubble(
                  docId: docs[i].id,
                  text: data['text'] ?? '',
                  senderName: data['senderName'] ?? '',
                  time: data['time'] ?? '',
                  isMe: isMe,
                  isWarden: data['isWarden'] == true,
                  canDelete: canDelete,
                  onDelete: () async => await FirebaseService.deletePrivateMessage(widget.chatId, docs[i].id),
                );
              },
            );
          },
        )),
        _ChatInputBar(controller: _ctrl, onSend: _send),
      ]),
    );
  }
}

// ── Chat Bubble Widget ────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final String docId, text, senderName, time;
  final bool isMe, isWarden, canDelete;
  final VoidCallback onDelete;
  const _ChatBubble({required this.docId, required this.text, required this.senderName, required this.time, required this.isMe, required this.isWarden, required this.canDelete, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: canDelete ? () => showDialog(context: context, builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Message?'),
        content: Text('This message will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(onPressed: () { Navigator.pop(context); onDelete(); },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: Text('Delete')),
        ],
      )) : null,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(bottom: 8, left: isMe ? 60 : 0, right: isMe ? 0 : 60),
          child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
            if (!isMe) Padding(padding: EdgeInsets.only(left: 12, bottom: 2), child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(senderName, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
              if (isWarden) ...[SizedBox(width: 4), Container(padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: Color(0xFF5C4D57), borderRadius: BorderRadius.circular(8)), child: Text('Warden', style: TextStyle(color: Colors.white, fontSize: 9)))],
            ])),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Color(0xFF5C4D57) : (isWarden ? Color(0xFF9E6B70).withOpacity(0.15) : Colors.grey[100]),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18), topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: isWarden && !isMe ? Border.all(color: Color(0xFF9E6B70).withOpacity(0.3)) : null,
              ),
              child: Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14)),
            ),
            Padding(padding: EdgeInsets.only(top: 2, left: 12, right: 12),
                child: Text(time, style: TextStyle(fontSize: 10, color: Colors.grey))),
          ]),
        ),
      ),
    );
  }
}

// ── Chat Input Bar ────────────────────────────────────────────────
class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _ChatInputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))]),
      child: Row(children: [
        Expanded(child: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          maxLines: null,
          maxLength: 2000,
          decoration: InputDecoration(
            hintText: 'Type a message...',
            filled: true, fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            counterText: '', // hide the character counter UI (rule still enforced)
          ),
          onSubmitted: (_) => onSend(),
        )),
        SizedBox(width: 8),
        GestureDetector(
          onTap: onSend,
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: Color(0xFF5C4D57), shape: BoxShape.circle),
            child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// NOTIFICATIONS SCREEN
// ═══════════════════════════════════════════════════════════════════
class NotificationsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notifications'), backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white,
          actions: [TextButton(onPressed: () { AppData.notifications.clear(); Navigator.pop(context); }, child: Text('Clear All', style: TextStyle(color: Colors.white)))]),
      body: AppData.notifications.isEmpty
          ? Center(child: Text('No notifications', style: TextStyle(color: Colors.grey)))
          : ListView.builder(padding: EdgeInsets.all(16), itemCount: AppData.notifications.length,
          itemBuilder: (ctx, i) {
            final n = AppData.notifications[AppData.notifications.length - 1 - i];
            return Card(margin: EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(leading: CircleAvatar(backgroundColor: Color(0xFF5C4D57).withOpacity(0.1), child: Icon(Icons.notifications_outlined, color: Color(0xFF5C4D57))),
                    title: Text(n['message'] ?? ''), subtitle: Text(n['time'] ?? '', style: TextStyle(color: Colors.grey))));
          }),
    );
  }
}

class EditProfileScreen extends StatefulWidget { @override _EditProfileScreenState createState() => _EditProfileScreenState(); }
class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController nc, rc;
  late String _emoji;
  late int    _color;

  @override
  void initState() {
    super.initState();
    nc     = TextEditingController(text: AppData.currentUserName);
    rc     = TextEditingController(text: AppData.currentUserRoom);
    _emoji = AppData.currentUserEmoji;
    _color = AppData.currentUserAvatarColor;
  }

  void _save() async {
    if (nc.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Name cannot be empty.'), backgroundColor: Colors.red));
      return;
    }
    AppData.currentUserName        = nc.text.trim();
    AppData.currentUserRoom        = rc.text.trim();
    AppData.currentUserEmoji       = _emoji;
    AppData.currentUserAvatarColor = _color;
    // Save to Firebase if logged in as student
    if (AppData.currentUserUid.isNotEmpty) {
      await FirebaseService.updateProfile(
        uid:         AppData.currentUserUid,
        name:        nc.text.trim(),
        room:        rc.text.trim(),
        emoji:       _emoji,
        avatarColor: _color.toString(),
      );
    }
    // Persist updated session so changes survive app restart
    await SessionManager.save(role: AppData.currentUserIsSuperAdmin ? 'superadmin' : AppData.currentUserIsAdmin ? 'warden' : 'student');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Profile updated!'), backgroundColor: Colors.green));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text('Edit Profile'), backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white,
          actions: [TextButton(onPressed: _save, child: Text('Save', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))]),
      body: SingleChildScrollView(padding: EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Live preview ──────────────────────────────────────────
        Center(child: UserAvatar(radius: 60, name: nc.text, emoji: _emoji, color: _color)),
        SizedBox(height: 8),
        Center(child: TextButton.icon(
          onPressed: () { setState(() => _emoji = ''); },
          icon: Icon(Icons.refresh, size: 16),
          label: Text('Reset to initials', style: TextStyle(fontSize: 12)),
        )),
        SizedBox(height: 20),

        // ── Name & Room ───────────────────────────────────────────
        TextField(controller: nc, onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        SizedBox(height: 14),
        TextField(controller: rc,
            decoration: InputDecoration(labelText: 'Room & Block', prefixIcon: Icon(Icons.door_back_door_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        SizedBox(height: 28),

        // ── Pick Emoji ────────────────────────────────────────────
        Text('Choose your avatar emoji', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        SizedBox(height: 4),
        Text('Tap any emoji to use it as your profile picture', style: TextStyle(color: Colors.grey, fontSize: 12)),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
          child: GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: AppData.avatarEmojis.map((e) {
              final selected = _emoji == e;
              return GestureDetector(
                onTap: () => setState(() => _emoji = e),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? Color(_color).withOpacity(0.15) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selected ? Color(_color) : Colors.grey[200]!, width: selected ? 2 : 1),
                  ),
                  child: Center(child: Text(e, style: TextStyle(fontSize: 22))),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 28),

        // ── Pick Background Color ─────────────────────────────────
        Text('Choose background color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        SizedBox(height: 4),
        Text('This shows when using initials or as the ring color', style: TextStyle(color: Colors.grey, fontSize: 12)),
        SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: AppData.avatarColors.map((c) {
          final selected = _color == c;
          return GestureDetector(
            onTap: () => setState(() => _color = c),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 3),
                boxShadow: selected ? [BoxShadow(color: Color(c).withOpacity(0.6), blurRadius: 8, spreadRadius: 2)] : [],
              ),
              child: selected ? Icon(Icons.check, color: Colors.white, size: 20) : null,
            ),
          );
        }).toList()),
        SizedBox(height: 32),

        // ── Save Button ───────────────────────────────────────────
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF5C4D57), foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text('Save Changes', style: TextStyle(fontSize: 18)),
        )),
        SizedBox(height: 20),
      ])),
    );
  }
}