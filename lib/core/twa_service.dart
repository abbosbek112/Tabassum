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
  external HapticFeedback get hapticFeedback;

  external void onEvent(String eventName, JSFunction callback);
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

extension type HapticFeedback(JSObject _) implements JSObject {
  external void impactOccurred(String style);
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
}
