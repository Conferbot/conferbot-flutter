import 'package:intl/intl.dart';

/// Comprehensive validation utilities for the Conferbot Flutter SDK.
/// These validation methods match the validation logic used in the web widget
/// and Android SDK to ensure consistent behavior across platforms.

// ============================================
// VALIDATION RESULT CLASS
// ============================================

/// Data class representing the result of a validation operation.
class ValidationResult {
  /// Whether the validation passed
  final bool isValid;

  /// The error message if validation failed, null otherwise
  final String? errorMessage;

  const ValidationResult(this.isValid, [this.errorMessage]);

  /// Returns the error message if invalid, or the default value if valid.
  String getErrorOrDefault([String defaultValue = '']) {
    return errorMessage ?? defaultValue;
  }

  @override
  String toString() =>
      'ValidationResult(isValid: $isValid, errorMessage: $errorMessage)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ValidationResult &&
        other.isValid == isValid &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => isValid.hashCode ^ errorMessage.hashCode;
}

// ============================================
// VALIDATION UTILS
// ============================================

/// Static validation utility class providing comprehensive validation methods.
class ValidationUtils {
  ValidationUtils._(); // Private constructor to prevent instantiation

  // ============================================
  // EMAIL VALIDATION
  // ============================================

  /// Email validation regex pattern.
  /// Matches the pattern used in the web widget:
  /// - Local part: allows letters, numbers, and special characters
  /// - Domain: allows letters, numbers, hyphens, and IP addresses in brackets
  /// - TLD: requires at least 2 characters
  static final RegExp _emailPattern = RegExp(
    r'^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
    caseSensitive: false,
  );

