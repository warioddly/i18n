// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Message/plural format library with locale support. This can have different
/// implementations based on the mechanism for finding the localized versions of
/// messages. This version expects them to be in a library named e.g.
/// 'messages_en_US'. The prefix is set in the "initializeMessages" call, which
/// must be made for a locale before any lookups can be done.
///
/// See Intl class comment or `tests/message_format_test.dart` for more
/// examples.
library message_lookup_by_library;

import 'intl.dart';

/// This is a message lookup mechanism that delegates to one of a collection
/// of individual [MessageLookupByLibrary] instances.
class CompositeMessageLookup {
  /// A map from locale names to the corresponding lookups.
  Map<String, MessageLookupByLibrary> availableMessages = new Map();

  /// Return true if we have a message lookup for [localeName].
  bool localeExists(localeName) => availableMessages.containsKey(localeName);

  /// The last locale in which we looked up messages.
  ///
  ///  If this locale matches the new one then we can skip looking up the
  ///  messages and assume they will be the same as last time.
  String _lastLocale;

  /// Caches the last messages that we found
  MessageLookupByLibrary _lastLookup;

  /// Look up the message with the given [name] and [locale] and return
  /// the translated version with the values in [args] interpolated.
  /// If nothing is found, return [message_str]. The [desc] and [examples]
  /// parameters are ignored
  String lookupMessage(
      String message_str, String locale, String name, List args) {
    // If passed null, use the default.
    var knownLocale = locale ?? Intl.getCurrentLocale();
    var messages = (knownLocale == _lastLocale)
        ? _lastLookup
        : _lookupMessageCatalog(knownLocale);
    // If we didn't find any messages for this locale, use the original string.
    if (messages == null) return message_str;
    return messages.lookupMessage(message_str, locale, name, args);
  }

  /// Find the right message lookup for [locale].
  MessageLookupByLibrary _lookupMessageCatalog(String locale) {
    var verifiedLocale = Intl.verifiedLocale(locale, localeExists,
        onFailure: (locale) => locale);
    _lastLocale = locale;
    _lastLookup = availableMessages[verifiedLocale];
    return _lastLookup;
  }

  /// If we do not already have a locale for [localeName] then
  /// [findLocale] will be called and the result stored as the lookup
  /// mechanism for that locale.
  addLocale(String localeName, Function findLocale) {
    if (localeExists(localeName)) return;
    var canonical = Intl.canonicalizedLocale(localeName);
    var newLocale = findLocale(canonical);
    if (newLocale != null) {
      availableMessages[localeName] = newLocale;
      availableMessages[canonical] = newLocale;
      // If there was already a failed lookup for [newLocale], null the cache.
      if (_lastLocale == newLocale) {
        _lastLocale = null;
        _lastLookup = null;
      }
    }
  }
}

/// This provides an abstract class for messages looked up in generated code.
/// Each locale will have a separate subclass of this class with its set of
/// messages. See generate_localized.dart.
abstract class MessageLookupByLibrary {
  /// Return the localized version of a message. We are passed the original
  /// version of the message, which consists of a
  /// [message_str] that will be translated, and which may be interpolated
  /// based on one or more variables, a [desc] providing a description of usage
  /// for the [message_str], and a map of [examples] for each data element to be
  /// substituted into the message.
  ///
  /// For example, if message="Hello, $name", then
  /// examples = {'name': 'Sparky'}. If not using the user's default locale, or
  /// if the locale is not easily detectable, explicitly pass [locale].
  ///
  /// The values of [desc] and [examples] are not used at run-time but are only
  /// made available to the translators, so they MUST be simple Strings
  /// available at compile time: no String interpolation or concatenation.  The
  /// expected usage of this is inside a function that takes as parameters the
  /// variables used in the interpolated string.
  ///
  /// Ultimately, the information about the enclosing function and its arguments
  /// will be extracted automatically but for the time being it must be passed
  /// explicitly in the [name] and [args] arguments.
  String lookupMessage(
      String message_str, String locale, String name, List args) {
    if (name == null) return message_str;
    var function = this[name];
    return function == null ? message_str : Function.apply(function, args);
  }

  /// Return our message with the given name
  operator [](String messageName) => messages[messageName];

  /// Subclasses should override this to return a list of their message
  /// functions.
  Map<String, Function> get messages;

  /// Subclasses should override this to return their locale, e.g. 'en_US'
  String get localeName;

  toString() => localeName;

  /// Return a function that returns the given string.
  /// An optimization for dart2js, used from the generated code.
  static simpleMessage(translatedString) => () => translatedString;
}
