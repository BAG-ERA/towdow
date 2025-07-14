import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'dart:typed_data';

const keycloakUrl = 'https://auth.towdow.app/realms/towdow/protocol/openid-connect/token';
const minioEndpoint = 'https://minio.towdow.app';
const bucketPrivate = 'towdow-private';
const bucketShared = 'towdow-shared';
const clientId = 'radicale-api';
const clientSecret = '';
const region = 'us-east-1';

Future<String> fetchJwt(String username, String password) async {
  final response = await http.post(
    Uri.parse(keycloakUrl),
    body: {
      'grant_type': 'password',
      'client_id': clientId,
      'client_secret': clientSecret,
      'username': username,
      'password': password,
    },
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to fetch JWT: ${response.body}');
  }

  return json.decode(response.body)['access_token'];
}

Map<String, dynamic> decodeJwt(String token) {
  final parts = token.split('.');
  String decode(String part) => utf8.decode(base64Url.decode(base64.normalize(part)));
  return json.decode(decode(parts[1]));
}

Future<Map<String, String>> getStsCredentials(String jwt) async {
  final url = Uri.parse('$minioEndpoint?Action=AssumeRoleWithWebIdentity&WebIdentityToken=$jwt&Version=2011-06-15');

  final response = await http.post(url);
  if (response.statusCode != 200) {
    throw Exception('STS request failed: ${response.body}');
  }

  final document = XmlDocument.parse(response.body);
  String getText(String tag) =>
      document.findAllElements(tag, namespace: '*').first.text;

  return {
    'accessKey': getText('AccessKeyId'),
    'secretKey': getText('SecretAccessKey'),
    'sessionToken': getText('SessionToken'),
  };
}

S3 createS3Client(Map<String, String> credentials) {
  final client = S3(
    region: region,
    credentials: AwsClientCredentials(
      accessKey: credentials['accessKey']!,
      secretKey: credentials['secretKey']!,
      sessionToken: credentials['sessionToken'],
    ),
    endpointUrl: minioEndpoint,
  );
  return client;
}

Future<void> listBuckets(S3 s3) async {
  final result = await s3.listBuckets();
  print('🪣 Buckets:');
  for (final bucket in result.buckets ?? []) {
    print(' - ${bucket.name}');
  }
}

Future<void> uploadObject(S3 s3, String bucket, String key, Uint8List content) async {
  await s3.putObject(
    bucket: bucket,
    key: key,
    body: content,
  );
  print('✅ Uploaded $key to $bucket');
}

Future<void> downloadObject(S3 s3, String bucket, String key) async {
  print("getting in bucket ${bucket} key ${key}");
  final result = await s3.getObject(bucket: bucket, key: key);
  final content = await result.body!.toList();
  print('📥 Downloaded: ${utf8.decode(content)}');
}

Future<void> main() async {
  final username = Platform.environment['USERNAME'];
  final password = Platform.environment['PASSWORD'];

  if (username == null || password == null) {
    print('❌ USERNAME and PASSWORD must be set as environment variables.');
    exit(1);
  }

  final jwt = await fetchJwt(username, password);
  final payload = decodeJwt(jwt);
  final sub = payload['sub'];
  print('🔐 Logged in as: $sub');

  final sts = await getStsCredentials(jwt);
  final s3 = createS3Client(sts);

  await listBuckets(s3);

  final uploadKey = '$sub/test_upload_dart.txt';
  await uploadObject(s3, bucketPrivate, uploadKey, utf8.encode('Hello from Dart via aws_s3_api'));
  await downloadObject(s3, bucketPrivate, uploadKey);

  await uploadObject(s3, bucketShared, uploadKey, utf8.encode('Hello from Dart via aws_s3_api in shared bucket'));
  await downloadObject(s3, bucketShared, uploadKey);
}