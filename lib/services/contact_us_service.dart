import 'package:dio/dio.dart';

class ContactUsSubmission {
  final String name;
  final String email;
  final String company;

  const ContactUsSubmission({
    required this.name,
    required this.email,
    this.company = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'company': company,
      };
}

class ContactUsService {
  static const String _endpoint =
      'http://167.172.125.207:8086/api/contact-us-messages';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  static Future<void> submitUpgradeRequest(ContactUsSubmission submission) async {
    try {
      final response = await _dio.post(
        _endpoint,
        data: submission.toJson(),
      );

      final statusCode = response.statusCode ?? 0;
      if (statusCode == 200 || statusCode == 201) {
        return;
      }

      throw Exception(_messageFromResponse(response));
    } on DioException catch (e) {
      final response = e.response;
      if (response != null) {
        throw Exception(_messageFromResponse(response));
      }
      throw Exception('Unable to reach the server. Check your connection and try again.');
    }
  }

  static String _messageFromResponse(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final errors = data['errors'];
      if (errors is Map<String, dynamic>) {
        final messages = <String>[];
        for (final entry in errors.entries) {
          final value = entry.value;
          if (value is List && value.isNotEmpty) {
            messages.add(value.first.toString());
          }
        }
        if (messages.isNotEmpty) {
          return messages.join('\n');
        }
      }

      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }

    return 'Something went wrong. Please try again.';
  }
}
