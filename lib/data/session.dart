// Who is signed in, and what they're allowed to do.
//
// Owner and Battle Baseball admin are set in roles/{uid} and reach every
// event. Event admins and staff are named one event at a time in
// staffAssignments/{eventId}_{uid}. Firestore's rules enforce all of it;
// the app only uses it to show the right screens.
import 'dart:async';

import 'package:battle_baseball/data/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class Session extends ChangeNotifier {
  Session._() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuth);
  }

  static final Session instance = Session._();

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Json>>? _roleSub;
  StreamSubscription<QuerySnapshot<Json>>? _staffSub;
  StreamSubscription<DocumentSnapshot<Json>>? _userSub;

  User? user;
  bool ready = false;

  /// owner, admin, or null.
  String? role;
  String name = '';
  List<StaffAssignment> assignments = const [];

  bool get signedIn => user != null;
  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'owner' || role == 'admin';
  bool get hasStaffTools => isAdmin || assignments.isNotEmpty;

  bool isEventAdmin(String eventId) =>
      isAdmin || assignments.any((a) => a.eventId == eventId && a.role == 'eventAdmin');
  bool isEventStaff(String eventId) =>
      isAdmin || assignments.any((a) => a.eventId == eventId);

  String get displayName =>
      name.isNotEmpty ? name : (user?.displayName ?? user?.email ?? 'Parent');

  void _onAuth(User? u) {
    user = u;
    _roleSub?.cancel();
    _staffSub?.cancel();
    _userSub?.cancel();
    role = null;
    assignments = const [];
    name = '';
    if (u == null) {
      ready = true;
      notifyListeners();
      return;
    }
    final db = FirebaseFirestore.instance;
    _roleSub = db.doc('roles/${u.uid}').snapshots().listen((d) {
      role = d.data()?['role'] as String?;
      ready = true;
      notifyListeners();
    }, onError: (_) {
      ready = true;
      notifyListeners();
    });
    _staffSub = db
        .collection('staffAssignments')
        .where('uid', isEqualTo: u.uid)
        .snapshots()
        .listen((s) {
      assignments = s.docs.map(StaffAssignment.fromDoc).toList();
      notifyListeners();
    }, onError: (_) {});
    _userSub = db.doc('users/${u.uid}').snapshots().listen((d) {
      name = d.data()?['name'] as String? ?? '';
      notifyListeners();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _roleSub?.cancel();
    _staffSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}
