// Mocks generated by Mockito 5.0.9 from annotations
// in adhoc_plugin/test/presentation/certificate_test.dart.
// Do not manually edit this file.

import 'dart:typed_data' as _i4;

import 'package:adhoc_plugin/src/presentation/key_mgnmt/certificate.dart'
    as _i3;
import 'package:mockito/mockito.dart' as _i1;
import 'package:pointycastle/asymmetric/api.dart' as _i2;

// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: comment_references
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis

class _FakeDateTime extends _i1.Fake implements DateTime {}

class _FakeRSAPublicKey extends _i1.Fake implements _i2.RSAPublicKey {}

/// A class which mocks [Certificate].
///
/// See the documentation for Mockito's code generation for more information.
class MockCertificate extends _i1.Mock implements _i3.Certificate {
  MockCertificate() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i4.Uint8List get signature =>
      (super.noSuchMethod(Invocation.getter(#signature),
          returnValue: _i4.Uint8List(0)) as _i4.Uint8List);
  @override
  set signature(_i4.Uint8List? _signature) =>
      super.noSuchMethod(Invocation.setter(#signature, _signature),
          returnValueForMissingStub: null);
  @override
  String get owner =>
      (super.noSuchMethod(Invocation.getter(#owner), returnValue: '')
          as String);
  @override
  String get issuer =>
      (super.noSuchMethod(Invocation.getter(#issuer), returnValue: '')
          as String);
  @override
  DateTime get validity => (super.noSuchMethod(Invocation.getter(#validity),
      returnValue: _FakeDateTime()) as DateTime);
  @override
  _i2.RSAPublicKey get key => (super.noSuchMethod(Invocation.getter(#key),
      returnValue: _FakeRSAPublicKey()) as _i2.RSAPublicKey);
  @override
  Map<String, dynamic> toJson() =>
      (super.noSuchMethod(Invocation.method(#toJson, []),
          returnValue: <String, dynamic>{}) as Map<String, dynamic>);
}
