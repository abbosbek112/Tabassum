import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@JS('window.Telegram')
external JSObject? get _telegram;

@JS('window.Telegram.WebApp')
external WebApp? get _webApp;

/// Extension types for strong typing
extension type WebApp(JSObject _) implements JSObject {
  external void ready();
  external void expand();
  external void setHeaderColor(String color);
  
  @JS('colorScheme')
  external String get colorScheme;
  
  @JS('MainButton')
  external MainButton get mainButton;
  
  @JS('BackButton')
  external BackButton get backButton;
  
  @JS('HapticFeedback')
  external TWAHapticFeedback get hapticFeedback;

  @JS('initData')
  external String get initData;

  @JS('initDataUnsafe')
  external WebAppInitData get initDataUnsafe;

  external void onEvent(String eventName, JSFunction callback);
  external void requestContact(JSFunction callback);
}

extension type WebAppInitData(JSObject _) implements JSObject {
  @JS('user')
  external WebAppUser? get user;
  
  @JS('start_param')
  external String? get startParam;
}

extension type WebAppUser(JSObject _) implements JSObject {
  @JS('id')
  external int get id;
  
  @JS('first_name')
  external String get firstName;
  
  @JS('last_name')
  external String? get lastName;
  
  @JS('username')
  external String? get username;
}

extension type MainButton(JSObject _) implements JSObject {
  external void setText(String text);
  external void show();
  external void hide();
  external void enable();
  external void disable();
  external void onClick(JSFunction callback);
}

extension type BackButton(JSObject _) implements JSObject {
  external void show();
  external void hide();
  external void onClick(JSFunction callback);
}

extension type TWAHapticFeedback(JSObject _) implements JSObject {
  external void impactOccurred(String style);
}

extension type ContactResponse(JSObject _) implements JSObject {
  @JS('status')
  external String get status;
  
  @JS('contact')
  external Contact? get contact;
}

extension type Contact(JSObject _) implements JSObject {
  @JS('phone_number')
  external String get phoneNumber;
  
  @JS('first_name')
  external String get firstName;
  
  @JS('last_name')
  external String? get lastName;
  
  @JS('user_id')
  external int? get userId;
}

final twaServiceProvider = ChangeNotifierProvider((ref) => TWAService());

class TWAService extends ChangeNotifier {
  TWAService() {
    _initThemeListener();
  }

  void _initThemeListener() {
    if (!isSupported) return;
    try {
      final webApp = _webApp;
      if (webApp == null) return;
      
      webApp.onEvent('themeChanged', (() {
        notifyListeners();
      }).toJS);
    } catch (e) {
      debugPrint('TWA Theme Listener Error: $e');
    }
  }

  bool get isSupported => _telegram != null && _webApp != null;

  String? get startParam {
    try {
      return _webApp?.initDataUnsafe.startParam;
    } catch (_) {
      return null;
    }
  }

  String? get initData {
    try {
      if (!isSupported) return null;
      return _webApp?.initData;
    } catch (_) {
      return null;
    }
  }

  void expand() {
    try {
      _webApp?.expand();
    } catch (e) {
      debugPrint('TWA Expand Error: $e');
    }
  }

  void ready() {
    try {
      _webApp?.ready();
    } catch (e) {
      debugPrint('TWA Ready Error: $e');
    }
  }

  void setHeaderColor(Color color) {
    if (!isSupported) return;
    try {
      final hex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
      _webApp?.setHeaderColor(hex);
    } catch (e) {
      debugPrint('TWA SetHeaderColor Error: $e');
    }
  }

  void setMainButton({
    required String text,
    required VoidCallback onTap,
    bool isVisible = true,
    bool isActive = true,
  }) {
    if (!isSupported) return;
    try {
      final btn = _webApp?.mainButton;
      if (btn == null) return;
      
      btn.setText(text);
      btn.onClick(onTap.toJS);
      
      if (isVisible) {
        btn.show();
      } else {
        btn.hide();
      }
      if (isActive) {
        btn.enable();
      } else {
        btn.disable();
      }
    } catch (e) {
      debugPrint('TWA SetMainButton Error: $e');
    }
  }

  void hideMainButton() {
    try {
      _webApp?.mainButton.hide();
    } catch (_) {}
  }

  void showBackButton(VoidCallback onTap) {
    if (!isSupported) return;
    try {
      final btn = _webApp?.backButton;
      if (btn == null) return;
      
      btn.show();
      btn.onClick(onTap.toJS);
    } catch (e) {
      debugPrint('TWA ShowBackButton Error: $e');
    }
  }

  void hideBackButton() {
    try {
      _webApp?.backButton.hide();
    } catch (_) {}
  }

  void hapticImpact(String style) {
    if (!isSupported) return;
    try {
      _webApp?.hapticFeedback.impactOccurred(style);
    } catch (e) {
      debugPrint('TWA Haptic Error: $e');
    }
  }

  bool get isDarkMode {
    try {
      if (!isSupported) return false;
      return _webApp?.colorScheme == 'dark';
    } catch (_) {
      return false;
    }
  }

  int? get telegramUserId {
    try {
      if (!isSupported) return null;
      return _webApp?.initDataUnsafe.user?.id;
    } catch (e) {
      debugPrint('TWA Get TelegramUserId Error: $e');
      return null;
    }
  }

  WebAppUser? get telegramUser {
    try {
      if (!isSupported) return null;
      return _webApp?.initDataUnsafe.user;
    } catch (e) {
      debugPrint('TWA Get TelegramUser Error: $e');
      return null;
    }
  }

  void requestPhone(void Function(String? phoneNumber) onResult) {
    if (!isSupported) {
      onResult(null);
      return;
    }
    try {
      _webApp?.requestContact(((JSObject result) {
        try {
          final resp = result as ContactResponse;
          if (resp.status == 'sent' && resp.contact != null) {
            onResult(resp.contact!.phoneNumber);
          } else {
            onResult(null);
          }
        } catch (e) {
          debugPrint('TWA Contact Callback Parse Error: $e');
          onResult(null);
        }
      }).toJS);
    } catch (e) {
      debugPrint('TWA RequestPhone Error: $e');
      onResult(null);
    }
  }
}
