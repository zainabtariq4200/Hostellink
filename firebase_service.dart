import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static final _db   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ═══════════════════════════════════════════════════════════════════
  // PASSWORD HASHING
  // ═══════════════════════════════════════════════════════════════════
  static String _generateSalt() {
    final rng   = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String _hashPassword(String password, String salt) {
    final key  = utf8.encode(password + salt);
    final hash = sha256.convert(key);
    return hash.toString();
  }

  static String hashNewPassword(String password) {
    final salt = _generateSalt();
    return '$salt:${_hashPassword(password, salt)}';
  }

  static bool verifyPassword(String plaintext, String stored) {
    if (stored.contains(':')) {
      final parts = stored.split(':');
      if (parts.length != 2) return false;
      return _hashPassword(plaintext, parts[0]) == parts[1];
    }
    return plaintext == stored;
  }

  // ═══════════════════════════════════════════════════════════════════
  // COLLECTION REFS
  // ═══════════════════════════════════════════════════════════════════
  static CollectionReference get _users    => _db.collection('users');
  static CollectionReference get _wardens  => _db.collection('wardens');
  static CollectionReference get _regReqs  => _db.collection('registrationRequests');
  static CollectionReference get _listings => _db.collection('listings');
  static CollectionReference get _requests => _db.collection('borrowRequests');
  static CollectionReference get _lendings => _db.collection('lendings');
  static CollectionReference get _superAdmins => _db.collection('superAdmins');

  // ═══════════════════════════════════════════════════════════════════
  // SUPER ADMIN LOGIN
  // Credentials live in Firestore superAdmins collection — never in code.
  // Rules are set to allow read, write: if false so only pre-seeded
  // documents can exist. Password stored as salt:sha256 hash.
  // Returns: null = not found | 'WRONG_PASSWORD' | data map on success
  // ═══════════════════════════════════════════════════════════════════
  static Future<dynamic> loginSuperAdmin({
    required String email,
    required String password,
  }) async {
    try {
      final snap = await _superAdmins
          .where('email', isEqualTo: email.trim().toLowerCase())
          .get();
      if (snap.docs.isEmpty) return null;
      final data   = snap.docs.first.data() as Map<String, dynamic>;
      final stored = data['password']?.toString() ?? '';
      if (!verifyPassword(password, stored)) return 'WRONG_PASSWORD';
      return data;
    } catch (_) {
      return null;
    }
  }

  // ── One-time seed ────────────────────────────────────────────────
  // Call this ONCE from a temporary button or script to create the
  // super admin document, then remove the call permanently.
  // Example: FirebaseService.seedSuperAdmin(
  //            email: 'superadmin@hostellink.pk',
  //            password: 'YourStrongPassword123!')
  static Future<void> seedSuperAdmin({
    required String email,
    required String password,
  }) async {
    await _superAdmins.doc('main').set({
      'email':     email.trim().toLowerCase(),
      'password':  hashNewPassword(password),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // SIGN OUT
  // ═══════════════════════════════════════════════════════════════════
  static Future<void> signOut() async {
    try { await _auth.signOut(); } catch (_) {}
  }

  /// Sends a Firebase Auth password reset email.
  /// Throws FirebaseAuthException if the email has no Auth account.
  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  // ═══════════════════════════════════════════════════════════════════
  // STUDENTS — login
  //
  // Strategy:
  //   1. Check Firestore for the student's profile (has email + hostelId).
  //   2. Verify their password against the stored hash.
  //   3. If Firebase Auth account doesn't exist yet, create it now
  //      (first-time login after warden approval).
  //   4. Sign in with Firebase Auth so Firestore rules see request.auth.
  // ═══════════════════════════════════════════════════════════════════
  static Future<dynamic> loginStudent(
      String email, String password, String hostelId) async {
    try {
      final lowerEmail = email.trim().toLowerCase();

      // 1. Find student in Firestore
      final snap = await _users
          .where('email', isEqualTo: lowerEmail)
          .get();
      final docs = snap.docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['hostelId'] == hostelId;
      }).toList();

      if (docs.isEmpty) return null;

      final data   = docs.first.data() as Map<String, dynamic>;
      final stored = data['password']?.toString() ?? '';

      // 2. Verify password against hash
      if (!verifyPassword(password, stored)) return 'WRONG_PASSWORD';

      // 3 & 4. Sign into Firebase Auth.
      // Detect if uid is old custom format (not a real Firebase Auth UID).
      // Real Firebase Auth UIDs are 28 chars, our custom ones contain underscores.
      final storedUid = data['uid']?.toString() ?? '';
      final needsAuthAccount = storedUid.contains('_') || storedUid.isEmpty;

      if (needsAuthAccount) {
        // No real Firebase Auth account yet — create one now.
        try {
          await _auth.createUserWithEmailAndPassword(
            email: lowerEmail, password: password,
          );
          final newUid = _auth.currentUser?.uid;
          if (newUid != null) {
            await docs.first.reference.update({'uid': newUid});
          }
        } on FirebaseAuthException catch (ce) {
          if (ce.code == 'email-already-in-use') {
            // Auth account exists — just sign in
            try {
              await _auth.signInWithEmailAndPassword(
                email: lowerEmail, password: password,
              );
              final newUid = _auth.currentUser?.uid;
              if (newUid != null && newUid != storedUid) {
                await docs.first.reference.update({'uid': newUid});
              }
            } catch (_) {}
          }
        } catch (_) {}
      } else {
        // Real Firebase Auth UID exists — sign in normally.
        try {
          await _auth.signInWithEmailAndPassword(
            email: lowerEmail, password: password,
          );
        } on FirebaseAuthException catch (authErr) {
          if (authErr.code == 'wrong-password') return 'WRONG_PASSWORD';
          // Other errors: allow login since Firestore hash matched.
        }
      }

      return data;
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateProfile({
    required String uid,
    required String name,
    required String room,
    required String emoji,
    required String avatarColor,
  }) async {
    try {
      await _users.doc(uid).update({
        'name': name, 'room': room,
        'emoji': emoji, 'avatarColor': avatarColor,
      });
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  // WARDENS — custom Firestore auth (no Firebase Auth)
  // ═══════════════════════════════════════════════════════════════════
  static Future<String?> createWarden({
    required String name,
    required String email,
    required String hostelId,
    required String tempPassword,
  }) async {
    try {
      final lowerEmail = email.trim().toLowerCase();
      final snap = await _wardens.where('email', isEqualTo: lowerEmail).get();
      final exists = snap.docs.any((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['hostelId'] == hostelId;
      });
      if (exists) return 'Warden already exists for this hostel.';

      final uid = '${hostelId}_warden_${lowerEmail.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      await _wardens.doc(uid).set({
        'uid': uid, 'name': name.trim(), 'email': lowerEmail,
        'password': hashNewPassword(tempPassword), 'hostelId': hostelId,
        'isTemp': true, 'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'Error: $e';
    }
  }

  static Future<dynamic> loginWarden(
      String email, String password, String hostelId) async {
    try {
      final snap = await _wardens
          .where('email', isEqualTo: email.trim().toLowerCase())
          .get();

      final docs = snap.docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['hostelId'] == hostelId;
      }).toList();

      if (docs.isEmpty) return null;

      final data   = docs.first.data() as Map<String, dynamic>;
      if (data['active'] == false) return null;

      final stored = data['password']?.toString() ?? '';
      if (!verifyPassword(password, stored)) return 'WRONG_PASSWORD';

      if (!stored.contains(':')) {
        await docs.first.reference.update({'password': hashNewPassword(password)});
      }

      return data;
    } catch (_) {
      return null;
    }
  }

  static Future<void> wardenChangePassword({
    required String email,
    required String hostelId,
    required String newPassword,
    String name = '',
  }) async {
    try {
      final lowerEmail = email.trim().toLowerCase();
      final hashedPw   = hashNewPassword(newPassword);
      final snap = await _wardens.where('email', isEqualTo: lowerEmail).get();

      final docs = snap.docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['hostelId'] == hostelId;
      }).toList();

      if (docs.isNotEmpty) {
        await docs.first.reference.update({'password': hashedPw, 'isTemp': false});
      } else {
        final uid = '${hostelId}_warden_${lowerEmail.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
        await _wardens.doc(uid).set({
          'uid': uid, 'name': name.isNotEmpty ? name : lowerEmail,
          'email': lowerEmail, 'password': hashedPw,
          'hostelId': hostelId, 'isTemp': false, 'active': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  // REGISTRATION REQUESTS
  // ═══════════════════════════════════════════════════════════════════

  /// Student submits request — password is stored as a hash.
  /// Warden approval creates the Firestore user doc.
  /// Firebase Auth account is created automatically on the student's first login.
  static Future<String?> submitRegRequest({
    required String name,
    required String email,
    required String password,
    required String room,
    required String hostelId,
  }) async {
    try {
      final lowerEmail = email.trim().toLowerCase();

      final snap = await _regReqs.where('email', isEqualTo: lowerEmail).get();
      final existing = snap.docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['hostelId'] == hostelId;
      }).toList();

      if (existing.isNotEmpty) {
        final status = (existing.first.data() as Map<String, dynamic>)['status'];
        if (status == 'pending')  return 'You already submitted a request.\nPlease wait for warden approval.';
        if (status == 'approved') return 'Your request was approved.\nPlease login with your account.';
        if (status == 'rejected') {
          final r = (existing.first.data() as Map<String, dynamic>)['rejectionReason'] ?? '';
          return 'Your request was rejected.${r.isNotEmpty ? "\nReason: $r" : ""}\n\nContact your warden.';
        }
      }

      final userSnap   = await _users.where('email', isEqualTo: lowerEmail).get();
      final userExists = userSnap.docs.any((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['hostelId'] == hostelId;
      });
      if (userExists) return 'This email is already registered. Please login.';

      await _regReqs.add({
        'name':            name.trim(),
        'email':           lowerEmail,
        'password':        hashNewPassword(password), // hash stored, not plaintext
        'room':            room.trim(),
        'hostelId':        hostelId,
        'status':          'pending',
        'submittedAt':     _now(),
        'reviewedAt':      '',
        'rejectionReason': '',
      });
      return null;
    } catch (e) {
      return 'Error: $e';
    }
  }

  static Stream<QuerySnapshot> getRegRequestsStream(String hostelId) =>
      _regReqs.where('hostelId', isEqualTo: hostelId).snapshots();

  static Future<Map<String, dynamic>?> checkRequestStatus(
      String email, String hostelId) async {
    try {
      final snap = await _regReqs
          .where('email', isEqualTo: email.trim().toLowerCase())
          .get();
      final docs = snap.docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['hostelId'] == hostelId;
      }).toList();
      if (docs.isEmpty) return null;
      return {'id': docs.first.id, ...docs.first.data() as Map<String, dynamic>};
    } catch (_) { return null; }
  }

  /// Warden approves a request.
  /// Only creates the Firestore user doc — NO Firebase Auth call here.
  /// The student's Firebase Auth account is created on their first login.
  static Future<String?> approveRequest(
      Map<String, dynamic> req, String docId) async {
    try {
      final email    = req['email']?.toString().trim().toLowerCase() ?? '';
      final name     = req['name']?.toString().trim() ?? '';
      final password = req['password']?.toString() ?? ''; // already hashed
      final room     = req['room']?.toString().trim() ?? '';
      final hostelId = req['hostelId']?.toString() ?? '';

      if (email.isEmpty || hostelId.isEmpty) return 'Missing required fields.';

      // Check if student already exists
      final snap    = await _users.where('email', isEqualTo: email).get();
      final already = snap.docs.any((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['hostelId'] == hostelId;
      });

      if (!already) {
        // Create Firestore profile only — no Firebase Auth here
        final uid = '${hostelId}_${email.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
        await _users.doc(uid).set({
          'uid':         uid,
          'name':        name,
          'email':       email,
          'password':    password, // hashed — used on first login to verify
          'room':        room,
          'hostelId':    hostelId,
          'emoji':       '',
          'avatarColor': '0xFF6C3483',
          'createdAt':   FieldValue.serverTimestamp(),
        });
      }

      await _regReqs.doc(docId).update({
        'status':     'approved',
        'reviewedAt': _now(),
      });
      return null;
    } catch (e) {
      return 'Error: $e';
    }
  }

  static Future<void> rejectRequest(String docId, String reason) async {
    try {
      await _regReqs.doc(docId).update({
        'status':          'rejected',
        'reviewedAt':      _now(),
        'rejectionReason': reason.trim().isEmpty ? 'No reason provided.' : reason.trim(),
      });
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  // BORROW REQUESTS
  // ═══════════════════════════════════════════════════════════════════
  static Stream<QuerySnapshot> getBorrowRequestsStream(String hostelId) =>
      _requests.where('hostelId', isEqualTo: hostelId).snapshots();

  static Stream<QuerySnapshot> getMyBorrowRequestsStream(
      String email, String hostelId) =>
      _requests.where('posterEmail', isEqualTo: email).snapshots();

  static Future<void> addBorrowRequest(Map<String, dynamic> data) async {
    try { await _requests.add({...data, 'createdAt': FieldValue.serverTimestamp()}); } catch (_) {}
  }

  static Future<void> updateBorrowRequestStatus(String docId, String status,
      {String? lenderName, String? lenderRoom}) async {
    try {
      final data = <String, dynamic>{'status': status};
      if (lenderName != null) data['lenderName'] = lenderName;
      if (lenderRoom  != null) data['lenderRoom']  = lenderRoom;
      await _requests.doc(docId).update(data);
    } catch (_) {}
  }

  static Future<void> deleteBorrowRequest(String docId) async {
    try { await _requests.doc(docId).delete(); } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  // LENDINGS
  // ═══════════════════════════════════════════════════════════════════
  static Stream<QuerySnapshot> getMyLendingsStream(String email, String hostelId) =>
      _lendings.where('lenderEmail', isEqualTo: email).snapshots();

  static Stream<QuerySnapshot> getHostelLendingsStream(String hostelId) =>
      _lendings.where('hostelId', isEqualTo: hostelId).snapshots();

  static Future<void> addLending(Map<String, dynamic> data) async {
    try { await _lendings.add({...data, 'createdAt': FieldValue.serverTimestamp()}); } catch (_) {}
  }

  static Future<void> markLendingReturned(String docId) async {
    try { await _lendings.doc(docId).update({'lendStatus': 'Returned'}); } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  // MARKETPLACE
  // ═══════════════════════════════════════════════════════════════════
  static Stream<QuerySnapshot> getListingsStream(String hostelId) =>
      _listings.where('hostelId', isEqualTo: hostelId).snapshots();

  static Future<void> addListing(Map<String, dynamic> data) async {
    try { await _listings.add({...data, 'createdAt': FieldValue.serverTimestamp()}); } catch (_) {}
  }

  static Future<void> markListingSold(String docId) async {
    try { await _listings.doc(docId).update({'status': 'sold'}); } catch (_) {}
  }

  static Future<void> deleteListing(String docId) async {
    try { await _listings.doc(docId).delete(); } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  // STUDENTS LIST
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getStudents(String hostelId) async {
    try {
      final snap = await _users.where('hostelId', isEqualTo: hostelId).get();
      return snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
    } catch (_) { return []; }
  }

  static Future<List<Map<String, dynamic>>> getAllStudents() async {
    try {
      final snap = await _users.get();
      return snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
    } catch (_) { return []; }
  }

  static Future<void> deleteStudent(String uid) async {
    try { await _users.doc(uid).delete(); } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  // SAMPLE DATA SEED
  // ═══════════════════════════════════════════════════════════════════
  static Future<void> seedSampleData(String hostelId) async {
    if (hostelId.isEmpty) return;
    try {
      final check = await _db.collection('seeded').doc(hostelId).get();
      if (check.exists) return;

      final batch = _db.batch();
      final borrowData = [
        {'item': 'Phone Charger (Type-C)', 'person': 'Ayesha', 'room': 'Room 12', 'duration': '2 hours', 'category': 'Electronics',  'notes': 'Need urgently for exam',  'status': 'open', 'posterEmail': 'ayesha@sample.com', 'hostelId': hostelId},
        {'item': 'Hair Dryer',             'person': 'Sana',   'room': 'Room 7',  'duration': '1 hour',  'category': 'Personal Care', 'notes': '',                        'status': 'open', 'posterEmail': 'sana@sample.com',   'hostelId': hostelId},
        {'item': 'Scientific Calculator',  'person': 'Fatima', 'room': 'Room 3',  'duration': '3 hours', 'category': 'Electronics',  'notes': 'For math exam tomorrow',  'status': 'open', 'posterEmail': 'fatima@sample.com', 'hostelId': hostelId},
        {'item': 'Biology Textbook',       'person': 'Zara',   'room': 'Room 15', 'duration': '2 days',  'category': 'Books',         'notes': 'Chapter 5-8 needed',      'status': 'open', 'posterEmail': 'zara@sample.com',   'hostelId': hostelId},
        {'item': 'Extension Cord',         'person': 'Hina',   'room': 'Room 9',  'duration': '1 day',   'category': 'Electronics',  'notes': '',                        'status': 'open', 'posterEmail': 'hina@sample.com',   'hostelId': hostelId},
        {'item': 'Iron',                   'person': 'Amna',   'room': 'Room 5',  'duration': '30 min',  'category': 'Personal Care', 'notes': 'Have event tonight',      'status': 'open', 'posterEmail': 'amna@sample.com',   'hostelId': hostelId},
      ];
      for (final r in borrowData) {
        batch.set(_requests.doc(), {...r, 'createdAt': FieldValue.serverTimestamp()});
      }

      final listingData = [
        {'title': 'Biology Textbook (2nd Year)',   'price': '500',  'condition': 'Good', 'category': 'Books',         'description': 'Slightly used, all pages intact.',                  'emoji': '📚', 'sellerName': 'Ayesha', 'sellerRoom': 'Room 12', 'sellerEmail': 'ayesha@sample.com', 'hostelId': hostelId, 'status': 'available', 'postedAt': '10/3/2025'},
        {'title': 'Hair Straightener (Philips)',   'price': '1200', 'condition': 'Good', 'category': 'Personal Care', 'description': 'Philips brand, works perfectly.',                   'emoji': '💇', 'sellerName': 'Sana',   'sellerRoom': 'Room 7',  'sellerEmail': 'sana@sample.com',   'hostelId': hostelId, 'status': 'available', 'postedAt': '9/3/2025'},
        {'title': 'Scientific Calculator (Casio)', 'price': '800',  'condition': 'New',  'category': 'Electronics',  'description': 'Bought last month, barely used.',                   'emoji': '🔢', 'sellerName': 'Fatima', 'sellerRoom': 'Room 3',  'sellerEmail': 'fatima@sample.com', 'hostelId': hostelId, 'status': 'available', 'postedAt': '8/3/2025'},
        {'title': 'Winter Shawl (Maroon)',         'price': '600',  'condition': 'Used', 'category': 'Clothing',     'description': 'Warm and cozy, worn only twice.',                   'emoji': '🧣', 'sellerName': 'Zara',   'sellerRoom': 'Room 15', 'sellerEmail': 'zara@sample.com',   'hostelId': hostelId, 'status': 'available', 'postedAt': '7/3/2025'},
        {'title': 'Desk Lamp (LED)',               'price': '450',  'condition': 'Good', 'category': 'Electronics',  'description': 'Perfect for late-night studying.',                  'emoji': '💡', 'sellerName': 'Hina',   'sellerRoom': 'Room 9',  'sellerEmail': 'hina@sample.com',   'hostelId': hostelId, 'status': 'available', 'postedAt': '6/3/2025'},
        {'title': 'Makeup Organizer',              'price': '350',  'condition': 'New',  'category': 'Personal Care', 'description': 'Never used, still in packaging.',                  'emoji': '💄', 'sellerName': 'Amna',   'sellerRoom': 'Room 5',  'sellerEmail': 'amna@sample.com',   'hostelId': hostelId, 'status': 'available', 'postedAt': '5/3/2025'},
      ];
      for (final l in listingData) {
        batch.set(_listings.doc(), {...l, 'createdAt': FieldValue.serverTimestamp()});
      }

      await batch.commit();
      await _db.collection('seeded').doc(hostelId).set({'seededAt': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  // HOSTEL REGISTRY
  // ═══════════════════════════════════════════════════════════════════
  static CollectionReference get _hostelsCol => _db.collection('hostelRegistry');

  static Future<String?> addHostelToFirestore({
    required String id, required String name,
    required String city, required String university,
  }) async {
    try {
      await _hostelsCol.doc(id).set({
        'id': id, 'name': name.trim(), 'city': city.trim(),
        'university': university.trim(), 'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) { return 'Error: $e'; }
  }

  static Future<List<Map<String, String>>> loadHostelsFromFirestore() async {
    try {
      final snap = await _hostelsCol.get();
      return snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {
          'id':         data['id']?.toString()         ?? d.id,
          'name':       data['name']?.toString()       ?? '',
          'city':       data['city']?.toString()       ?? '',
          'university': data['university']?.toString() ?? '',
          'active':     (data['active'] == true)       ? 'yes' : 'no',
        };
      }).toList();
    } catch (_) { return []; }
  }

  static Future<void> setHostelActive(String id, bool active) async {
    try { await _hostelsCol.doc(id).update({'active': active}); } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  // WARDEN MANAGEMENT (Super Admin)
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getAllWardens() async {
    try {
      final snap = await _wardens.get();
      return snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {'docId': d.id, ...data};
      }).toList();
    } catch (_) { return []; }
  }

  static Future<void> setWardenActive(String uid, bool active) async {
    try { await _wardens.doc(uid).update({'active': active}); } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  // CHAT — Group + Private Messaging
  // ═══════════════════════════════════════════════════════════════════
  static CollectionReference _groupMessages(String hostelId) =>
      _db.collection('hostels').doc(hostelId).collection('groupMessages');

  static CollectionReference get _privateChats => _db.collection('privateChats');

  static Stream<QuerySnapshot> getGroupMessagesStream(String hostelId) =>
      _groupMessages(hostelId).orderBy('createdAt', descending: false).snapshots();

  static Future<void> sendGroupMessage({
    required String text, required String senderName,
    required String senderEmail, required String hostelId,
    bool isWarden = false,
  }) async {
    try {
      final now  = DateTime.now();
      final time = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
      await _groupMessages(hostelId).add({
        'text': text.trim(), 'senderName': senderName,
        'senderEmail': senderEmail, 'isWarden': isWarden,
        'time': time, 'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Future<void> deleteGroupMessageById(String hostelId, String docId) async {
    try { await _groupMessages(hostelId).doc(docId).delete(); } catch (_) {}
  }

  static Future<String> getOrCreatePrivateChat({
    required String myEmail, required String myName,
    required String otherEmail, required String otherName,
  }) async {
    try {
      final participants = [myEmail, otherEmail]..sort();
      final chatId = participants.join('_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final doc = await _privateChats.doc(chatId).get();
      if (!doc.exists) {
        await _privateChats.doc(chatId).set({
          'participants': participants,
          'participantNames': {myEmail: myName, otherEmail: otherName},
          'lastMessage': '', 'lastMessageTime': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return chatId;
    } catch (_) { return ''; }
  }

  static Stream<QuerySnapshot> getPrivateChatsStream(String email) =>
      _privateChats.where('participants', arrayContains: email).snapshots();

  static Stream<QuerySnapshot> getPrivateMessagesStream(String chatId) =>
      _privateChats.doc(chatId).collection('messages')
          .orderBy('createdAt', descending: false).snapshots();

  static Future<void> sendPrivateMessage({
    required String chatId, required String text,
    required String senderName, required String senderEmail,
    required String otherEmail, bool isWardenSender = false,
  }) async {
    try {
      final now  = DateTime.now();
      final time = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
      await _privateChats.doc(chatId).collection('messages').add({
        'text': text.trim(), 'senderName': senderName,
        'senderEmail': senderEmail, 'isWarden': isWardenSender,
        'time': time, 'createdAt': FieldValue.serverTimestamp(),
      });
      final otherKey = otherEmail.replaceAll('.', '_').replaceAll('@', '_');
      await _privateChats.doc(chatId).update({
        'lastMessage':           text.trim().length > 40 ? '${text.trim().substring(0, 40)}...' : text.trim(),
        'lastMessageTime':       time,
        'unreadCount_$otherKey': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  static Future<void> deletePrivateMessage(String chatId, String docId) async {
    try { await _privateChats.doc(chatId).collection('messages').doc(docId).delete(); } catch (_) {}
  }

  static Future<void> clearPrivateChatUnread({
    required String chatId, required String myKey,
  }) async {
    try { await _privateChats.doc(chatId).update({'unreadCount_$myKey': 0}); } catch (_) {}
  }

  static String _now() {
    final n = DateTime.now();
    return '${n.day}/${n.month}/${n.year} ${n.hour}:${n.minute.toString().padLeft(2, '0')}';
  }
}