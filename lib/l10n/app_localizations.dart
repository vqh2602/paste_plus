import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// No description provided for @aiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiTitle;

  /// No description provided for @app_name.
  ///
  /// In en, this message translates to:
  /// **'ClipFlow'**
  String get app_name;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'LIBRARY'**
  String get library;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @pinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// No description provided for @images.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get images;

  /// No description provided for @links.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get links;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// No description provided for @collections.
  ///
  /// In en, this message translates to:
  /// **'COLLECTIONS'**
  String get collections;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @local_data_only.
  ///
  /// In en, this message translates to:
  /// **'Data saved locally'**
  String get local_data_only;

  /// No description provided for @search_in_clipboard.
  ///
  /// In en, this message translates to:
  /// **'Search in clipboard'**
  String get search_in_clipboard;

  /// No description provided for @text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get text;

  /// No description provided for @url.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get url;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File Path'**
  String get file;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'HEX Color'**
  String get color;

  /// No description provided for @json.
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get json;

  /// No description provided for @jwt.
  ///
  /// In en, this message translates to:
  /// **'JWT'**
  String get jwt;

  /// No description provided for @image.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// No description provided for @emoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get emoji;

  /// No description provided for @image_link.
  ///
  /// In en, this message translates to:
  /// **'Image Link'**
  String get image_link;

  /// No description provided for @collection_personal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get collection_personal;

  /// No description provided for @collection_link.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get collection_link;

  /// No description provided for @collection_reply.
  ///
  /// In en, this message translates to:
  /// **'Reply Templates'**
  String get collection_reply;

  /// No description provided for @just_now.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get just_now;

  /// No description provided for @mins_ago.
  ///
  /// In en, this message translates to:
  /// **'@m mins ago'**
  String get mins_ago;

  /// No description provided for @hours_ago.
  ///
  /// In en, this message translates to:
  /// **'@h hours ago'**
  String get hours_ago;

  /// No description provided for @days_ago.
  ///
  /// In en, this message translates to:
  /// **'@d days ago'**
  String get days_ago;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copy_again.
  ///
  /// In en, this message translates to:
  /// **'Copy again'**
  String get copy_again;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copied;

  /// No description provided for @pin_item.
  ///
  /// In en, this message translates to:
  /// **'Pin item'**
  String get pin_item;

  /// No description provided for @unpin_item.
  ///
  /// In en, this message translates to:
  /// **'Unpin item'**
  String get unpin_item;

  /// No description provided for @add_to_collection.
  ///
  /// In en, this message translates to:
  /// **'Add to Collection'**
  String get add_to_collection;

  /// No description provided for @add_note.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get add_note;

  /// No description provided for @edit_note.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get edit_note;

  /// No description provided for @edit_clipboard.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit_clipboard;

  /// No description provided for @clipboard_updated.
  ///
  /// In en, this message translates to:
  /// **'Clipboard updated'**
  String get clipboard_updated;

  /// No description provided for @clipboard_update_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to update this clipboard'**
  String get clipboard_update_failed;

  /// No description provided for @invalid_color_code.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid color code'**
  String get invalid_color_code;

  /// No description provided for @open_link.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open_link;

  /// No description provided for @paste_as_plain_text.
  ///
  /// In en, this message translates to:
  /// **'Paste as Plain Text'**
  String get paste_as_plain_text;

  /// No description provided for @share_clipboard.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share_clipboard;

  /// No description provided for @share_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to share this clipboard'**
  String get share_failed;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @no_note_yet.
  ///
  /// In en, this message translates to:
  /// **'No note yet...'**
  String get no_note_yet;

  /// No description provided for @type_note_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Type note (auto-saves)...'**
  String get type_note_placeholder;

  /// No description provided for @extract_ocr.
  ///
  /// In en, this message translates to:
  /// **'Extract Text (OCR)'**
  String get extract_ocr;

  /// No description provided for @translate_text.
  ///
  /// In en, this message translates to:
  /// **'Translate Text'**
  String get translate_text;

  /// No description provided for @upload_cloud.
  ///
  /// In en, this message translates to:
  /// **'Upload to Cloud'**
  String get upload_cloud;

  /// No description provided for @ask_ai.
  ///
  /// In en, this message translates to:
  /// **'Ask AI Assistant'**
  String get ask_ai;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @delete_item_title.
  ///
  /// In en, this message translates to:
  /// **'Delete item?'**
  String get delete_item_title;

  /// No description provided for @delete_item_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this clipboard item?'**
  String get delete_item_confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clipboard_empty.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is currently empty.'**
  String get clipboard_empty;

  /// No description provided for @copied_time.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied_time;

  /// No description provided for @source_app.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source_app;

  /// No description provided for @usage_count.
  ///
  /// In en, this message translates to:
  /// **'Usage count'**
  String get usage_count;

  /// No description provided for @characters.
  ///
  /// In en, this message translates to:
  /// **'characters'**
  String get characters;

  /// No description provided for @words.
  ///
  /// In en, this message translates to:
  /// **'words'**
  String get words;

  /// No description provided for @lines.
  ///
  /// In en, this message translates to:
  /// **'lines'**
  String get lines;

  /// No description provided for @ai_conversation_options.
  ///
  /// In en, this message translates to:
  /// **'Conversation Options'**
  String get ai_conversation_options;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @ai_conversation_history.
  ///
  /// In en, this message translates to:
  /// **'Conversation History'**
  String get ai_conversation_history;

  /// No description provided for @ai_choose_context.
  ///
  /// In en, this message translates to:
  /// **'Choose clipboard context'**
  String get ai_choose_context;

  /// No description provided for @ai_choose_context_title.
  ///
  /// In en, this message translates to:
  /// **'Choose clipboard context'**
  String get ai_choose_context_title;

  /// No description provided for @ai_no_context_items.
  ///
  /// In en, this message translates to:
  /// **'No clipboard items available'**
  String get ai_no_context_items;

  /// No description provided for @ai_history_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Up to 20 recent sessions, stored locally'**
  String get ai_history_subtitle;

  /// No description provided for @ai_new_conversation.
  ///
  /// In en, this message translates to:
  /// **'＋ New Conversation'**
  String get ai_new_conversation;

  /// No description provided for @ai_rename_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Rename Conversation'**
  String get ai_rename_dialog_title;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @ai_gen_settings_title.
  ///
  /// In en, this message translates to:
  /// **'Generation Settings'**
  String get ai_gen_settings_title;

  /// No description provided for @ai_gen_settings_sub.
  ///
  /// In en, this message translates to:
  /// **'Applies to subsequent AI responses'**
  String get ai_gen_settings_sub;

  /// No description provided for @main_window.
  ///
  /// In en, this message translates to:
  /// **'Main Window'**
  String get main_window;

  /// No description provided for @ai_config.
  ///
  /// In en, this message translates to:
  /// **'AI Configuration'**
  String get ai_config;

  /// No description provided for @ai_profile_precise.
  ///
  /// In en, this message translates to:
  /// **'Precise · 2K'**
  String get ai_profile_precise;

  /// No description provided for @ai_profile_balanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced · 4K'**
  String get ai_profile_balanced;

  /// No description provided for @ai_profile_creative.
  ///
  /// In en, this message translates to:
  /// **'Creative · 8K'**
  String get ai_profile_creative;

  /// No description provided for @ai_processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get ai_processing;

  /// No description provided for @ai_regenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get ai_regenerate;

  /// No description provided for @ai_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get ai_continue;

  /// No description provided for @ai_recent_conversation.
  ///
  /// In en, this message translates to:
  /// **'Recent Conversation'**
  String get ai_recent_conversation;

  /// No description provided for @ai_privacy_title.
  ///
  /// In en, this message translates to:
  /// **'100% Private & Offline'**
  String get ai_privacy_title;

  /// No description provided for @ai_cancel_download.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get ai_cancel_download;

  /// No description provided for @ai_size_label.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get ai_size_label;

  /// No description provided for @settings_title.
  ///
  /// In en, this message translates to:
  /// **'ClipFlow Settings'**
  String get settings_title;

  /// No description provided for @tab_general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get tab_general;

  /// No description provided for @tab_clipboard.
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get tab_clipboard;

  /// No description provided for @tab_privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get tab_privacy;

  /// No description provided for @tab_storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get tab_storage;

  /// No description provided for @tab_shortcuts.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get tab_shortcuts;

  /// No description provided for @tab_about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get tab_about;

  /// No description provided for @appearance_and_theme.
  ///
  /// In en, this message translates to:
  /// **'Appearance & Theme'**
  String get appearance_and_theme;

  /// No description provided for @theme_mode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get theme_mode;

  /// No description provided for @theme_system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get theme_system;

  /// No description provided for @theme_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get theme_light;

  /// No description provided for @theme_dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get theme_dark;

  /// No description provided for @app_language.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get app_language;

  /// No description provided for @translation_language.
  ///
  /// In en, this message translates to:
  /// **'Translation Language'**
  String get translation_language;

  /// No description provided for @translation_language_sub.
  ///
  /// In en, this message translates to:
  /// **'Default language when using Translate action'**
  String get translation_language_sub;

  /// No description provided for @system_permissions.
  ///
  /// In en, this message translates to:
  /// **'System Permissions'**
  String get system_permissions;

  /// No description provided for @accessibility_permission.
  ///
  /// In en, this message translates to:
  /// **'Accessibility Permission'**
  String get accessibility_permission;

  /// No description provided for @accessibility_granted.
  ///
  /// In en, this message translates to:
  /// **'Granted. ClipFlow automatically pastes when item is selected.'**
  String get accessibility_granted;

  /// No description provided for @accessibility_required.
  ///
  /// In en, this message translates to:
  /// **'Required for ClipFlow to automatically paste text into active apps.'**
  String get accessibility_required;

  /// No description provided for @granted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get granted;

  /// No description provided for @grant_permission.
  ///
  /// In en, this message translates to:
  /// **'Grant Permission'**
  String get grant_permission;

  /// No description provided for @restart_app.
  ///
  /// In en, this message translates to:
  /// **'Restart Application'**
  String get restart_app;

  /// No description provided for @restart_app_sub.
  ///
  /// In en, this message translates to:
  /// **'Restart ClipFlow to apply newly granted permissions.'**
  String get restart_app_sub;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @reset_permission.
  ///
  /// In en, this message translates to:
  /// **'Reset & Re-grant Permission'**
  String get reset_permission;

  /// No description provided for @reset_permission_sub.
  ///
  /// In en, this message translates to:
  /// **'Use if app update invalidates system Accessibility permission.'**
  String get reset_permission_sub;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @startup_options.
  ///
  /// In en, this message translates to:
  /// **'Startup & Behavior'**
  String get startup_options;

  /// No description provided for @launch_at_login.
  ///
  /// In en, this message translates to:
  /// **'Launch at Login'**
  String get launch_at_login;

  /// No description provided for @launch_at_login_sub.
  ///
  /// In en, this message translates to:
  /// **'Automatically launch ClipFlow when logging in to macOS.'**
  String get launch_at_login_sub;

  /// No description provided for @run_in_tray.
  ///
  /// In en, this message translates to:
  /// **'Run in Menu Bar'**
  String get run_in_tray;

  /// No description provided for @run_in_tray_sub.
  ///
  /// In en, this message translates to:
  /// **'Keep ClipFlow active in the macOS Menu Bar.'**
  String get run_in_tray_sub;

  /// No description provided for @show_in_dock.
  ///
  /// In en, this message translates to:
  /// **'Show in Dock'**
  String get show_in_dock;

  /// No description provided for @show_in_dock_sub.
  ///
  /// In en, this message translates to:
  /// **'Show ClipFlow app icon in macOS Dock.'**
  String get show_in_dock_sub;

  /// No description provided for @close_after_copy.
  ///
  /// In en, this message translates to:
  /// **'Auto-hide Quick Panel after copy'**
  String get close_after_copy;

  /// No description provided for @close_after_copy_sub.
  ///
  /// In en, this message translates to:
  /// **'Automatically hide panel and paste content into previous active app.'**
  String get close_after_copy_sub;

  /// No description provided for @sound_enabled.
  ///
  /// In en, this message translates to:
  /// **'Sound Effects'**
  String get sound_enabled;

  /// No description provided for @sound_enabled_sub.
  ///
  /// In en, this message translates to:
  /// **'Play subtle sound effect on copy or action.'**
  String get sound_enabled_sub;

  /// No description provided for @backup_restore_section.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore Settings'**
  String get backup_restore_section;

  /// No description provided for @export_config.
  ///
  /// In en, this message translates to:
  /// **'Export Personal Settings (.clipflow)'**
  String get export_config;

  /// No description provided for @export_config_sub.
  ///
  /// In en, this message translates to:
  /// **'Package all settings & theme into an encrypted .clipflow file.'**
  String get export_config_sub;

  /// No description provided for @export_button.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export_button;

  /// No description provided for @import_config.
  ///
  /// In en, this message translates to:
  /// **'Import Settings (.clipflow)'**
  String get import_config;

  /// No description provided for @import_config_sub.
  ///
  /// In en, this message translates to:
  /// **'Restore settings from an encrypted .clipflow backup file.'**
  String get import_config_sub;

  /// No description provided for @import_button.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import_button;

  /// No description provided for @export_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Export Personal Settings'**
  String get export_dialog_title;

  /// No description provided for @export_dialog_msg.
  ///
  /// In en, this message translates to:
  /// **'Enter a password to encrypt your .clipflow backup file:'**
  String get export_dialog_msg;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirm_password.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirm_password;

  /// No description provided for @password_empty.
  ///
  /// In en, this message translates to:
  /// **'Password cannot be empty.'**
  String get password_empty;

  /// No description provided for @password_mismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get password_mismatch;

  /// No description provided for @export_success.
  ///
  /// In en, this message translates to:
  /// **'Settings exported successfully!'**
  String get export_success;

  /// No description provided for @export_failed.
  ///
  /// In en, this message translates to:
  /// **'Export failed.'**
  String get export_failed;

  /// No description provided for @import_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Import Personal Settings'**
  String get import_dialog_title;

  /// No description provided for @import_dialog_msg.
  ///
  /// In en, this message translates to:
  /// **'Enter password to decrypt .clipflow file:'**
  String get import_dialog_msg;

  /// No description provided for @decrypt_password.
  ///
  /// In en, this message translates to:
  /// **'Decryption Password'**
  String get decrypt_password;

  /// No description provided for @import_success.
  ///
  /// In en, this message translates to:
  /// **'Settings imported and applied successfully!'**
  String get import_success;

  /// No description provided for @import_failed.
  ///
  /// In en, this message translates to:
  /// **'Import failed.'**
  String get import_failed;

  /// No description provided for @current_storage_usage.
  ///
  /// In en, this message translates to:
  /// **'Current Storage Usage'**
  String get current_storage_usage;

  /// No description provided for @clear_history.
  ///
  /// In en, this message translates to:
  /// **'Clear History…'**
  String get clear_history;

  /// No description provided for @clear_history_title.
  ///
  /// In en, this message translates to:
  /// **'Clear clipboard history?'**
  String get clear_history_title;

  /// No description provided for @clear_history_msg.
  ///
  /// In en, this message translates to:
  /// **'Pinned items will be preserved.'**
  String get clear_history_msg;

  /// No description provided for @app_description.
  ///
  /// In en, this message translates to:
  /// **'A private, local-first clipboard manager designed for macOS.'**
  String get app_description;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @github_source.
  ///
  /// In en, this message translates to:
  /// **'Source Code on GitHub'**
  String get github_source;

  /// No description provided for @check_updates.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get check_updates;

  /// No description provided for @quit_app.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get quit_app;

  /// No description provided for @visit.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get visit;

  /// No description provided for @check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// No description provided for @latest_version.
  ///
  /// In en, this message translates to:
  /// **'You are using the latest version'**
  String get latest_version;

  /// No description provided for @update_available.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get update_available;

  /// No description provided for @add_to_collection_title.
  ///
  /// In en, this message translates to:
  /// **'Add to collection'**
  String get add_to_collection_title;

  /// No description provided for @no_collections.
  ///
  /// In en, this message translates to:
  /// **'No collections available.'**
  String get no_collections;

  /// No description provided for @new_collection.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get new_collection;

  /// No description provided for @new_collection_btn.
  ///
  /// In en, this message translates to:
  /// **'+ New Collection'**
  String get new_collection_btn;

  /// No description provided for @rename_collection.
  ///
  /// In en, this message translates to:
  /// **'Rename collection'**
  String get rename_collection;

  /// No description provided for @delete_collection.
  ///
  /// In en, this message translates to:
  /// **'Delete collection'**
  String get delete_collection;

  /// No description provided for @collection_name_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Collection name'**
  String get collection_name_placeholder;

  /// No description provided for @this_device.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get this_device;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @ocr_success.
  ///
  /// In en, this message translates to:
  /// **'Text extracted & copy created'**
  String get ocr_success;

  /// No description provided for @ocr_empty.
  ///
  /// In en, this message translates to:
  /// **'No text found in image'**
  String get ocr_empty;

  /// No description provided for @translate_success.
  ///
  /// In en, this message translates to:
  /// **'Text translated & copy created'**
  String get translate_success;

  /// No description provided for @translate_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to translate text'**
  String get translate_failed;

  /// No description provided for @text_transform.
  ///
  /// In en, this message translates to:
  /// **'Text conversion'**
  String get text_transform;

  /// No description provided for @format_json.
  ///
  /// In en, this message translates to:
  /// **'Format JSON'**
  String get format_json;

  /// No description provided for @minify_json.
  ///
  /// In en, this message translates to:
  /// **'Minify JSON'**
  String get minify_json;

  /// No description provided for @encode_base64.
  ///
  /// In en, this message translates to:
  /// **'Encode Base64'**
  String get encode_base64;

  /// No description provided for @decode_base64.
  ///
  /// In en, this message translates to:
  /// **'Decode Base64'**
  String get decode_base64;

  /// No description provided for @encode_url.
  ///
  /// In en, this message translates to:
  /// **'Encode URL'**
  String get encode_url;

  /// No description provided for @decode_url.
  ///
  /// In en, this message translates to:
  /// **'Decode URL'**
  String get decode_url;

  /// No description provided for @uppercase.
  ///
  /// In en, this message translates to:
  /// **'UPPERCASE'**
  String get uppercase;

  /// No description provided for @lowercase.
  ///
  /// In en, this message translates to:
  /// **'lowercase'**
  String get lowercase;

  /// No description provided for @title_case.
  ///
  /// In en, this message translates to:
  /// **'Title Case'**
  String get title_case;

  /// No description provided for @parse_timestamp.
  ///
  /// In en, this message translates to:
  /// **'Parse timestamp'**
  String get parse_timestamp;

  /// No description provided for @md5_hash.
  ///
  /// In en, this message translates to:
  /// **'MD5 hash'**
  String get md5_hash;

  /// No description provided for @sort_lines.
  ///
  /// In en, this message translates to:
  /// **'Sort lines'**
  String get sort_lines;

  /// No description provided for @remove_duplicate_lines.
  ///
  /// In en, this message translates to:
  /// **'Remove duplicate lines'**
  String get remove_duplicate_lines;

  /// No description provided for @link_cleaner.
  ///
  /// In en, this message translates to:
  /// **'Link Cleaner'**
  String get link_cleaner;

  /// No description provided for @transformed_copied.
  ///
  /// In en, this message translates to:
  /// **'Converted result copied'**
  String get transformed_copied;

  /// No description provided for @transform_failed.
  ///
  /// In en, this message translates to:
  /// **'This conversion could not be completed'**
  String get transform_failed;

  /// No description provided for @link_cleaned.
  ///
  /// In en, this message translates to:
  /// **'Clean link copied'**
  String get link_cleaned;

  /// No description provided for @calculation_result.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get calculation_result;

  /// No description provided for @detected_language.
  ///
  /// In en, this message translates to:
  /// **'Detected'**
  String get detected_language;

  /// No description provided for @upload_cloud_success.
  ///
  /// In en, this message translates to:
  /// **'Uploaded to cloud & link copied'**
  String get upload_cloud_success;

  /// No description provided for @upload_cloud_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to upload image to cloud'**
  String get upload_cloud_failed;

  /// No description provided for @select_item_to_view.
  ///
  /// In en, this message translates to:
  /// **'Select an item to view details'**
  String get select_item_to_view;

  /// No description provided for @image_file_not_found.
  ///
  /// In en, this message translates to:
  /// **'Image file no longer exists'**
  String get image_file_not_found;

  /// No description provided for @cannot_display_image.
  ///
  /// In en, this message translates to:
  /// **'Unable to display image'**
  String get cannot_display_image;

  /// No description provided for @no_results_found.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get no_results_found;

  /// No description provided for @clipboard_empty_title.
  ///
  /// In en, this message translates to:
  /// **'Your clipboard is empty'**
  String get clipboard_empty_title;

  /// No description provided for @try_different_keyword.
  ///
  /// In en, this message translates to:
  /// **'Try different keywords or filters.'**
  String get try_different_keyword;

  /// No description provided for @clipboard_empty_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Copy something. ClipFlow will keep it safe on this device.'**
  String get clipboard_empty_subtitle;

  /// No description provided for @try_again.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get try_again;

  /// No description provided for @delete_cannot_undo.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get delete_cannot_undo;

  /// No description provided for @onboarding_title_1.
  ///
  /// In en, this message translates to:
  /// **'Everything you copy, right where you need it'**
  String get onboarding_title_1;

  /// No description provided for @onboarding_desc_1.
  ///
  /// In en, this message translates to:
  /// **'ClipFlow saves your clipboard history so you can find text, links, code, and more in seconds.'**
  String get onboarding_desc_1;

  /// No description provided for @onboarding_title_2.
  ///
  /// In en, this message translates to:
  /// **'Private by design'**
  String get onboarding_title_2;

  /// No description provided for @onboarding_desc_2.
  ///
  /// In en, this message translates to:
  /// **'Data stays on this device only. ClipFlow does not upload your clipboard content to any server.'**
  String get onboarding_desc_2;

  /// No description provided for @onboarding_title_3.
  ///
  /// In en, this message translates to:
  /// **'You are always in control'**
  String get onboarding_title_3;

  /// No description provided for @onboarding_desc_3.
  ///
  /// In en, this message translates to:
  /// **'Pause monitoring anytime, exclude sensitive apps, and clear data with one click.'**
  String get onboarding_desc_3;

  /// No description provided for @onboarding_title_4.
  ///
  /// In en, this message translates to:
  /// **'How long do you want to keep history?'**
  String get onboarding_title_4;

  /// No description provided for @onboarding_desc_4.
  ///
  /// In en, this message translates to:
  /// **'You can change this anytime in Settings.'**
  String get onboarding_desc_4;

  /// No description provided for @onboarding_title_5.
  ///
  /// In en, this message translates to:
  /// **'Ready to work faster'**
  String get onboarding_title_5;

  /// No description provided for @onboarding_desc_5.
  ///
  /// In en, this message translates to:
  /// **'Press Control + V on macOS or Control + Shift + V on Windows/Linux to open ClipFlow.'**
  String get onboarding_desc_5;

  /// No description provided for @unlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get unlimited;

  /// No description provided for @start_btn.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get start_btn;

  /// No description provided for @continue_btn.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continue_btn;

  /// No description provided for @cloud_hosting_section.
  ///
  /// In en, this message translates to:
  /// **'Cloud Image Hosting'**
  String get cloud_hosting_section;

  /// No description provided for @cloud_provider.
  ///
  /// In en, this message translates to:
  /// **'Cloud Provider'**
  String get cloud_provider;

  /// No description provided for @cloud_provider_sub.
  ///
  /// In en, this message translates to:
  /// **'Enable a single host option to upload images'**
  String get cloud_provider_sub;

  /// No description provided for @cloud_in_use.
  ///
  /// In en, this message translates to:
  /// **'FreeImage.host (Active)'**
  String get cloud_in_use;

  /// No description provided for @cloud_coming_soon.
  ///
  /// In en, this message translates to:
  /// **'Google Drive (Coming soon)'**
  String get cloud_coming_soon;

  /// No description provided for @cloud_provider_freeimage.
  ///
  /// In en, this message translates to:
  /// **'FreeImage.host'**
  String get cloud_provider_freeimage;

  /// No description provided for @cloud_provider_imgbb.
  ///
  /// In en, this message translates to:
  /// **'ImgBB'**
  String get cloud_provider_imgbb;

  /// No description provided for @freeimage_api_key.
  ///
  /// In en, this message translates to:
  /// **'FreeImage API Key'**
  String get freeimage_api_key;

  /// No description provided for @imgbb_api_key.
  ///
  /// In en, this message translates to:
  /// **'ImgBB API Key'**
  String get imgbb_api_key;

  /// No description provided for @api_key_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Enter API key...'**
  String get api_key_placeholder;

  /// No description provided for @accent_color.
  ///
  /// In en, this message translates to:
  /// **'Theme Accent Color'**
  String get accent_color;

  /// No description provided for @clipboard_monitoring.
  ///
  /// In en, this message translates to:
  /// **'Clipboard Monitoring'**
  String get clipboard_monitoring;

  /// No description provided for @monitoring_active.
  ///
  /// In en, this message translates to:
  /// **'ClipFlow is recording new clipboard entries.'**
  String get monitoring_active;

  /// No description provided for @monitoring_paused.
  ///
  /// In en, this message translates to:
  /// **'Clipboard history recording is paused.'**
  String get monitoring_paused;

  /// No description provided for @ignore_duplicates.
  ///
  /// In en, this message translates to:
  /// **'Ignore Duplicates'**
  String get ignore_duplicates;

  /// No description provided for @duplicate_behavior.
  ///
  /// In en, this message translates to:
  /// **'When item already exists'**
  String get duplicate_behavior;

  /// No description provided for @bring_to_top.
  ///
  /// In en, this message translates to:
  /// **'Bring to top'**
  String get bring_to_top;

  /// No description provided for @create_new.
  ///
  /// In en, this message translates to:
  /// **'Create new item'**
  String get create_new;

  /// No description provided for @keep_position.
  ///
  /// In en, this message translates to:
  /// **'Keep position'**
  String get keep_position;

  /// No description provided for @allowed_content_types.
  ///
  /// In en, this message translates to:
  /// **'Allowed Content Types'**
  String get allowed_content_types;

  /// No description provided for @content_limits.
  ///
  /// In en, this message translates to:
  /// **'Content Limits'**
  String get content_limits;

  /// No description provided for @min_length.
  ///
  /// In en, this message translates to:
  /// **'Minimum length'**
  String get min_length;

  /// No description provided for @max_length.
  ///
  /// In en, this message translates to:
  /// **'Maximum length'**
  String get max_length;

  /// No description provided for @max_image_size.
  ///
  /// In en, this message translates to:
  /// **'Maximum image size'**
  String get max_image_size;

  /// No description provided for @chars_unit.
  ///
  /// In en, this message translates to:
  /// **'characters'**
  String get chars_unit;

  /// No description provided for @ignore_sensitive.
  ///
  /// In en, this message translates to:
  /// **'Ignore Sensitive Content'**
  String get ignore_sensitive;

  /// No description provided for @ignore_otp.
  ///
  /// In en, this message translates to:
  /// **'Ignore OTP Codes'**
  String get ignore_otp;

  /// No description provided for @ignore_otp_sub.
  ///
  /// In en, this message translates to:
  /// **'Numeric strings of 4-8 digits.'**
  String get ignore_otp_sub;

  /// No description provided for @ignore_long_tokens.
  ///
  /// In en, this message translates to:
  /// **'Ignore Long Tokens'**
  String get ignore_long_tokens;

  /// No description provided for @excluded_apps.
  ///
  /// In en, this message translates to:
  /// **'Excluded Applications'**
  String get excluded_apps;

  /// No description provided for @add_app.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add_app;

  /// No description provided for @no_excluded_apps.
  ///
  /// In en, this message translates to:
  /// **'No applications excluded yet.'**
  String get no_excluded_apps;

  /// No description provided for @add_excluded_app_title.
  ///
  /// In en, this message translates to:
  /// **'Add Excluded Application'**
  String get add_excluded_app_title;

  /// No description provided for @add_excluded_app_msg.
  ///
  /// In en, this message translates to:
  /// **'Copied content from excluded apps will not be saved to history.'**
  String get add_excluded_app_msg;

  /// No description provided for @select_running_app.
  ///
  /// In en, this message translates to:
  /// **'Select from running applications'**
  String get select_running_app;

  /// No description provided for @select_app_finder.
  ///
  /// In en, this message translates to:
  /// **'Select application (.app) from Finder'**
  String get select_app_finder;

  /// No description provided for @enter_app_manual.
  ///
  /// In en, this message translates to:
  /// **'Enter application name manually'**
  String get enter_app_manual;

  /// No description provided for @enter_app_name.
  ///
  /// In en, this message translates to:
  /// **'Enter application name'**
  String get enter_app_name;

  /// No description provided for @app_name_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Example: Safari, Xcode'**
  String get app_name_placeholder;

  /// No description provided for @running_apps_title.
  ///
  /// In en, this message translates to:
  /// **'Running Applications'**
  String get running_apps_title;

  /// No description provided for @history_retention.
  ///
  /// In en, this message translates to:
  /// **'History Retention'**
  String get history_retention;

  /// No description provided for @max_storage.
  ///
  /// In en, this message translates to:
  /// **'Maximum Storage Size'**
  String get max_storage;

  /// No description provided for @delete_images_first.
  ///
  /// In en, this message translates to:
  /// **'Delete images first when cleaning up'**
  String get delete_images_first;

  /// No description provided for @data_protection.
  ///
  /// In en, this message translates to:
  /// **'Data Protection'**
  String get data_protection;

  /// No description provided for @protect_pinned.
  ///
  /// In en, this message translates to:
  /// **'Do not auto-delete pinned items'**
  String get protect_pinned;

  /// No description provided for @protect_collections.
  ///
  /// In en, this message translates to:
  /// **'Do not auto-delete collection items'**
  String get protect_collections;

  /// No description provided for @auto_cleanup.
  ///
  /// In en, this message translates to:
  /// **'Auto Cleanup'**
  String get auto_cleanup;

  /// No description provided for @retention_period.
  ///
  /// In en, this message translates to:
  /// **'History Retention Period'**
  String get retention_period;

  /// No description provided for @max_items.
  ///
  /// In en, this message translates to:
  /// **'Maximum Items'**
  String get max_items;

  /// No description provided for @items_unit.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get items_unit;

  /// No description provided for @shortcuts_title.
  ///
  /// In en, this message translates to:
  /// **'System Global Shortcuts'**
  String get shortcuts_title;

  /// No description provided for @open_quick_panel.
  ///
  /// In en, this message translates to:
  /// **'Open Quick Panel'**
  String get open_quick_panel;

  /// No description provided for @open_main_window.
  ///
  /// In en, this message translates to:
  /// **'Open Main Window'**
  String get open_main_window;

  /// No description provided for @toggle_monitoring.
  ///
  /// In en, this message translates to:
  /// **'Pause/Resume Monitoring'**
  String get toggle_monitoring;

  /// No description provided for @focus_search.
  ///
  /// In en, this message translates to:
  /// **'Focus Search Bar'**
  String get focus_search;

  /// No description provided for @toggle_pin.
  ///
  /// In en, this message translates to:
  /// **'Pin / Unpin Item'**
  String get toggle_pin;

  /// No description provided for @select_and_copy.
  ///
  /// In en, this message translates to:
  /// **'Select and Copy'**
  String get select_and_copy;

  /// No description provided for @delete_item.
  ///
  /// In en, this message translates to:
  /// **'Delete Item'**
  String get delete_item;

  /// No description provided for @restore_defaults.
  ///
  /// In en, this message translates to:
  /// **'Restore Defaults'**
  String get restore_defaults;

  /// No description provided for @shortcut_hint.
  ///
  /// In en, this message translates to:
  /// **'Click a row to record a new shortcut. Global hotkey takes effect immediately after saving.'**
  String get shortcut_hint;

  /// No description provided for @record_shortcut_title.
  ///
  /// In en, this message translates to:
  /// **'Record New Shortcut'**
  String get record_shortcut_title;

  /// No description provided for @record_shortcut_msg.
  ///
  /// In en, this message translates to:
  /// **'Press the shortcut key combination you want to use.'**
  String get record_shortcut_msg;

  /// No description provided for @system_hotkey_needs_modifier.
  ///
  /// In en, this message translates to:
  /// **'Global shortcuts require a modifier key (Cmd/Ctrl/Option/Shift).'**
  String get system_hotkey_needs_modifier;

  /// No description provided for @choose_non_modifier.
  ///
  /// In en, this message translates to:
  /// **'Please select a non-modifier key.'**
  String get choose_non_modifier;

  /// No description provided for @shortcut_conflict.
  ///
  /// In en, this message translates to:
  /// **'Shortcut is already used for another action.'**
  String get shortcut_conflict;

  /// No description provided for @shortcut_used_by_other_app.
  ///
  /// In en, this message translates to:
  /// **'Shortcut is used by another application.'**
  String get shortcut_used_by_other_app;

  /// No description provided for @saved_shortcut.
  ///
  /// In en, this message translates to:
  /// **'Saved @s.'**
  String get saved_shortcut;

  /// No description provided for @reset_shortcuts_success.
  ///
  /// In en, this message translates to:
  /// **'Restored default shortcuts.'**
  String get reset_shortcuts_success;

  /// No description provided for @press_keys_to_change.
  ///
  /// In en, this message translates to:
  /// **'Click shortcut key to record changes'**
  String get press_keys_to_change;

  /// No description provided for @click_to_record.
  ///
  /// In en, this message translates to:
  /// **'Click here then press your shortcut keys'**
  String get click_to_record;

  /// No description provided for @local_data_saved.
  ///
  /// In en, this message translates to:
  /// **'Data saved locally'**
  String get local_data_saved;

  /// No description provided for @login_items_hint.
  ///
  /// In en, this message translates to:
  /// **'Please enable ClipFlow in Login Items.'**
  String get login_items_hint;

  /// No description provided for @open_at_login_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to toggle \"Launch at Login\".'**
  String get open_at_login_failed;

  /// No description provided for @open_at_login_on.
  ///
  /// In en, this message translates to:
  /// **'ClipFlow will launch at login.'**
  String get open_at_login_on;

  /// No description provided for @open_at_login_off.
  ///
  /// In en, this message translates to:
  /// **'Disabled launch at login.'**
  String get open_at_login_off;

  /// No description provided for @tray_on.
  ///
  /// In en, this message translates to:
  /// **'ClipFlow icon is visible in menu bar.'**
  String get tray_on;

  /// No description provided for @tray_off.
  ///
  /// In en, this message translates to:
  /// **'Hidden menu bar icon.'**
  String get tray_off;

  /// No description provided for @tray_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to update menu bar.'**
  String get tray_failed;

  /// No description provided for @running_apps_empty.
  ///
  /// In en, this message translates to:
  /// **'No running applications found.'**
  String get running_apps_empty;

  /// No description provided for @select_running_app_title.
  ///
  /// In en, this message translates to:
  /// **'Select Running Application'**
  String get select_running_app_title;

  /// No description provided for @exclude_app_title.
  ///
  /// In en, this message translates to:
  /// **'Exclude Application'**
  String get exclude_app_title;

  /// No description provided for @exclude_app_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Example: Bitwarden, Safari'**
  String get exclude_app_placeholder;

  /// No description provided for @privacy_db_notice.
  ///
  /// In en, this message translates to:
  /// **'Clipboard content is saved exclusively in the local database on this device.'**
  String get privacy_db_notice;

  /// No description provided for @version_label.
  ///
  /// In en, this message translates to:
  /// **'Version @v'**
  String get version_label;

  /// No description provided for @update_check_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to check for updates. Please try again later.'**
  String get update_check_failed;

  /// No description provided for @update_available_version.
  ///
  /// In en, this message translates to:
  /// **'New version available (@v)!'**
  String get update_available_version;

  /// No description provided for @latest_version_msg.
  ///
  /// In en, this message translates to:
  /// **'You are on the latest version (@v).'**
  String get latest_version_msg;

  /// No description provided for @downloading_update.
  ///
  /// In en, this message translates to:
  /// **'Downloading update... (@p%)'**
  String get downloading_update;

  /// No description provided for @cannot_auto_install.
  ///
  /// In en, this message translates to:
  /// **'Unable to auto-install. Opening release page...'**
  String get cannot_auto_install;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License (MIT)'**
  String get license;

  /// No description provided for @license_sub.
  ///
  /// In en, this message translates to:
  /// **'Open-Source MIT Software License'**
  String get license_sub;

  /// No description provided for @privacy_policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacy_policy;

  /// No description provided for @privacy_policy_sub.
  ///
  /// In en, this message translates to:
  /// **'100% Local-First, data stays strictly on device'**
  String get privacy_policy_sub;

  /// No description provided for @view_policy.
  ///
  /// In en, this message translates to:
  /// **'View Policy'**
  String get view_policy;

  /// No description provided for @view_license.
  ///
  /// In en, this message translates to:
  /// **'View License'**
  String get view_license;

  /// No description provided for @about_tagline.
  ///
  /// In en, this message translates to:
  /// **'A private, fast, local clipboard manager'**
  String get about_tagline;

  /// No description provided for @added_to_collection.
  ///
  /// In en, this message translates to:
  /// **'Added to collection'**
  String get added_to_collection;

  /// No description provided for @added_to_collection_named.
  ///
  /// In en, this message translates to:
  /// **'Added to collection \"@name\"'**
  String get added_to_collection_named;

  /// No description provided for @all_cleared.
  ///
  /// In en, this message translates to:
  /// **'Clipboard history cleared'**
  String get all_cleared;

  /// No description provided for @all_clips.
  ///
  /// In en, this message translates to:
  /// **'All Clips'**
  String get all_clips;

  /// No description provided for @all_types.
  ///
  /// In en, this message translates to:
  /// **'All Types'**
  String get all_types;

  /// No description provided for @backup_export_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not export backup'**
  String get backup_export_failed;

  /// No description provided for @backup_exported.
  ///
  /// In en, this message translates to:
  /// **'Backup exported'**
  String get backup_exported;

  /// No description provided for @backup_import_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not import backup'**
  String get backup_import_failed;

  /// No description provided for @backup_imported.
  ///
  /// In en, this message translates to:
  /// **'Backup imported'**
  String get backup_imported;

  /// No description provided for @check_update.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get check_update;

  /// No description provided for @cleanup_rules.
  ///
  /// In en, this message translates to:
  /// **'Cleanup Rules'**
  String get cleanup_rules;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clear_all.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clear_all;

  /// No description provided for @clear_all_confirm_msg.
  ///
  /// In en, this message translates to:
  /// **'All clipboard items will be deleted. This cannot be undone.'**
  String get clear_all_confirm_msg;

  /// No description provided for @clear_all_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Clear all history?'**
  String get clear_all_confirm_title;

  /// No description provided for @clear_all_history.
  ///
  /// In en, this message translates to:
  /// **'Clear All History'**
  String get clear_all_history;

  /// No description provided for @clear_all_sub.
  ///
  /// In en, this message translates to:
  /// **'Delete every item, including pinned items'**
  String get clear_all_sub;

  /// No description provided for @clear_unpinned.
  ///
  /// In en, this message translates to:
  /// **'Clear Unpinned'**
  String get clear_unpinned;

  /// No description provided for @clear_unpinned_sub.
  ///
  /// In en, this message translates to:
  /// **'Keep pinned items'**
  String get clear_unpinned_sub;

  /// No description provided for @collection_name.
  ///
  /// In en, this message translates to:
  /// **'Collection name'**
  String get collection_name;

  /// No description provided for @copy_and_paste.
  ///
  /// In en, this message translates to:
  /// **'Copy & Paste'**
  String get copy_and_paste;

  /// No description provided for @copy_text_hint.
  ///
  /// In en, this message translates to:
  /// **'Copy something to get started'**
  String get copy_text_hint;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @database_cleanup.
  ///
  /// In en, this message translates to:
  /// **'Database Cleanup'**
  String get database_cleanup;

  /// No description provided for @days_unit.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get days_unit;

  /// No description provided for @delete_collection_msg.
  ///
  /// In en, this message translates to:
  /// **'Items in this collection will remain in clipboard history.'**
  String get delete_collection_msg;

  /// No description provided for @delete_collection_title.
  ///
  /// In en, this message translates to:
  /// **'Delete this collection?'**
  String get delete_collection_title;

  /// No description provided for @delete_images_first_sub.
  ///
  /// In en, this message translates to:
  /// **'Prioritize images when storage is over limit'**
  String get delete_images_first_sub;

  /// No description provided for @delete_item_shortcut.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected Item'**
  String get delete_item_shortcut;

  /// No description provided for @delete_item_sub.
  ///
  /// In en, this message translates to:
  /// **'Remove this item from clipboard history'**
  String get delete_item_sub;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @export_backup.
  ///
  /// In en, this message translates to:
  /// **'Export Backup'**
  String get export_backup;

  /// No description provided for @export_backup_prompt.
  ///
  /// In en, this message translates to:
  /// **'Enter a password to protect the backup file.'**
  String get export_backup_prompt;

  /// No description provided for @export_backup_sub.
  ///
  /// In en, this message translates to:
  /// **'Save settings to an encrypted .clipflow file'**
  String get export_backup_sub;

  /// No description provided for @export_backup_title.
  ///
  /// In en, this message translates to:
  /// **'Export Settings'**
  String get export_backup_title;

  /// No description provided for @filter_by_type.
  ///
  /// In en, this message translates to:
  /// **'Filter by content type'**
  String get filter_by_type;

  /// No description provided for @apply_filters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get apply_filters;

  /// No description provided for @focus_search_shortcut.
  ///
  /// In en, this message translates to:
  /// **'Focus Search'**
  String get focus_search_shortcut;

  /// No description provided for @focus_search_sub.
  ///
  /// In en, this message translates to:
  /// **'Move focus to the search field'**
  String get focus_search_sub;

  /// No description provided for @global_shortcut_section.
  ///
  /// In en, this message translates to:
  /// **'Global Shortcut'**
  String get global_shortcut_section;

  /// No description provided for @ignore_long_token.
  ///
  /// In en, this message translates to:
  /// **'Ignore Long Tokens'**
  String get ignore_long_token;

  /// No description provided for @ignore_long_token_sub.
  ///
  /// In en, this message translates to:
  /// **'Do not save long secrets or token-like text'**
  String get ignore_long_token_sub;

  /// No description provided for @ignore_sensitive_sub.
  ///
  /// In en, this message translates to:
  /// **'Do not save content that appears sensitive'**
  String get ignore_sensitive_sub;

  /// No description provided for @image_not_found.
  ///
  /// In en, this message translates to:
  /// **'Image not found'**
  String get image_not_found;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @import_backup.
  ///
  /// In en, this message translates to:
  /// **'Import Backup'**
  String get import_backup;

  /// No description provided for @import_backup_prompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the password to decrypt the backup file.'**
  String get import_backup_prompt;

  /// No description provided for @import_backup_sub.
  ///
  /// In en, this message translates to:
  /// **'Restore settings from a .clipflow file'**
  String get import_backup_sub;

  /// No description provided for @import_backup_title.
  ///
  /// In en, this message translates to:
  /// **'Import Settings'**
  String get import_backup_title;

  /// No description provided for @in_app_shortcuts.
  ///
  /// In en, this message translates to:
  /// **'In-App Shortcuts'**
  String get in_app_shortcuts;

  /// No description provided for @item_deleted.
  ///
  /// In en, this message translates to:
  /// **'Item deleted'**
  String get item_deleted;

  /// No description provided for @licenses_sub.
  ///
  /// In en, this message translates to:
  /// **'Licenses for Flutter and open-source packages'**
  String get licenses_sub;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @max_database_size.
  ///
  /// In en, this message translates to:
  /// **'Maximum Database Size'**
  String get max_database_size;

  /// No description provided for @no_matching_clips.
  ///
  /// In en, this message translates to:
  /// **'No matching clips'**
  String get no_matching_clips;

  /// No description provided for @open_source_licenses.
  ///
  /// In en, this message translates to:
  /// **'Open-Source Licenses'**
  String get open_source_licenses;

  /// No description provided for @password_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get password_placeholder;

  /// No description provided for @press_shortcut.
  ///
  /// In en, this message translates to:
  /// **'Press shortcut'**
  String get press_shortcut;

  /// No description provided for @privacy_policy_text.
  ///
  /// In en, this message translates to:
  /// **'Clipboard data is processed and stored locally on your device. ClipFlow does not track or send clipboard history to a server.'**
  String get privacy_policy_text;

  /// No description provided for @retention_and_limits.
  ///
  /// In en, this message translates to:
  /// **'Retention & Limits'**
  String get retention_and_limits;

  /// No description provided for @search_history_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Search clipboard history'**
  String get search_history_placeholder;

  /// No description provided for @starred_clips.
  ///
  /// In en, this message translates to:
  /// **'Starred Clips'**
  String get starred_clips;

  /// No description provided for @tab_ai.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get tab_ai;

  /// No description provided for @toggle_panel_shortcut.
  ///
  /// In en, this message translates to:
  /// **'Toggle Quick Panel'**
  String get toggle_panel_shortcut;

  /// No description provided for @toggle_panel_shortcut_sub.
  ///
  /// In en, this message translates to:
  /// **'Show ClipFlow from any application'**
  String get toggle_panel_shortcut_sub;

  /// No description provided for @toggle_pin_shortcut.
  ///
  /// In en, this message translates to:
  /// **'Toggle Pin'**
  String get toggle_pin_shortcut;

  /// No description provided for @toggle_pin_sub.
  ///
  /// In en, this message translates to:
  /// **'Pin or unpin the selected item'**
  String get toggle_pin_sub;

  /// No description provided for @try_different_search.
  ///
  /// In en, this message translates to:
  /// **'Try another keyword or filter.'**
  String get try_different_search;

  /// No description provided for @unpinned_cleared.
  ///
  /// In en, this message translates to:
  /// **'Unpinned items cleared'**
  String get unpinned_cleared;

  /// No description provided for @view_licenses.
  ///
  /// In en, this message translates to:
  /// **'View Licenses'**
  String get view_licenses;

  /// No description provided for @ai_settings_title.
  ///
  /// In en, this message translates to:
  /// **'Local AI Features (Offline)'**
  String get ai_settings_title;

  /// No description provided for @ai_enabled.
  ///
  /// In en, this message translates to:
  /// **'Enable Local AI'**
  String get ai_enabled;

  /// No description provided for @ai_enabled_sub.
  ///
  /// In en, this message translates to:
  /// **'Allow using AI models that run directly on your device.'**
  String get ai_enabled_sub;

  /// No description provided for @ai_privacy_notice.
  ///
  /// In en, this message translates to:
  /// **'ClipFlow integrates AI running entirely on your device, processing clipboard content without sending data to external servers. No account, API key or Internet required.'**
  String get ai_privacy_notice;

  /// No description provided for @ai_model_selection.
  ///
  /// In en, this message translates to:
  /// **'AI Thinking Models (Reasoning Models)'**
  String get ai_model_selection;

  /// No description provided for @ai_model_selection_sub.
  ///
  /// In en, this message translates to:
  /// **'Only models with deep reasoning (Thinking capabilities) are listed.'**
  String get ai_model_selection_sub;

  /// No description provided for @ai_download_model.
  ///
  /// In en, this message translates to:
  /// **'Download model'**
  String get ai_download_model;

  /// No description provided for @ai_delete_model.
  ///
  /// In en, this message translates to:
  /// **'Delete model'**
  String get ai_delete_model;

  /// No description provided for @ai_downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get ai_downloaded;

  /// No description provided for @ai_not_downloaded.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get ai_not_downloaded;

  /// No description provided for @ai_downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get ai_downloading;

  /// No description provided for @ai_active_model.
  ///
  /// In en, this message translates to:
  /// **'Active model'**
  String get ai_active_model;

  /// No description provided for @ai_chat_assistant.
  ///
  /// In en, this message translates to:
  /// **'ClipFlow Local AI Assistant'**
  String get ai_chat_assistant;

  /// No description provided for @ai_thinking_process.
  ///
  /// In en, this message translates to:
  /// **'Thinking process'**
  String get ai_thinking_process;

  /// No description provided for @ai_context_clip.
  ///
  /// In en, this message translates to:
  /// **'Selected clip — used only when relevant:'**
  String get ai_context_clip;

  /// No description provided for @ai_clear_context.
  ///
  /// In en, this message translates to:
  /// **'Remove clipboard'**
  String get ai_clear_context;

  /// No description provided for @ai_send_prompt.
  ///
  /// In en, this message translates to:
  /// **'Ask AI...'**
  String get ai_send_prompt;

  /// No description provided for @ai_no_model_title.
  ///
  /// In en, this message translates to:
  /// **'AI Model Required'**
  String get ai_no_model_title;

  /// No description provided for @ai_no_model_desc.
  ///
  /// In en, this message translates to:
  /// **'Please download at least 1 AI model to use AI features. Models run entirely on your device, no Internet needed after download.'**
  String get ai_no_model_desc;

  /// No description provided for @ai_recommend_model.
  ///
  /// In en, this message translates to:
  /// **'Recommended for you'**
  String get ai_recommend_model;

  /// No description provided for @ai_resume_download.
  ///
  /// In en, this message translates to:
  /// **'Resume download'**
  String get ai_resume_download;

  /// No description provided for @ai_partial_downloaded.
  ///
  /// In en, this message translates to:
  /// **'Partially downloaded'**
  String get ai_partial_downloaded;

  /// No description provided for @ai_download_paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get ai_download_paused;

  /// No description provided for @ai_delete_partial.
  ///
  /// In en, this message translates to:
  /// **'Delete temp file'**
  String get ai_delete_partial;

  /// No description provided for @ai_all_clipboard_context.
  ///
  /// In en, this message translates to:
  /// **'Ready to search Clipboard when requested (@count items)'**
  String get ai_all_clipboard_context;

  /// No description provided for @ai_select_clip_hint.
  ///
  /// In en, this message translates to:
  /// **'Normal chat does not read Clipboard'**
  String get ai_select_clip_hint;

  /// No description provided for @copy_part.
  ///
  /// In en, this message translates to:
  /// **'Copy this section'**
  String get copy_part;

  /// No description provided for @copy_all.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get copy_all;

  /// No description provided for @paste_all.
  ///
  /// In en, this message translates to:
  /// **'Paste all'**
  String get paste_all;

  /// No description provided for @copy_clipboard_content.
  ///
  /// In en, this message translates to:
  /// **'Copy clipboard content'**
  String get copy_clipboard_content;

  /// No description provided for @tab_sharing_devices.
  ///
  /// In en, this message translates to:
  /// **'Sharing & Devices'**
  String get tab_sharing_devices;

  /// No description provided for @local_network_sharing.
  ///
  /// In en, this message translates to:
  /// **'Local network sharing'**
  String get local_network_sharing;

  /// No description provided for @sharing_private_note.
  ///
  /// In en, this message translates to:
  /// **'Connect directly on the same Wi-Fi without an account or intermediary server.'**
  String get sharing_private_note;

  /// No description provided for @sharing_disabled.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get sharing_disabled;

  /// No description provided for @sharing_paused.
  ///
  /// In en, this message translates to:
  /// **'All connections are paused'**
  String get sharing_paused;

  /// No description provided for @devices_connected_count.
  ///
  /// In en, this message translates to:
  /// **'@count devices connected'**
  String get devices_connected_count;

  /// No description provided for @searching_devices.
  ///
  /// In en, this message translates to:
  /// **'Searching for devices'**
  String get searching_devices;

  /// No description provided for @no_connected_devices.
  ///
  /// In en, this message translates to:
  /// **'No connected devices'**
  String get no_connected_devices;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @available_devices.
  ///
  /// In en, this message translates to:
  /// **'Available devices'**
  String get available_devices;

  /// No description provided for @paired_devices.
  ///
  /// In en, this message translates to:
  /// **'Paired devices'**
  String get paired_devices;

  /// No description provided for @blocked_devices.
  ///
  /// In en, this message translates to:
  /// **'Blocked devices'**
  String get blocked_devices;

  /// No description provided for @manage_devices.
  ///
  /// In en, this message translates to:
  /// **'Manage devices'**
  String get manage_devices;

  /// No description provided for @searching_nearby_devices.
  ///
  /// In en, this message translates to:
  /// **'Searching for nearby devices…'**
  String get searching_nearby_devices;

  /// No description provided for @searching_nearby_devices_sub.
  ///
  /// In en, this message translates to:
  /// **'Keep ClipFlow open on devices connected to the same Wi-Fi network.'**
  String get searching_nearby_devices_sub;

  /// No description provided for @sharing_discovery_off.
  ///
  /// In en, this message translates to:
  /// **'Device discovery is off'**
  String get sharing_discovery_off;

  /// No description provided for @sharing_discovery_off_sub.
  ///
  /// In en, this message translates to:
  /// **'Enable local network sharing to discover devices.'**
  String get sharing_discovery_off_sub;

  /// No description provided for @no_paired_devices.
  ///
  /// In en, this message translates to:
  /// **'No paired devices'**
  String get no_paired_devices;

  /// No description provided for @no_paired_devices_sub.
  ///
  /// In en, this message translates to:
  /// **'Devices that verify the security code will appear here.'**
  String get no_paired_devices_sub;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @reconnect_manually.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect_manually;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @forget_device.
  ///
  /// In en, this message translates to:
  /// **'Forget device'**
  String get forget_device;

  /// No description provided for @block_device.
  ///
  /// In en, this message translates to:
  /// **'Block device'**
  String get block_device;

  /// No description provided for @unblock_device.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock_device;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @platform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get platform;

  /// No description provided for @local_ip.
  ///
  /// In en, this message translates to:
  /// **'Local IP address'**
  String get local_ip;

  /// No description provided for @service_port.
  ///
  /// In en, this message translates to:
  /// **'Service port'**
  String get service_port;

  /// No description provided for @clipflow_version.
  ///
  /// In en, this message translates to:
  /// **'ClipFlow version'**
  String get clipflow_version;

  /// No description provided for @protocol_version.
  ///
  /// In en, this message translates to:
  /// **'Protocol version'**
  String get protocol_version;

  /// No description provided for @connection_quality.
  ///
  /// In en, this message translates to:
  /// **'Connection quality'**
  String get connection_quality;

  /// No description provided for @latency.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get latency;

  /// No description provided for @not_available.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get not_available;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @last_sync_value.
  ///
  /// In en, this message translates to:
  /// **'Last synced: @time'**
  String get last_sync_value;

  /// No description provided for @pending_items_value.
  ///
  /// In en, this message translates to:
  /// **'@count items pending'**
  String get pending_items_value;

  /// No description provided for @peer_status_available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get peer_status_available;

  /// No description provided for @peer_status_pairing.
  ///
  /// In en, this message translates to:
  /// **'Awaiting confirmation'**
  String get peer_status_pairing;

  /// No description provided for @peer_status_connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get peer_status_connecting;

  /// No description provided for @peer_status_authenticating.
  ///
  /// In en, this message translates to:
  /// **'Authenticating'**
  String get peer_status_authenticating;

  /// No description provided for @peer_status_syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get peer_status_syncing;

  /// No description provided for @peer_status_reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get peer_status_reconnecting;

  /// No description provided for @peer_status_connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get peer_status_connected;

  /// No description provided for @peer_status_disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get peer_status_disconnected;

  /// No description provided for @peer_status_rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get peer_status_rejected;

  /// No description provided for @peer_status_incompatible.
  ///
  /// In en, this message translates to:
  /// **'Incompatible'**
  String get peer_status_incompatible;

  /// No description provided for @peer_status_blocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get peer_status_blocked;

  /// No description provided for @quality_excellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get quality_excellent;

  /// No description provided for @quality_good.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get quality_good;

  /// No description provided for @quality_fair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get quality_fair;

  /// No description provided for @quality_poor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get quality_poor;

  /// No description provided for @quality_offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get quality_offline;

  /// No description provided for @pairing_request_title.
  ///
  /// In en, this message translates to:
  /// **'@device wants to connect'**
  String get pairing_request_title;

  /// No description provided for @pairing_code_help.
  ///
  /// In en, this message translates to:
  /// **'Verify that this code matches on both devices. It expires after 60 seconds.'**
  String get pairing_code_help;

  /// No description provided for @codes_match.
  ///
  /// In en, this message translates to:
  /// **'Codes match'**
  String get codes_match;

  /// No description provided for @waiting_other_device.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the other device…'**
  String get waiting_other_device;

  /// No description provided for @reconnect_attempt_value.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting (@count/5)'**
  String get reconnect_attempt_value;

  /// No description provided for @reconnect_manual_required.
  ///
  /// In en, this message translates to:
  /// **'Automatic reconnection failed 5 times. Reconnect manually.'**
  String get reconnect_manual_required;

  /// No description provided for @device_display_name.
  ///
  /// In en, this message translates to:
  /// **'Device display name'**
  String get device_display_name;

  /// No description provided for @device_display_name_sub.
  ///
  /// In en, this message translates to:
  /// **'The name shown to other devices on the network'**
  String get device_display_name_sub;

  /// No description provided for @make_device_discoverable.
  ///
  /// In en, this message translates to:
  /// **'Make this device discoverable'**
  String get make_device_discoverable;

  /// No description provided for @make_device_discoverable_sub.
  ///
  /// In en, this message translates to:
  /// **'Allow other devices to find ClipFlow on the same network'**
  String get make_device_discoverable_sub;

  /// No description provided for @pause_all_connections.
  ///
  /// In en, this message translates to:
  /// **'Pause all connections'**
  String get pause_all_connections;

  /// No description provided for @pause_all_connections_sub.
  ///
  /// In en, this message translates to:
  /// **'Keep pairing data while pausing connections and synchronization'**
  String get pause_all_connections_sub;

  /// No description provided for @connection_and_sync.
  ///
  /// In en, this message translates to:
  /// **'Connection & synchronization'**
  String get connection_and_sync;

  /// No description provided for @auto_connect_trusted.
  ///
  /// In en, this message translates to:
  /// **'Auto-connect trusted devices'**
  String get auto_connect_trusted;

  /// No description provided for @auto_connect_trusted_sub.
  ///
  /// In en, this message translates to:
  /// **'Reconnect after authenticating the stored device key'**
  String get auto_connect_trusted_sub;

  /// No description provided for @auto_sync_new_clipboard.
  ///
  /// In en, this message translates to:
  /// **'Automatically sync new clipboard items'**
  String get auto_sync_new_clipboard;

  /// No description provided for @auto_sync_new_clipboard_sub.
  ///
  /// In en, this message translates to:
  /// **'Send new items to each connected device'**
  String get auto_sync_new_clipboard_sub;

  /// No description provided for @sync_pinned_only.
  ///
  /// In en, this message translates to:
  /// **'Only sync pinned items'**
  String get sync_pinned_only;

  /// No description provided for @sync_pinned_only_sub.
  ///
  /// In en, this message translates to:
  /// **'Do not automatically send unpinned items'**
  String get sync_pinned_only_sub;

  /// No description provided for @allow_receiving_images.
  ///
  /// In en, this message translates to:
  /// **'Allow receiving images'**
  String get allow_receiving_images;

  /// No description provided for @sharing_image_limit.
  ///
  /// In en, this message translates to:
  /// **'Image size limit'**
  String get sharing_image_limit;

  /// No description provided for @sharing_notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get sharing_notifications;

  /// No description provided for @notify_device_connected.
  ///
  /// In en, this message translates to:
  /// **'Notify when a device connects'**
  String get notify_device_connected;

  /// No description provided for @notify_clipboard_received.
  ///
  /// In en, this message translates to:
  /// **'Notify when a clipboard item arrives'**
  String get notify_clipboard_received;

  /// No description provided for @sharing_service_error.
  ///
  /// In en, this message translates to:
  /// **'Could not update the sharing service. Please try again.'**
  String get sharing_service_error;

  /// No description provided for @forget_device_title.
  ///
  /// In en, this message translates to:
  /// **'Forget this device?'**
  String get forget_device_title;

  /// No description provided for @forget_device_message.
  ///
  /// In en, this message translates to:
  /// **'The trusted key will be removed. Connecting again requires a new 6-digit pairing code.'**
  String get forget_device_message;

  /// No description provided for @block_device_title.
  ///
  /// In en, this message translates to:
  /// **'Block this device?'**
  String get block_device_title;

  /// No description provided for @block_device_message.
  ///
  /// In en, this message translates to:
  /// **'The device will be disconnected and all new requests will be rejected.'**
  String get block_device_message;

  /// No description provided for @delete_collection_confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete Collection Confirm'**
  String get delete_collection_confirm;

  /// No description provided for @ai_performance_mode.
  ///
  /// In en, this message translates to:
  /// **'AI intelligence level'**
  String get ai_performance_mode;

  /// No description provided for @ai_performance_fast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get ai_performance_fast;

  /// No description provided for @ai_performance_balanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get ai_performance_balanced;

  /// No description provided for @ai_performance_smart.
  ///
  /// In en, this message translates to:
  /// **'Smart'**
  String get ai_performance_smart;

  /// No description provided for @ai_result_count.
  ///
  /// In en, this message translates to:
  /// **'Found @count items.'**
  String get ai_result_count;

  /// No description provided for @ai_result_url_count.
  ///
  /// In en, this message translates to:
  /// **'Found @count items with links.'**
  String get ai_result_url_count;

  /// No description provided for @ai_result_image_count.
  ///
  /// In en, this message translates to:
  /// **'Found @count images.'**
  String get ai_result_image_count;

  /// No description provided for @ai_result_empty.
  ///
  /// In en, this message translates to:
  /// **'No matching clipboard items found.'**
  String get ai_result_empty;

  /// No description provided for @ai_result_show_more.
  ///
  /// In en, this message translates to:
  /// **'More results available'**
  String get ai_result_show_more;

  /// No description provided for @ai_confirm_action_title.
  ///
  /// In en, this message translates to:
  /// **'Confirm action'**
  String get ai_confirm_action_title;

  /// No description provided for @ai_confirm_pin.
  ///
  /// In en, this message translates to:
  /// **'Pin these @count clipboard items?'**
  String get ai_confirm_pin;

  /// No description provided for @ai_confirm_unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin these @count clipboard items?'**
  String get ai_confirm_unpin;

  /// No description provided for @ai_confirm_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete these @count clipboard items?'**
  String get ai_confirm_delete;

  /// No description provided for @ai_confirm_add_collection.
  ///
  /// In en, this message translates to:
  /// **'Add these @count items to collection \"@name\"?'**
  String get ai_confirm_add_collection;

  /// No description provided for @ai_confirm_generic.
  ///
  /// In en, this message translates to:
  /// **'Apply this action to @count items?'**
  String get ai_confirm_generic;

  /// No description provided for @ai_receipt_pin.
  ///
  /// In en, this message translates to:
  /// **'Pinned @count items.'**
  String get ai_receipt_pin;

  /// No description provided for @ai_receipt_unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpinned @count items.'**
  String get ai_receipt_unpin;

  /// No description provided for @ai_receipt_delete.
  ///
  /// In en, this message translates to:
  /// **'Deleted @count items.'**
  String get ai_receipt_delete;

  /// No description provided for @ai_receipt_collection.
  ///
  /// In en, this message translates to:
  /// **'Added @count items to the collection.'**
  String get ai_receipt_collection;

  /// No description provided for @ai_receipt_generic.
  ///
  /// In en, this message translates to:
  /// **'Updated @count items.'**
  String get ai_receipt_generic;

  /// No description provided for @ai_error_reference_not_found.
  ///
  /// In en, this message translates to:
  /// **'I could not tell which clipboard items you meant. Please search first.'**
  String get ai_error_reference_not_found;

  /// No description provided for @ai_error_collection_not_found.
  ///
  /// In en, this message translates to:
  /// **'That collection does not exist.'**
  String get ai_error_collection_not_found;

  /// No description provided for @ai_error_collection_name_required.
  ///
  /// In en, this message translates to:
  /// **'Please tell me the collection name.'**
  String get ai_error_collection_name_required;

  /// No description provided for @ai_error_generic.
  ///
  /// In en, this message translates to:
  /// **'The action could not be completed.'**
  String get ai_error_generic;

  /// No description provided for @ai_saved_result_set.
  ///
  /// In en, this message translates to:
  /// **'Saved clipboard result (@count items).'**
  String get ai_saved_result_set;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @ai_image_needs_vision_model.
  ///
  /// In en, this message translates to:
  /// **'This model cannot read images. It answered from OCR text and file details only. Download a vision model (Gemma 4 12B Vision or Qwen2.5-VL 7B) to analyse the picture itself.'**
  String get ai_image_needs_vision_model;

  /// No description provided for @vault_title.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get vault_title;

  /// No description provided for @vault_enabled.
  ///
  /// In en, this message translates to:
  /// **'Enable Vault'**
  String get vault_enabled;

  /// No description provided for @vault_enabled_sub.
  ///
  /// In en, this message translates to:
  /// **'Protect a system collection with encryption and authentication.'**
  String get vault_enabled_sub;

  /// No description provided for @vault_create_password_title.
  ///
  /// In en, this message translates to:
  /// **'Create Vault password'**
  String get vault_create_password_title;

  /// No description provided for @vault_unlock_title.
  ///
  /// In en, this message translates to:
  /// **'Unlock Vault'**
  String get vault_unlock_title;

  /// No description provided for @vault_unlock_sub.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to view encrypted clipboard items.'**
  String get vault_unlock_sub;

  /// No description provided for @vault_password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get vault_password;

  /// No description provided for @vault_confirm_password.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get vault_confirm_password;

  /// No description provided for @vault_new_password.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get vault_new_password;

  /// No description provided for @vault_password_min.
  ///
  /// In en, this message translates to:
  /// **'Use at least 6 characters.'**
  String get vault_password_min;

  /// No description provided for @vault_password_mismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get vault_password_mismatch;

  /// No description provided for @vault_unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get vault_unlock;

  /// No description provided for @vault_use_device_auth.
  ///
  /// In en, this message translates to:
  /// **'Use device authentication'**
  String get vault_use_device_auth;

  /// No description provided for @vault_invalid_password.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password.'**
  String get vault_invalid_password;

  /// No description provided for @vault_attempts_remaining.
  ///
  /// In en, this message translates to:
  /// **'@count attempts remaining.'**
  String get vault_attempts_remaining;

  /// No description provided for @vault_data_wiped.
  ///
  /// In en, this message translates to:
  /// **'Vault data was deleted after 5 failed attempts.'**
  String get vault_data_wiped;

  /// No description provided for @vault_change_password.
  ///
  /// In en, this message translates to:
  /// **'Change Vault password'**
  String get vault_change_password;

  /// No description provided for @vault_change_password_sub.
  ///
  /// In en, this message translates to:
  /// **'Rewrap the encryption key with a new password.'**
  String get vault_change_password_sub;

  /// No description provided for @vault_device_auth.
  ///
  /// In en, this message translates to:
  /// **'Face ID, fingerprint or device authentication'**
  String get vault_device_auth;

  /// No description provided for @vault_device_auth_sub.
  ///
  /// In en, this message translates to:
  /// **'Use an authentication method configured on this device.'**
  String get vault_device_auth_sub;

  /// No description provided for @vault_device_auth_failed.
  ///
  /// In en, this message translates to:
  /// **'Device authentication was unavailable or cancelled.'**
  String get vault_device_auth_failed;

  /// No description provided for @vault_wipe_after_five.
  ///
  /// In en, this message translates to:
  /// **'Delete Vault data after 5 failed attempts'**
  String get vault_wipe_after_five;

  /// No description provided for @vault_wipe_after_five_sub.
  ///
  /// In en, this message translates to:
  /// **'Permanently deletes only encrypted items in the Vault. Off by default.'**
  String get vault_wipe_after_five_sub;

  /// No description provided for @vault_encryption_title.
  ///
  /// In en, this message translates to:
  /// **'AES-256 encrypted at rest'**
  String get vault_encryption_title;

  /// No description provided for @vault_encryption_sub.
  ///
  /// In en, this message translates to:
  /// **'Clipboard content, metadata and image files are encrypted before being stored.'**
  String get vault_encryption_sub;

  /// No description provided for @vault_disable_confirm.
  ///
  /// In en, this message translates to:
  /// **'Disable Vault and restore its decrypted items to clipboard history?'**
  String get vault_disable_confirm;

  /// No description provided for @vault_locked_notice.
  ///
  /// In en, this message translates to:
  /// **'Unlock the Vault before continuing.'**
  String get vault_locked_notice;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'ja',
    'ko',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
