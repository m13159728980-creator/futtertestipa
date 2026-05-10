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
  )..load();
});

class SocialProvider extends ChangeNotifier {
  SocialProvider({required ApiService apiService, required AuthProvider auth})
    : _apiService = apiService,
      _auth = auth;

  final ApiService _apiService;
  final AuthProvider _auth;

  final List<User> _contacts = [];
  final List<Group> _groups = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<User> get contacts => List.unmodifiable(_contacts);
  List<Group> get groups => List.unmodifiable(_groups);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  String _requireToken() {
    final token = _token;
    if (token == null) {
      throw const ApiException('请先登录');
    }
    return token;
  }
}
