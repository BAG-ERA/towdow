// Test file for UsersApiService
// Tests the users API service functionality

import 'package:flutter_test/flutter_test.dart';
import '../../lib/data/models/user.dart';

void main() {
  group('UsersApiService Models', () {
    test('CurrentUser model can be created from JSON', () {
      final json = {
        'email': 'test@example.com',
        'name': 'Test User',
        'sub': 'user123',
        'role': ['user'],
        'locale': 'en',
      };

      final currentUser = CurrentUser.fromJson(json);
      
      expect(currentUser.email, equals('test@example.com'));
      expect(currentUser.name, equals('Test User'));
      expect(currentUser.sub, equals('user123'));
      expect(currentUser.role, equals(['user']));
      expect(currentUser.locale, equals('en'));
    });

    test('UserInfo model can be created from JSON', () {
      final json = {
        'id': 1,
        'isGuest': false,
        'homePath': '/home/test',
        'email': 'test@example.com',
        'kcId': 'kc123',
        'firstname': 'Test',
        'lastname': 'User',
      };

      final userInfo = UserInfo.fromJson(json);
      
      expect(userInfo.id, equals(1));
      expect(userInfo.isGuest, isFalse);
      expect(userInfo.homePath, equals('/home/test'));
      expect(userInfo.email, equals('test@example.com'));
      expect(userInfo.kcId, equals('kc123'));
      expect(userInfo.firstname, equals('Test'));
      expect(userInfo.lastname, equals('User'));
    });

    test('CurrentUser can be converted to JSON', () {
      final currentUser = CurrentUser(
        email: 'test@example.com',
        name: 'Test User',
        sub: 'user123',
        role: ['user'],
        locale: 'en',
      );

      final json = currentUser.toJson();
      
      expect(json['email'], equals('test@example.com'));
      expect(json['name'], equals('Test User'));
      expect(json['sub'], equals('user123'));
      expect(json['role'], equals(['user']));
      expect(json['locale'], equals('en'));
    });

    test('UserInfo can be converted to JSON', () {
      final userInfo = UserInfo(
        id: 1,
        isGuest: false,
        homePath: '/home/test',
        email: 'test@example.com',
        kcId: 'kc123',
        firstname: 'Test',
        lastname: 'User',
      );

      final json = userInfo.toJson();
      
      expect(json['id'], equals(1));
      expect(json['isGuest'], isFalse);
      expect(json['homePath'], equals('/home/test'));
      expect(json['email'], equals('test@example.com'));
      expect(json['kcId'], equals('kc123'));
      expect(json['firstname'], equals('Test'));
      expect(json['lastname'], equals('User'));
    });
  });
} 