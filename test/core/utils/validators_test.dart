import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('should reject null', () {
      expect(Validators.email(null), 'Email obrigatório');
    });

    test('should reject empty and whitespace-only values', () {
      expect(Validators.email(''), 'Email obrigatório');
      expect(Validators.email('   '), 'Email obrigatório');
    });

    test('should reject malformed emails', () {
      expect(Validators.email('invalid'), 'Email inválido');
      expect(Validators.email('invalid@'), 'Email inválido');
      expect(Validators.email('invalid@domain'), 'Email inválido');
      expect(Validators.email('invalid@domain.'), 'Email inválido');
    });

    test('should accept valid emails', () {
      expect(Validators.email('test@example.com'), isNull);
      expect(Validators.email('user.name+tag@sub.domain.com.br'), isNull);
    });

    test('should trim before validating', () {
      expect(Validators.email('  test@example.com  '), isNull);
    });
  });

  group('Validators.password', () {
    test('should reject null and empty values', () {
      expect(Validators.password(null), 'Senha obrigatória');
      expect(Validators.password(''), 'Senha obrigatória');
    });

    test('should reject passwords shorter than 6 characters', () {
      expect(Validators.password('12345'), 'Mínimo de 6 caracteres');
    });

    test('should accept passwords with 6 or more characters', () {
      expect(Validators.password('123456'), isNull);
      expect(Validators.password('a much longer password'), isNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('should return the password validation error first', () {
      expect(Validators.confirmPassword('', 'password'), 'Senha obrigatória');
      expect(
        Validators.confirmPassword('123', 'password'),
        'Mínimo de 6 caracteres',
      );
    });

    test('should reject when passwords do not match', () {
      expect(
        Validators.confirmPassword('password1', 'password2'),
        'Senhas não coincidem',
      );
    });

    test('should accept when passwords match', () {
      expect(Validators.confirmPassword('password', 'password'), isNull);
    });
  });
}
