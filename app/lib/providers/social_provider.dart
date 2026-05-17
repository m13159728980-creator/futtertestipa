import 'dart:async';

import 'package:app/core/services/websocket_service.dart';
import 'package:app/core/services/api_service.dart';
import 'package:app/models/group.dart';
import 'package:app/models/user.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final socialProvider = ChangeNotifierProvider<SocialProvider>((ref) {
  return SocialProvider(
    apiService: ref.watch(apiServiceProvider),
    auth: ref.watch(authProvider),
    webSocketService: ref.watch(webSocketServiceProvider),
  )..load();
});

class SocialProvider extends ChangeNotifier {
  SocialProvider({
    required ApiService apiService,
    required AuthProvider auth,
    required WebSocketService webSocketService,
  }) : _apiService = apiService,
       _auth = auth {
    _socketSubscription = webSocketService.events.listen(_handleEvent);
  }

  final ApiService _apiService;
  final AuthProvider _auth;
  StreamSubscription<WebSocketEvent>? _socketSubscription;

  final List<User> _contacts = [];
  final List<Group> _groups = [];
  final Set<String> _onlineUserIds = {};
  bool _isLoading = false;
  String? _errorMessage;
  Future<void>? _refreshFuture;

  List<User> get contacts => List.unmodifiable(_contacts);
  List<Group> get groups => List.unmodifiable(_groups);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool isOnline(String userId) {
    return _onlineUserIds.contains(userId);
  }

  String? get _token {
    final token = _auth.user?.token;
    return token == null || token.isEmpty ? null : token;
  }

  Future<void> load() async {
    final token = _token;
    if (token == null) {
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _contacts
        ..clear()
        ..addAll(await _apiService.listContacts(token: token));
      _groups
        ..clear()
        ..addAll(await _apiService.listGroups(token: token));
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<User> addContact(String account) async {
    final token = _requireToken();
    final contact = await _apiService.addContact(
      token: token,
      account: account.trim(),
    );
    final index = _contacts.indexWhere((item) => item.id == contact.id);
    if (index >= 0) {
      _contacts[index] = contact;
    } else {
      _contacts.add(contact);
    }
    notifyListeners();
    return contact;
  }

  Future<Group> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    final token = _requireToken();
    final group = await _apiService.createGroup(
      token: token,
      name: name,
      memberIds: memberIds,
    );
    rememberGroup(group);
    return group;
  }

  Future<Group> renameGroup({
    required String groupId,
    required String name,
  }) async {
    final token = _requireToken();
    final group = await _apiService.renameGroup(
      token: token,
      groupId: groupId,
      name: name,
    );
    rememberGroup(group);
    return group;
  }

  Future<Group> addGroupMembers({
    required String groupId,
    required List<String> memberIds,
  }) async {
    final token = _requireToken();
    final group = await _apiService.addGroupMembers(
      token: token,
      groupId: groupId,
      memberIds: memberIds,
    );
    rememberGroup(group);
    return group;
  }

  void rememberGroup(Group group) {
    final index = _groups.indexWhere((item) => item.id == group.id);
    if (index >= 0) {
      _groups[index] = group;
    } else {
      _groups.add(group);
    }
    notifyListeners();
  }

  void _handleEvent(WebSocketEvent event) {
    switch (event.type) {
      case 'user.updated':
        _handleUserUpdated(event.payload);
      case 'presence.snapshot':
        _handlePresenceSnapshot(event.payload);
      case 'presence.updated':
        _handlePresenceUpdated(event.payload);
      case 'group.updated':
        _handleGroupUpdated(event.payload);
      case 'contact.updated':
        _refreshListsSoon();
      case 'message.send':
      case 'message.created':
      case 'message.received':
        _refreshListsSoon();
    }
  }

  void _handleUserUpdated(Map<String, dynamic> payload) {
    final source = payload['user'];
    if (source is! Map) {
      return;
    }
    final updated = User.fromJson(Map<String, dynamic>.from(source));
    final index = _contacts.indexWhere((contact) => contact.id == updated.id);
    if (index == -1) {
      return;
    }
    _contacts[index] = updated;
    notifyListeners();
  }

  void _handlePresenceSnapshot(Map<String, dynamic> payload) {
    final ids = payload['onlineUserIds'];
    if (ids is! List) {
      return;
    }
    _onlineUserIds
      ..clear()
      ..addAll(ids.map((id) => id.toString()));
    notifyListeners();
  }

  void _handlePresenceUpdated(Map<String, dynamic> payload) {
    final userId = payload['userId']?.toString();
    if (userId == null || userId.isEmpty) {
      return;
    }
    if (payload['isOnline'] == true) {
      _onlineUserIds.add(userId);
    } else {
      _onlineUserIds.remove(userId);
    }
    notifyListeners();
  }

  void _handleGroupUpdated(Map<String, dynamic> payload) {
    final source = payload['group'];
    if (source is! Map) {
      _refreshListsSoon();
      return;
    }
    rememberGroup(Group.fromJson(Map<String, dynamic>.from(source)));
  }

  void _refreshListsSoon() {
    _refreshFuture ??= Future<void>.delayed(Duration.zero, () async {
      _refreshFuture = null;
      await load();
    });
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }

  String _requireToken() {
    final token = _token;
    if (token == null) {
      throw const ApiException('请先登录');
    }
    return token;
  }
}
