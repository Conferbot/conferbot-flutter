import 'package:flutter_test/flutter_test.dart';
import 'package:conferbot_flutter/src/utils/validation_utils.dart';

void main() {
  group('ValidationResult', () {
    test('should create valid result', () {
      const result = ValidationResult(true);

      expect(result.isValid, true);
      expect(result.errorMessage, isNull);
    });

    test('should create invalid result with error message', () {
      const result = ValidationResult(false, 'Error message');

      expect(result.isValid, false);
      expect(result.errorMessage, 'Error message');
    });

    test('should return error or default value', () {
      const validResult = ValidationResult(true);
      const invalidResult = ValidationResult(false, 'Error');

      expect(validResult.getErrorOrDefault('default'), '');
      expect(invalidResult.getErrorOrDefault('default'), 'Error');
    });

    test('should have correct equality', () {
      const result1 = ValidationResult(true);
      const result2 = ValidationResult(true);
      const result3 = ValidationResult(false, 'Error');

      expect(result1 == result2, true);
      expect(result1 == result3, false);
    });

    test('should have correct toString', () {
      const result = ValidationResult(true);

      expect(result.toString(), contains('isValid: true'));
    });
  });

  group('Email Validation', () {
    test('should validate correct email addresses', () {
      expect(ValidationUtils.isValidEmail('test@example.com'), true);
      expect(ValidationUtils.isValidEmail('user.name@domain.co.uk'), true);
      expect(ValidationUtils.isValidEmail('user+tag@example.org'), true);
      expect(ValidationUtils.isValidEmail('test123@test.io'), true);
      expect(ValidationUtils.isValidEmail('a@b.co'), true);
    });

    test('should reject invalid email addresses', () {
      expect(ValidationUtils.isValidEmail(''), false);
      expect(ValidationUtils.isValidEmail(null), false);
      expect(ValidationUtils.isValidEmail('invalid'), false);
      expect(ValidationUtils.isValidEmail('invalid@'), false);
      expect(ValidationUtils.isValidEmail('@domain.com'), false);
      expect(ValidationUtils.isValidEmail('test@.com'), false);
      expect(ValidationUtils.isValidEmail('test@domain'), false);
      expect(ValidationUtils.isValidEmail('test @domain.com'), false);
    });

    test('should be case insensitive', () {
      expect(ValidationUtils.isValidEmail('TEST@EXAMPLE.COM'), true);
      expect(ValidationUtils.isValidEmail('Test@Example.Com'), true);
    });

    test('should handle whitespace', () {
      expect(ValidationUtils.isValidEmail('  test@example.com  '), true);
      expect(ValidationUtils.isValidEmail('   '), false);
    });

    test('validateEmail should return detailed result', () {
      final validResult = ValidationUtils.validateEmail('test@example.com');
      expect(validResult.isValid, true);
      expect(validResult.errorMessage, isNull);

      final emptyResult = ValidationUtils.validateEmail('');
      expect(emptyResult.isValid, false);
      expect(emptyResult.errorMessage, 'Email address is required');

      final invalidResult = ValidationUtils.validateEmail('invalid');
      expect(invalidResult.isValid, false);
      expect(invalidResult.errorMessage, 'Please enter a valid email address');
    });
  });

  group('Phone Number Validation', () {
    test('should validate correct phone numbers (basic)', () {
      expect(ValidationUtils.isValidPhoneNumber('1234567890', allowInternational: false), true);
      expect(ValidationUtils.isValidPhoneNumber('123456', allowInternational: false), true);
      expect(ValidationUtils.isValidPhoneNumber('123456789012345', allowInternational: false), true);
    });

    test('should validate international phone numbers', () {
      expect(ValidationUtils.isValidPhoneNumber('+1234567890'), true);
      expect(ValidationUtils.isValidPhoneNumber('+1 234 567 8900'), true);
      expect(ValidationUtils.isValidPhoneNumber('+44 20 7946 0958'), true);
      expect(ValidationUtils.isValidPhoneNumber('(123) 456-7890'), true);
    });

    test('should reject invalid phone numbers', () {
      expect(ValidationUtils.isValidPhoneNumber(''), false);
      expect(ValidationUtils.isValidPhoneNumber(null), false);
      expect(ValidationUtils.isValidPhoneNumber('12345', allowInternational: false), false);
      expect(ValidationUtils.isValidPhoneNumber('abc123'), false);
      expect(ValidationUtils.isValidPhoneNumber('1234567890123456', allowInternational: false), false);
    });

    test('should handle whitespace in phone numbers', () {
      expect(ValidationUtils.isValidPhoneNumber('  1234567890  ', allowInternational: false), true);
    });

    test('validatePhoneNumber should return detailed result', () {
      final validResult = ValidationUtils.validatePhoneNumber('+1234567890');
      expect(validResult.isValid, true);

      final emptyResult = ValidationUtils.validatePhoneNumber('');
      expect(emptyResult.isValid, false);
      expect(emptyResult.errorMessage, 'Phone number is required');

      final invalidResult = ValidationUtils.validatePhoneNumber('abc');
      expect(invalidResult.isValid, false);
      expect(invalidResult.errorMessage, 'Please enter a valid phone number');
    });
  });

  group('URL Validation', () {
    test('should validate correct URLs', () {
      expect(ValidationUtils.isValidUrl('https://example.com'), true);
      expect(ValidationUtils.isValidUrl('http://example.com'), true);
      expect(ValidationUtils.isValidUrl('example.com'), true);
      expect(ValidationUtils.isValidUrl('www.example.com'), true);
      expect(ValidationUtils.isValidUrl('https://example.com/path'), true);
      expect(ValidationUtils.isValidUrl('https://example.com/path/to/page'), true);
    });

    test('should reject invalid URLs', () {
      expect(ValidationUtils.isValidUrl(''), false);
      expect(ValidationUtils.isValidUrl(null), false);
      expect(ValidationUtils.isValidUrl('invalid'), false);
      expect(ValidationUtils.isValidUrl('ftp://invalid'), false);
    });

    test('should handle whitespace', () {
      expect(ValidationUtils.isValidUrl('  https://example.com  '), true);
    });

    test('validateUrl should return detailed result', () {
      final validResult = ValidationUtils.validateUrl('https://example.com');
      expect(validResult.isValid, true);

      final emptyResult = ValidationUtils.validateUrl('');
      expect(emptyResult.isValid, false);
      expect(emptyResult.errorMessage, 'URL is required');

      final invalidResult = ValidationUtils.validateUrl('not-a-url');
      expect(invalidResult.isValid, false);
      expect(invalidResult.errorMessage, 'Please enter a valid URL');
    });
  });

  group('Number Validation', () {
    test('should validate valid numbers', () {
      expect(ValidationUtils.isValidNumber('42'), true);
      expect(ValidationUtils.isValidNumber('3.14'), true);
      expect(ValidationUtils.isValidNumber('-10'), true);
      expect(ValidationUtils.isValidNumber('0'), true);
      expect(ValidationUtils.isValidNumber('1e10'), true);
    });

    test('should reject invalid numbers', () {
      expect(ValidationUtils.isValidNumber(''), false);
      expect(ValidationUtils.isValidNumber(null), false);
      expect(ValidationUtils.isValidNumber('abc'), false);
      expect(ValidationUtils.isValidNumber('12.34.56'), false);
    });

    test('should validate integers', () {
      expect(ValidationUtils.isValidInteger('42'), true);
      expect(ValidationUtils.isValidInteger('-10'), true);
      expect(ValidationUtils.isValidInteger('0'), true);
      expect(ValidationUtils.isValidInteger('3.14'), false);
    });

    test('should validate number in range', () {
      expect(ValidationUtils.isValidNumberInRange('50', min: 0, max: 100), true);
      expect(ValidationUtils.isValidNumberInRange('0', min: 0, max: 100), true);
      expect(ValidationUtils.isValidNumberInRange('100', min: 0, max: 100), true);
      expect(ValidationUtils.isValidNumberInRange('-1', min: 0, max: 100), false);
      expect(ValidationUtils.isValidNumberInRange('101', min: 0, max: 100), false);
    });

    test('should validate integer in range', () {
      expect(ValidationUtils.isValidIntegerInRange('50', min: 0, max: 100), true);
      expect(ValidationUtils.isValidIntegerInRange('-1', min: 0, max: 100), false);
      expect(ValidationUtils.isValidIntegerInRange('3.14', min: 0, max: 100), false);
    });

    test('validateNumber should return detailed result', () {
      final validResult = ValidationUtils.validateNumber('42');
      expect(validResult.isValid, true);

      final emptyResult = ValidationUtils.validateNumber('');
      expect(emptyResult.isValid, false);
      expect(emptyResult.errorMessage, 'Number is required');

      final invalidResult = ValidationUtils.validateNumber('abc');
      expect(invalidResult.isValid, false);
      expect(invalidResult.errorMessage, 'Please enter a valid number');

      final belowMinResult = ValidationUtils.validateNumber('5', min: 10);
      expect(belowMinResult.isValid, false);
      expect(belowMinResult.errorMessage, 'Number must be at least 10.0');

      final aboveMaxResult = ValidationUtils.validateNumber('150', max: 100);
      expect(aboveMaxResult.isValid, false);
      expect(aboveMaxResult.errorMessage, 'Number must be at most 100.0');
    });
  });

  group('Date Validation', () {
    test('should validate ISO date format', () {
      expect(ValidationUtils.isValidDate('2024-01-15'), true);
      expect(ValidationUtils.isValidDate('2024-12-31'), true);
    });

    test('should reject invalid dates', () {
      expect(ValidationUtils.isValidDate(''), false);
      expect(ValidationUtils.isValidDate(null), false);
      expect(ValidationUtils.isValidDate('invalid'), false);
      expect(ValidationUtils.isValidDate('2024-13-01'), false);
      expect(ValidationUtils.isValidDate('2024-01-32'), false);
    });

    test('should validate custom date formats', () {
      expect(ValidationUtils.isValidDate('01/15/2024', format: ValidationUtils.usDate), true);
      expect(ValidationUtils.isValidDate('15/01/2024', format: ValidationUtils.euDate), true);
    });

    test('should validate date in range', () {
      final minDate = DateTime(2024, 1, 1);
      final maxDate = DateTime(2024, 12, 31);

      expect(ValidationUtils.isValidDateInRange('2024-06-15', minDate: minDate, maxDate: maxDate), true);
      expect(ValidationUtils.isValidDateInRange('2023-12-31', minDate: minDate, maxDate: maxDate), false);
      expect(ValidationUtils.isValidDateInRange('2025-01-01', minDate: minDate, maxDate: maxDate), false);
    });

    test('validateDate should return detailed result', () {
      final validResult = ValidationUtils.validateDate('2024-01-15');
      expect(validResult.isValid, true);

      final emptyResult = ValidationUtils.validateDate('');
      expect(emptyResult.isValid, false);
      expect(emptyResult.errorMessage, 'Date is required');

      final invalidResult = ValidationUtils.validateDate('invalid');
      expect(invalidResult.isValid, false);
      expect(invalidResult.errorMessage, 'Please enter a valid date');
    });

    test('should parse date', () {
      final date = ValidationUtils.parseDate('2024-01-15');

      expect(date, isNotNull);
      expect(date!.year, 2024);
      expect(date.month, 1);
      expect(date.day, 15);
    });

    test('should format date', () {
      final date = DateTime(2024, 1, 15);
      final formatted = ValidationUtils.formatDate(date);

      expect(formatted, '2024-01-15');
    });
  });

  group('Time Validation', () {
    test('should validate time in 24h format', () {
      expect(ValidationUtils.isValidTime('14:30'), true);
      expect(ValidationUtils.isValidTime('00:00'), true);
      expect(ValidationUtils.isValidTime('23:59'), true);
    });

    test('should reject invalid times', () {
      expect(ValidationUtils.isValidTime(''), false);
      expect(ValidationUtils.isValidTime(null), false);
      expect(ValidationUtils.isValidTime('invalid'), false);
      expect(ValidationUtils.isValidTime('25:00'), false);
      expect(ValidationUtils.isValidTime('14:60'), false);
    });

    test('should validate time in 12h format', () {
      expect(ValidationUtils.isValidTime('02:30 PM', format: ValidationUtils.time12h), true);
      expect(ValidationUtils.isValidTime('12:00 AM', format: ValidationUtils.time12h), true);
    });
  });

  group('Required Field Validation', () {
    test('should validate non-empty strings', () {
      expect(ValidationUtils.isNotEmpty('value'), true);
      expect(ValidationUtils.isNotEmpty('  value  '), true);
    });

    test('should reject empty strings', () {
      expect(ValidationUtils.isNotEmpty(''), false);
      expect(ValidationUtils.isNotEmpty(null), false);
      expect(ValidationUtils.isNotEmpty('   '), false);
    });

    test('should validate non-null values', () {
      expect(ValidationUtils.isNotNull('value'), true);
      expect(ValidationUtils.isNotNull(42), true);
      expect(ValidationUtils.isNotNull(null), false);
    });

    test('validateRequired should return detailed result', () {
      final validResult = ValidationUtils.validateRequired('value');
      expect(validResult.isValid, true);

      final emptyResult = ValidationUtils.validateRequired('');
      expect(emptyResult.isValid, false);
      expect(emptyResult.errorMessage, 'This field is required');

      final customFieldResult = ValidationUtils.validateRequired('', fieldName: 'Name');
      expect(customFieldResult.errorMessage, 'Name is required');
    });
  });

  group('Length Validation', () {
    test('should validate length', () {
      expect(ValidationUtils.isValidLength('hello', minLength: 3), true);
      expect(ValidationUtils.isValidLength('hi', minLength: 3), false);
      expect(ValidationUtils.isValidLength('hello', maxLength: 10), true);
      expect(ValidationUtils.isValidLength('hello world', maxLength: 5), false);
      expect(ValidationUtils.isValidLength('hello', minLength: 3, maxLength: 10), true);
    });

    test('should handle null and empty strings', () {
      expect(ValidationUtils.isValidLength(null, minLength: 0), true);
      expect(ValidationUtils.isValidLength(null, minLength: 1), false);
      expect(ValidationUtils.isValidLength('', minLength: 0), true);
    });

    test('validateLength should return detailed result', () {
      final validResult = ValidationUtils.validateLength('hello', minLength: 3, maxLength: 10);
      expect(validResult.isValid, true);

      final tooShortResult = ValidationUtils.validateLength('hi', minLength: 3);
      expect(tooShortResult.isValid, false);
      expect(tooShortResult.errorMessage, 'This field must be at least 3 characters');

      final tooLongResult = ValidationUtils.validateLength('hello world', maxLength: 5);
      expect(tooLongResult.isValid, false);
      expect(tooLongResult.errorMessage, 'This field must be at most 5 characters');

      final customFieldResult = ValidationUtils.validateLength('hi', minLength: 3, fieldName: 'Name');
      expect(customFieldResult.errorMessage, 'Name must be at least 3 characters');
    });
  });

  group('Pattern Validation', () {
    test('should match string patterns', () {
      expect(ValidationUtils.matchesPattern('ABC123', r'^[A-Z]+[0-9]+$'), true);
      expect(ValidationUtils.matchesPattern('abc123', r'^[A-Z]+[0-9]+$'), false);
    });

    test('should match RegExp patterns', () {
      final pattern = RegExp(r'^\d{3}-\d{4}$');
      expect(ValidationUtils.matchesRegExp('123-4567', pattern), true);
      expect(ValidationUtils.matchesRegExp('1234567', pattern), false);
    });

    test('should handle empty strings', () {
      expect(ValidationUtils.matchesPattern('', r'.*'), false);
      expect(ValidationUtils.matchesPattern(null, r'.*'), false);
    });
  });

  group('Composite Validation', () {
    test('validateAll should return first failure', () {
      final validations = [
        const ValidationResult(true),
        const ValidationResult(false, 'First error'),
        const ValidationResult(false, 'Second error'),
      ];

      final result = ValidationUtils.validateAll(validations);

      expect(result.isValid, false);
      expect(result.errorMessage, 'First error');
    });

    test('validateAll should return success when all pass', () {
      final validations = [
        const ValidationResult(true),
        const ValidationResult(true),
        const ValidationResult(true),
      ];

      final result = ValidationUtils.validateAll(validations);

      expect(result.isValid, true);
    });
  });

  group('Validate By Type', () {
    test('should validate email type', () {
      final result = ValidationUtils.validateByType('test@example.com', fieldType: 'email');
      expect(result.isValid, true);

      final invalid = ValidationUtils.validateByType('invalid', fieldType: 'email');
      expect(invalid.isValid, false);
    });

    test('should validate phone type', () {
      final result = ValidationUtils.validateByType('+1234567890', fieldType: 'phone');
      expect(result.isValid, true);

      final mobile = ValidationUtils.validateByType('+1234567890', fieldType: 'mobile');
      expect(mobile.isValid, true);
    });

    test('should validate url type', () {
      final result = ValidationUtils.validateByType('https://example.com', fieldType: 'url');
      expect(result.isValid, true);

      final website = ValidationUtils.validateByType('https://example.com', fieldType: 'website');
      expect(website.isValid, true);
    });

    test('should validate number type', () {
      final result = ValidationUtils.validateByType('42', fieldType: 'number');
      expect(result.isValid, true);

      final numeric = ValidationUtils.validateByType('42', fieldType: 'numeric');
      expect(numeric.isValid, true);
    });

    test('should validate date type', () {
      final result = ValidationUtils.validateByType('2024-01-15', fieldType: 'date');
      expect(result.isValid, true);
    });

    test('should validate text/name type as required', () {
      final result = ValidationUtils.validateByType('John', fieldType: 'text');
      expect(result.isValid, true);

      final name = ValidationUtils.validateByType('John', fieldType: 'name');
      expect(name.isValid, true);

      final empty = ValidationUtils.validateByType('', fieldType: 'text');
      expect(empty.isValid, false);
    });

    test('should respect required flag', () {
      final optional = ValidationUtils.validateByType('', fieldType: 'email', required: false);
      expect(optional.isValid, true);

      final required = ValidationUtils.validateByType('', fieldType: 'email', required: true);
      expect(required.isValid, false);
    });
  });
}
