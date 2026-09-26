// Copyright 2026 BenderBlog Rodriguez and Contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyUid = 'ruisi_uid';
  static const _keyUsername = 'ruisi_username';
  static const _keyFormhash = 'ruisi_formhash';
  static const _keyPassword = 'ruisi_password';
  static const _keySearchHistory = 'ruisi_search_history';
  static const _maxSearchHistory = 10;

  final SharedPreferencesWithCache _prefs;

  int? _uid;
  String? _username;
  String? _formhash;
  String? _password;

  int? get uid => _uid;
  String? get username => _username;
  String? get formhash => _formhash;
  String? get password => _password;
  bool get isLogin => _uid != null;

  List<String> get searchHistory {
    final encoded = _prefs.getString(_keySearchHistory);
    if (encoded == null || encoded.isEmpty) return const [];

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const [];

      final seen = <String>{};
      final history = <String>[];
      for (final item in decoded) {
        if (item is! String) continue;
        final keyword = item.trim();
        if (keyword.isEmpty || !seen.add(keyword)) continue;
        history.add(keyword);
      }
      return List.unmodifiable(history);
    } on FormatException {
      return const [];
    }
  }

  SettingsService(this._prefs) {
    _uid = _prefs.getInt(_keyUid);
    _username = _prefs.getString(_keyUsername);
    _formhash = _prefs.getString(_keyFormhash);
    _password = _prefs.getString(_keyPassword);
  }

  Future<void> saveLogin({
    required int uid,
    required String username,
    required String formhash,
    String? password,
  }) async {
    _uid = uid;
    _username = username;
    _formhash = formhash;
    _password = password;
    await _prefs.setInt(_keyUid, uid);
    await _prefs.setString(_keyUsername, username);
    await _prefs.setString(_keyFormhash, formhash);
    if (password != null) {
      await _prefs.setString(_keyPassword, password);
    }
    await _prefs.reloadCache();
  }

  Future<void> logout() async {
    _uid = null;
    _username = null;
    _formhash = null;
    _password = null;
    await _prefs.remove(_keyUid);
    await _prefs.remove(_keyUsername);
    await _prefs.remove(_keyFormhash);
    await _prefs.remove(_keyPassword);
    await _prefs.reloadCache();
  }

  Future<void> updateFormhash(String formhash) async {
    _formhash = formhash;
    await _prefs.setString(_keyFormhash, formhash);
    await _prefs.reloadCache();
  }

  Future<List<String>> addSearchHistory(String keyword) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) return searchHistory;

    final history = <String>[
      normalized,
      ...searchHistory.where((item) => item != normalized),
    ];
    if (history.length > _maxSearchHistory) {
      history.removeRange(_maxSearchHistory, history.length);
    }

    await _prefs.setString(_keySearchHistory, jsonEncode(history));
    await _prefs.reloadCache();
    return List.unmodifiable(history);
  }

  Future<void> clearSearchHistory() async {
    await _prefs.remove(_keySearchHistory);
    await _prefs.reloadCache();
  }
}
