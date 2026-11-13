import 'dart:io';

String? message(Object? error) => switch (error) {
  CertificateException e => e.message,
  HandshakeException e => e.message,
  SocketException e => e.message,
  _ => null,
};
