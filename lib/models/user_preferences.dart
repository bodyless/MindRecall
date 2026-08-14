import 'package:flutter/material.dart';

/// 应用正文字号档位：相对当前主题字号缩放。
enum AppFontSize {
  small,
  medium,
  large;

  double get scale => switch (this) {
        AppFontSize.small => 0.75,
        AppFontSize.medium => 1.0,
        AppFontSize.large => 1.25,
      };

  static AppFontSize fromStorage(String? value) {
    return switch (value) {
      'small' => AppFontSize.small,
      'large' => AppFontSize.large,
      _ => AppFontSize.medium,
    };
  }

  String get storageValue => switch (this) {
        AppFontSize.small => 'small',
        AppFontSize.medium => 'medium',
        AppFontSize.large => 'large',
      };
}

class UserPreferences {
  const UserPreferences({
    required this.themeMode,
    required this.localeCode,
    this.lastOpenedMemoId,
    this.fontSize = AppFontSize.medium,
    this.debugToolsEnabled = false,
    this.debugShowFps = true,
    this.debugShowImeHud = true,
    this.debugShowCursorHud = true,
  });

  final ThemeMode themeMode;
  final String localeCode;
  final String? lastOpenedMemoId;
  final AppFontSize fontSize;

  /// 仅 Debug 构建下有意义：调试总开关；关闭时隐藏子项叠层。
  final bool debugToolsEnabled;

  /// 总开关开启时是否显示 FPS 徽标（缺省 true，兼容旧偏好）。
  final bool debugShowFps;

  /// 总开关开启时是否显示 IME HUD（缺省 true，兼容旧偏好）。
  final bool debugShowImeHud;

  /// 总开关开启时是否显示光标状态 HUD（缺省 true，兼容旧偏好）。
  final bool debugShowCursorHud;

  factory UserPreferences.defaults() {
    return const UserPreferences(
      themeMode: ThemeMode.light,
      localeCode: 'zh',
    );
  }

  Locale get locale => Locale(localeCode);

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      themeMode: _themeModeFromString(json['themeMode'] as String?),
      localeCode: json['localeCode'] as String? ?? 'zh',
      lastOpenedMemoId: json['lastOpenedMemoId'] as String?,
      fontSize: AppFontSize.fromStorage(json['fontSize'] as String?),
      debugToolsEnabled: json['debugToolsEnabled'] as bool? ?? false,
      debugShowFps: json['debugShowFps'] as bool? ?? true,
      debugShowImeHud: json['debugShowImeHud'] as bool? ?? true,
      debugShowCursorHud: json['debugShowCursorHud'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': _themeModeToString(themeMode),
      'localeCode': localeCode,
      'fontSize': fontSize.storageValue,
      'debugToolsEnabled': debugToolsEnabled,
      'debugShowFps': debugShowFps,
      'debugShowImeHud': debugShowImeHud,
      'debugShowCursorHud': debugShowCursorHud,
      if (lastOpenedMemoId != null) 'lastOpenedMemoId': lastOpenedMemoId,
    };
  }

  UserPreferences copyWith({
    ThemeMode? themeMode,
    String? localeCode,
    String? lastOpenedMemoId,
    AppFontSize? fontSize,
    bool? debugToolsEnabled,
    bool? debugShowFps,
    bool? debugShowImeHud,
    bool? debugShowCursorHud,
    bool clearLastOpenedMemoId = false,
  }) {
    return UserPreferences(
      themeMode: themeMode ?? this.themeMode,
      localeCode: localeCode ?? this.localeCode,
      fontSize: fontSize ?? this.fontSize,
      debugToolsEnabled: debugToolsEnabled ?? this.debugToolsEnabled,
      debugShowFps: debugShowFps ?? this.debugShowFps,
      debugShowImeHud: debugShowImeHud ?? this.debugShowImeHud,
      debugShowCursorHud: debugShowCursorHud ?? this.debugShowCursorHud,
      lastOpenedMemoId: clearLastOpenedMemoId
          ? null
          : (lastOpenedMemoId ?? this.lastOpenedMemoId),
    );
  }

  static ThemeMode _themeModeFromString(String? value) {
    return switch (value) {
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }

  static String _themeModeToString(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light || ThemeMode.system => 'light',
    };
  }
}
