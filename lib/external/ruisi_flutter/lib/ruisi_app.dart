// Copyright 2026 BenderBlog Rodriguez and Contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'package:material_ui/material_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:watermeter/generated/translations.g.dart';

import 'controller/ruisi_controller.dart';
import 'services/api_service.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'widgets/captcha_dialog.dart';

class RuisiApp extends StatefulWidget {
  final SharedPreferencesWithCache prefs;
  final String cookiePath;
  final Talker talker;
  const RuisiApp({
    super.key,
    required this.prefs,
    required this.cookiePath,
    required this.talker,
  });

  @override
  State<RuisiApp> createState() => _RuisiAppState();
}

class _RuisiAppState extends State<RuisiApp>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// 会话检查状态：null=未登录, true=有效, false=失效
  bool? _sessionValid;
  bool _checking = false;
  bool _networkUnavailable = false;

  RuisiService get _c => GetIt.instance<RuisiService>();

  @override
  void initState() {
    super.initState();
    GetIt.instance.registerSingleton<RuisiService>(
      RuisiService(
        prefs: widget.prefs,
        cookiePath: widget.cookiePath,
        talker: widget.talker,
      ),
    );

    // 监听登录状态变化，驱动页面切换
    _c.isLoggedInNotifier.addListener(_onLoginChanged);

    if (_c.isLoggedIn) {
      _checking = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
    }
  }

  @override
  void dispose() {
    _c.isLoggedInNotifier.removeListener(_onLoginChanged);
    super.dispose();
  }

  void _onLoginChanged() {
    if (!mounted) return;
    setState(() {
      if (_c.isLoggedIn) {
        _checking = true;
        _sessionValid = null;
        _networkUnavailable = false;
      } else {
        _checking = false;
        _sessionValid = null;
        _networkUnavailable = false;
      }
    });

    if (_c.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
    }
  }

  /// 会话有效性检测 + 三层续登。
  Future<void> _checkSession() async {
    final validation = await _c.api.validateSessionState();
    if (!mounted) return;

    if (validation == SessionValidationResult.valid) {
      setState(() {
        _sessionValid = true;
        _checking = false;
        _networkUnavailable = false;
      });
      return;
    }

    // 请求失败时无法区分会话失效和断网/非校园网，保留登录态并让用户重试。
    if (validation == SessionValidationResult.unavailable) {
      setState(() {
        _sessionValid = null;
        _checking = false;
        _networkUnavailable = true;
      });
      return;
    }

    // 会话失效，尝试刷新
    final result = await _c.refreshSession();
    if (!mounted) return;

    switch (result) {
      case SessionRefreshResult.success:
        setState(() {
          _sessionValid = true;
          _checking = false;
          _networkUnavailable = false;
        });
      case SessionRefreshResult.needCaptcha:
        // 弹出验证码弹窗
        final dialogOk = await CaptchaDialog.show(context);
        if (!mounted) return;
        setState(() {
          _sessionValid = dialogOk;
          _checking = false;
          _networkUnavailable = false;
        });
      case SessionRefreshResult.failed:
        setState(() {
          _sessionValid = false;
          _checking = false;
          _networkUnavailable = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_c.isLoggedIn) return const LoginPage();
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_networkUnavailable) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 48),
                const SizedBox(height: 16),
                Text(
                  context.t.common.notSchoolNetwork,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  context.t.common.networkError,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () {
                    setState(() {
                      _checking = true;
                      _sessionValid = null;
                      _networkUnavailable = false;
                    });
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _checkSession(),
                    );
                  },
                  child: Text(context.t.ruisi.common.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _sessionValid == true ? const HomePage() : const LoginPage();
  }
}