  /// Validates an email address.
  /// Matches the _validateEmailHelper function from the web widget.
  ///
  /// [email] The email address to validate
  /// Returns true if the email is valid, false otherwise
  static bool isValidEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    return _emailPattern.hasMatch(email.trim().toLowerCase());
  }

  /// Validates an email address with detailed result.
  ///
  /// [email] The email address to validate
  /// Returns [ValidationResult] containing validity and error message if invalid
  static ValidationResult validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return const ValidationResult(false, 'Email address is required');
    }
    if (!_emailPattern.hasMatch(email.trim().toLowerCase())) {
      return const ValidationResult(false, 'Please enter a valid email address');
    }
    return const ValidationResult(true);
  }

  // ============================================
  // PHONE NUMBER VALIDATION
  // ============================================

  /// Phone number validation regex pattern.
  /// Matches the pattern used in the web widget:
  /// - Requires 6-15 digits only
  static final RegExp _phonePatternBasic = RegExp(r'^\d{6,15}$');

  /// International phone number pattern with optional country code.
  /// More flexible pattern for international formats:
  /// - Optional + prefix for country code
  /// - Allows spaces, dashes, parentheses for formatting
  /// - Requires minimum 6 digits, maximum 15 digits (E.164 standard)
  static final RegExp _phonePatternInternational = RegExp(
    r'^\+?[0-9]{1,4}?[-.\s]?\(?[0-9]{1,3}?\)?[-.\s]?[0-9]{1,4}[-.\s]?[0-9]{1,4}[-.\s]?[0-9]{1,9}$',
  );

  /// Validates a phone number using basic validation (digits only).
  /// Matches the _validatePhoneNumberHelper function from the web widget.
  ///
  /// [phoneNumber] The phone number to validate
  /// [allowInternational] Whether to allow international format with + prefix
  /// Returns true if the phone number is valid, false otherwise
  static bool isValidPhoneNumber(String? phoneNumber,
      {bool allowInternational = true}) {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) return false;

    if (allowInternational) {
      // Check international format first
      if (_phonePatternInternational.hasMatch(phoneNumber.trim())) {
        // Also verify digit count is within E.164 limits
        final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
        return digitsOnly.length >= 6 && digitsOnly.length <= 15;
      }
      return false;
    } else {
      // Remove all non-digit characters for basic validation (matching web widget behavior)
      final digitsOnly = phoneNumber.trim().replaceAll(RegExp(r'[^0-9]'), '');
      return _phonePatternBasic.hasMatch(digitsOnly);
    }
  }

  /// Validates a phone number with detailed result.
  ///
  /// [phoneNumber] The phone number to validate
  /// [allowInternational] Whether to allow international format
  /// Returns [ValidationResult] containing validity and error message if invalid
  static ValidationResult validatePhoneNumber(String? phoneNumber,
      {bool allowInternational = true}) {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      return const ValidationResult(false, 'Phone number is required');
    }
    if (!isValidPhoneNumber(phoneNumber, allowInternational: allowInternational)) {
      return const ValidationResult(false, 'Please enter a valid phone number');
    }
    return const ValidationResult(true);
  }

  // ============================================
  // URL VALIDATION
  // ============================================

  /// URL validation regex pattern.
  /// Matches the pattern used in the web widget:
  /// - Optional http:// or https:// protocol
  /// - Domain with TLD (2-6 characters)
  /// - Optional path
  static final RegExp _urlPattern = RegExp(
    r'^(https?://)?([a-zA-Z0-9.-]+)\.([a-zA-Z.]{2,6})([/\w .-]*)*/?$',
    caseSensitive: false,
  );

  /// More comprehensive URL pattern for stricter validation.
  static final RegExp _urlPatternStrict = RegExp(
    r"^(https?://)?([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}(/[\w\-.~:/?#\[\]@!\$&'()*+,;=]*)?$",
    caseSensitive: false,
  );

  /// Validates a URL.
  /// Matches the _validateUrlHelper function from the web widget.
  ///
  /// [url] The URL to validate
  /// [strictMode] Whether to use stricter validation
  /// Returns true if the URL is valid, false otherwise
  static bool isValidUrl(String? url, {bool strictMode = false}) {
    if (url == null || url.trim().isEmpty) return false;

    if (strictMode) {
      return _urlPatternStrict.hasMatch(url.trim());
    }
    return _urlPattern.hasMatch(url.trim().toLowerCase());
  }

  /// Validates a URL with detailed result.
  ///
  /// [url] The URL to validate
  /// Returns [ValidationResult] containing validity and error message if invalid
  static ValidationResult validateUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return const ValidationResult(false, 'URL is required');
    }
    if (!isValidUrl(url)) {
      return const ValidationResult(false, 'Please enter a valid URL');
    }
    return const ValidationResult(true);
  }

  // ============================================
  // NUMBER VALIDATION
  // ============================================

  /// Validates if a string is a valid number.
  ///
  /// [value] The string to validate
  /// Returns true if the string is a valid number, false otherwise
  static bool isValidNumber(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    return double.tryParse(value.trim()) != null;
  }

  /// Validates if a string is a valid integer.
  ///
  /// [value] The string to validate
  /// Returns true if the string is a valid integer, false otherwise
  static bool isValidInteger(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    return int.tryParse(value.trim()) != null;
  }

  /// Validates if a number is within a specified range.
  ///
  /// [value] The string value to validate
  /// [min] Minimum allowed value (inclusive)
  /// [max] Maximum allowed value (inclusive)
  /// Returns true if the number is valid and within range, false otherwise
  static bool isValidNumberInRange(String? value,
      {double? min, double? max}) {
    if (value == null || value.trim().isEmpty) return false;
    final number = double.tryParse(value.trim());
    if (number == null) return false;
    if (min != null && number < min) return false;
    if (max != null && number > max) return false;
    return true;
  }

  /// Validates if an integer is within a specified range.
  ///
  /// [value] The string value to validate
  /// [min] Minimum allowed value (inclusive)
  /// [max] Maximum allowed value (inclusive)
  /// Returns true if the integer is valid and within range, false otherwise
  static bool isValidIntegerInRange(String? value, {int? min, int? max}) {
    if (value == null || value.trim().isEmpty) return false;
    final number = int.tryParse(value.trim());
    if (number == null) return false;
    if (min != null && number < min) return false;
    if (max != null && number > max) return false;
    return true;
  }

  /// Validates a number with detailed result.
  ///
  /// [value] The string value to validate
  /// [min] Optional minimum value
  /// [max] Optional maximum value
  /// Returns [ValidationResult] containing validity and error message if invalid
  static ValidationResult validateNumber(String? value,
      {double? min, double? max}) {
    if (value == null || value.trim().isEmpty) {
      return const ValidationResult(false, 'Number is required');
    }

    final number = double.tryParse(value.trim());
    if (number == null) {
      return const ValidationResult(false, 'Please enter a valid number');
    }

    if (min != null && number < min) {
      return ValidationResult(false, 'Number must be at least $min');
    }

    if (max != null && number > max) {
      return ValidationResult(false, 'Number must be at most $max');
    }

    return const ValidationResult(true);
  }

  // ============================================
  // DATE/TIME VALIDATION
  // ============================================

  /// Common date format patterns.
  static const String isoDate = 'yyyy-MM-dd';
  static const String isoDateTime = "yyyy-MM-dd'T'HH:mm:ss";
  static const String isoDateTimeWithTimezone = "yyyy-MM-dd'T'HH:mm:ssZ";
  static const String usDate = 'MM/dd/yyyy';
  static const String euDate = 'dd/MM/yyyy';
  static const String displayDate = 'MMM dd, yyyy';
  static const String displayDateTime = 'MMM dd, yyyy HH:mm';
  static const String time12h = 'hh:mm a';
  static const String time24h = 'HH:mm';

  /// Validates if a string is a valid date in the specified format.
  ///
  /// [dateString] The date string to validate
  /// [format] The expected date format (default: ISO date format)
  /// Returns true if the date string is valid, false otherwise
  static bool isValidDate(String? dateString, {String format = isoDate}) {
    if (dateString == null || dateString.trim().isEmpty) return false;

    try {
      final dateFormat = DateFormat(format);
      dateFormat.parseStrict(dateString.trim());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validates if a string is a valid time in the specified format.
  ///
  /// [timeString] The time string to validate
  /// [format] The expected time format (default: 24-hour format)
  /// Returns true if the time string is valid, false otherwise
  static bool isValidTime(String? timeString, {String format = time24h}) {
    if (timeString == null || timeString.trim().isEmpty) return false;

    try {
      final dateFormat = DateFormat(format);
      dateFormat.parseStrict(timeString.trim());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validates if a date is within a specified range.
  ///
  /// [dateString] The date string to validate
  /// [format] The expected date format
  /// [minDate] The minimum allowed date (inclusive)
  /// [maxDate] The maximum allowed date (inclusive)
  /// Returns true if the date is valid and within range, false otherwise
  static bool isValidDateInRange(
    String? dateString, {
    String format = isoDate,
    DateTime? minDate,
    DateTime? maxDate,
  }) {
    if (dateString == null || dateString.trim().isEmpty) return false;

    try {
      final dateFormat = DateFormat(format);
      final date = dateFormat.parseStrict(dateString.trim());

      if (minDate != null && date.isBefore(minDate)) return false;
      if (maxDate != null && date.isAfter(maxDate)) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validates a date with detailed result.
  ///
  /// [dateString] The date string to validate
  /// [format] The expected date format
  /// Returns [ValidationResult] containing validity and error message if invalid
  static ValidationResult validateDate(String? dateString,
      {String format = isoDate}) {
    if (dateString == null || dateString.trim().isEmpty) {
      return const ValidationResult(false, 'Date is required');
    }
    if (!isValidDate(dateString, format: format)) {
      return const ValidationResult(false, 'Please enter a valid date');
    }
    return const ValidationResult(true);
  }

  /// Parses a date string to DateTime object.
  ///
  /// [dateString] The date string to parse
  /// [format] The expected date format
  /// Returns DateTime object if parsing succeeds, null otherwise
  static DateTime? parseDate(String? dateString, {String format = isoDate}) {
    if (dateString == null || dateString.trim().isEmpty) return null;

    try {
      final dateFormat = DateFormat(format);
      return dateFormat.parseStrict(dateString.trim());
    } catch (e) {
      return null;
    }
  }

  /// Formats a DateTime object to string.
  ///
  /// [date] The DateTime object to format
  /// [format] The desired date format
  /// Returns formatted date string
  static String formatDate(DateTime date, {String format = isoDate}) {
    final dateFormat = DateFormat(format);
    return dateFormat.format(date);
  }

  // ============================================
  // REQUIRED FIELD VALIDATION
  // ============================================

  /// Validates that a field is not empty or blank.
  ///
  /// [value] The value to validate
  /// Returns true if the value is not empty or blank, false otherwise
  static bool isNotEmpty(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  /// Validates that a field is not null.
  ///
  /// [value] The value to validate
  /// Returns true if the value is not null, false otherwise
  static bool isNotNull(Object? value) {
    return value != null;
  }

  /// Validates a required field with detailed result.
  ///
  /// [value] The value to validate
  /// [fieldName] The name of the field for the error message
  /// Returns [ValidationResult] containing validity and error message if invalid
  static ValidationResult validateRequired(String? value,
      {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return ValidationResult(false, '$fieldName is required');
    }
    return const ValidationResult(true);
  }

  /// Validates field length.
  ///
  /// [value] The value to validate
  /// [minLength] Minimum length (inclusive)
  /// [maxLength] Maximum length (inclusive)
  /// Returns true if the length is within range, false otherwise
  static bool isValidLength(String? value, {int minLength = 0, int? maxLength}) {
    if (value == null) return minLength == 0;
    if (value.length < minLength) return false;
    if (maxLength != null && value.length > maxLength) return false;
    return true;
  }

  /// Validates field length with detailed result.
  ///
  /// [value] The value to validate
  /// [minLength] Minimum length (inclusive)
  /// [maxLength] Maximum length (inclusive)
  /// [fieldName] The name of the field for the error message
  /// Returns [ValidationResult] containing validity and error message if invalid
  static ValidationResult validateLength(
    String? value, {
    int minLength = 0,
    int? maxLength,
    String fieldName = 'This field',
  }) {
    if (value == null) {
      if (minLength == 0) {
        return const ValidationResult(true);
      }
      return ValidationResult(
          false, '$fieldName must be at least $minLength characters');
    }

    if (value.length < minLength) {
      return ValidationResult(
          false, '$fieldName must be at least $minLength characters');
    }

    if (maxLength != null && value.length > maxLength) {
      return ValidationResult(
          false, '$fieldName must be at most $maxLength characters');
    }

    return const ValidationResult(true);
  }

  // ============================================
  // CUSTOM PATTERN VALIDATION
  // ============================================

  /// Validates a value against a custom regex pattern.
  ///
  /// [value] The value to validate
  /// [pattern] The regex pattern string to match
  /// Returns true if the value matches the pattern, false otherwise
  static bool matchesPattern(String? value, String pattern) {
    if (value == null || value.trim().isEmpty) return false;
    return RegExp(pattern).hasMatch(value);
  }

  /// Validates a value against a custom RegExp pattern.
  ///
  /// [value] The value to validate
  /// [pattern] The compiled RegExp to match
  /// Returns true if the value matches the pattern, false otherwise
  static bool matchesRegExp(String? value, RegExp pattern) {
    if (value == null || value.trim().isEmpty) return false;
    return pattern.hasMatch(value);
  }

  // ============================================
  // COMPOSITE VALIDATION
  // ============================================

  /// Validates multiple conditions and returns the first error.
  ///
  /// [validations] List of ValidationResult objects
  /// Returns the first failed ValidationResult, or a success result if all pass
  static ValidationResult validateAll(List<ValidationResult> validations) {
    for (final validation in validations) {
      if (!validation.isValid) {
        return validation;
      }
    }
    return const ValidationResult(true);
  }

  /// Validates a value based on its type/purpose.
  ///
  /// [value] The value to validate
  /// [fieldType] The type of field (email, phone, url, number, date, text)
  /// [required] Whether the field is required
  /// Returns [ValidationResult] containing validity and error message if invalid
  static ValidationResult validateByType(
    String? value, {
    required String fieldType,
    bool required = true,
  }) {
    // Check required first
    if (required && (value == null || value.trim().isEmpty)) {
      return const ValidationResult(false, 'This field is required');
    }

    // If not required and empty, it's valid
    if (!required && (value == null || value.trim().isEmpty)) {
      return const ValidationResult(true);
    }

    // Validate based on type
    switch (fieldType.toLowerCase()) {
      case 'email':
        return validateEmail(value);
      case 'phone':
      case 'mobile':
      case 'telephone':
        return validatePhoneNumber(value);
      case 'url':
      case 'website':
      case 'link':
        return validateUrl(value);
      case 'number':
      case 'numeric':
      case 'integer':
        return validateNumber(value);
      case 'date':
        return validateDate(value);
      case 'text':
      case 'name':
      default:
        return validateRequired(value);
    }
  }
}
