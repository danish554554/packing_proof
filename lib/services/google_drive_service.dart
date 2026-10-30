import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../controllers/recording_controller.dart';
import 'google_auth_service.dart';

class GoogleDriveService {
  GoogleDriveService(this._authService);

  final GoogleAuthService _authService;

  static const String _filesBaseUrl =
      'https://www.googleapis.com/drive/v3/files';
  static const String _uploadBaseUrl =
      'https://www.googleapis.com/upload/drive/v3/files';

  Future<String> _requireAccessToken() async {
    String? token = await _authService.getAccessToken();
    if (token == null || token.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 1500));
      token = await _authService.getAccessToken();
    }
    if (token == null || token.isEmpty) {
      throw Exception('Google Drive access token not available. Please connect Google Drive in Settings.');
    }
    return token;
  }

  Future<String> createDriveFolderStructure({
    required String orderId,
  }) async {
    final String accessToken = await _requireAccessToken();

    return _ensureOrderFolderInTodayPath(
      accessToken: accessToken,
      orderId: orderId,
    );
  }

  Future<String?> findExistingOrderFolderId({
    required String orderId,
  }) async {
    final String accessToken = await _requireAccessToken();

    final String rootFolderId = await _findOrCreateFolder(
      accessToken: accessToken,
      folderName: 'PackProof',
    );

    final List<_DriveFolderRef> dateFolders = await _listChildFolders(
      accessToken: accessToken,
      parentFolderId: rootFolderId,
    );

    dateFolders.sort((a, b) => b.name.compareTo(a.name));

    for (final dateFolder in dateFolders) {
      final existingFolderId = await _findFolderId(
        accessToken: accessToken,
        folderName: orderId,
        parentFolderId: dateFolder.id,
      );

      if (existingFolderId != null && existingFolderId.isNotEmpty) {
        return existingFolderId;
      }
    }

    return null;
  }

  Future<String> resolveOrderFolderId({
    required String orderId,
    required RecordingFlowType flowType,
  }) async {
    final String accessToken = await _requireAccessToken();

    if (flowType == RecordingFlowType.returnRecording) {
      final existingFolderId = await findExistingOrderFolderId(orderId: orderId);
      if (existingFolderId == null) {
        throw Exception(
          'No existing Google Drive folder was found for tracking ID "$orderId". Record packing first, or make sure the original folder already exists in PackProof.',
        );
      }
      return existingFolderId;
    }

    return _ensureOrderFolderInTodayPath(
      accessToken: accessToken,
      orderId: orderId,
    );
  }

  Future<DriveUploadResult> uploadVideo({
    required String orderId,
    required String filePath,
    required RecordingFlowType flowType,
    String? existingFolderId,
  }) async {
    final String accessToken = await _requireAccessToken();

    final File videoFile = File(filePath);

    if (!await videoFile.exists()) {
      throw Exception('Recorded video file not found.');
    }

    final String targetFolderId = existingFolderId ??
        await resolveOrderFolderId(orderId: orderId, flowType: flowType);

    final String extension = _getFileExtension(videoFile.path);
    final String mimeType = _getVideoMimeType(extension);
    final MediaType mediaType = _toMediaType(mimeType);

    final String fileName = _buildDriveVideoFileName(
      orderId,
      flowType: flowType,
      extension: extension,
    );

    final Uri uri = Uri.parse(
      '$_uploadBaseUrl?uploadType=multipart&fields=id,name,webViewLink',
    );

    final http.MultipartRequest request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $accessToken';

    request.files.add(
      http.MultipartFile.fromString(
        'metadata',
        jsonEncode(<String, dynamic>{
          'name': fileName,
          'parents': <String>[targetFolderId],
        }),
        contentType: MediaType('application', 'json'),
      ),
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        videoFile.path,
        filename: fileName,
        contentType: mediaType,
      ),
    );

    final http.StreamedResponse streamedResponse = await request.send();
    final http.Response response = await http.Response.fromStream(
      streamedResponse,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Drive upload failed: ${response.statusCode} ${response.body}',
      );
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    final String? fileId = body['id'] as String?;
    final String? uploadedName = body['name'] as String?;
    final String? webViewLink = body['webViewLink'] as String?;

    if (fileId == null || fileId.isEmpty) {
      throw Exception('Drive file ID missing after upload.');
    }

    return DriveUploadResult(
      fileId: fileId,
      fileName: uploadedName ?? fileName,
      folderId: targetFolderId,
      webViewLink: webViewLink,
    );
  }

  Future<String> _ensureOrderFolderInTodayPath({
    required String accessToken,
    required String orderId,
  }) async {
    final String rootFolderId = await _findOrCreateFolder(
      accessToken: accessToken,
      folderName: 'PackProof',
    );

    final String todayFolderName = _formatTodayFolderName();

    final String dateFolderId = await _findOrCreateFolder(
      accessToken: accessToken,
      folderName: todayFolderName,
      parentFolderId: rootFolderId,
    );

    final String orderFolderId = await _findOrCreateFolder(
      accessToken: accessToken,
      folderName: orderId,
      parentFolderId: dateFolderId,
    );

    return orderFolderId;
  }

  Future<List<_DriveFolderRef>> _listChildFolders({
    required String accessToken,
    required String parentFolderId,
  }) async {
    final String query =
        "'$parentFolderId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false";

    final Uri uri = Uri.parse(_filesBaseUrl).replace(
      queryParameters: <String, String>{
        'q': query,
        'spaces': 'drive',
        'pageSize': '1000',
        'fields': 'files(id,name)',
      },
    );

    final http.Response response = await http.get(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to list Drive folders: ${response.statusCode} ${response.body}',
      );
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> files = body['files'] as List<dynamic>? ?? <dynamic>[];

    return files
        .map(
          (file) => _DriveFolderRef(
            id: (file as Map<String, dynamic>)['id'] as String? ?? '',
            name: file['name'] as String? ?? '',
          ),
        )
        .where((folder) => folder.id.isNotEmpty)
        .toList();
  }

  Future<String> _findOrCreateFolder({
    required String accessToken,
    required String folderName,
    String? parentFolderId,
  }) async {
    final String? existingFolderId = await _findFolderId(
      accessToken: accessToken,
      folderName: folderName,
      parentFolderId: parentFolderId,
    );

    if (existingFolderId != null) {
      return existingFolderId;
    }

    return _createFolder(
      accessToken: accessToken,
      folderName: folderName,
      parentFolderId: parentFolderId,
    );
  }

  Future<String?> _findFolderId({
    required String accessToken,
    required String folderName,
    String? parentFolderId,
  }) async {
    String query =
        "name = '${_escapeGoogleQuery(folderName)}' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";

    if (parentFolderId != null && parentFolderId.isNotEmpty) {
      query += " and '$parentFolderId' in parents";
    }

    final Uri uri = Uri.parse(_filesBaseUrl).replace(
      queryParameters: <String, String>{
        'q': query,
        'spaces': 'drive',
        'fields': 'files(id,name)',
      },
    );

    final http.Response response = await http.get(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to search Drive folder: ${response.statusCode} ${response.body}',
      );
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    final List<dynamic> files = body['files'] as List<dynamic>? ?? <dynamic>[];

    if (files.isEmpty) {
      return null;
    }

    final Map<String, dynamic> firstFile =
        files.first as Map<String, dynamic>;

    return firstFile['id'] as String?;
  }

  Future<String> _createFolder({
    required String accessToken,
    required String folderName,
    String? parentFolderId,
  }) async {
    final Map<String, dynamic> metadata = <String, dynamic>{
      'name': folderName,
      'mimeType': 'application/vnd.google-apps.folder',
    };

    if (parentFolderId != null && parentFolderId.isNotEmpty) {
      metadata['parents'] = <String>[parentFolderId];
    }

    final Uri uri = Uri.parse(_filesBaseUrl);

    final http.Response response = await http.post(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(metadata),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Failed to create Drive folder: ${response.statusCode} ${response.body}',
      );
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    final String? folderId = body['id'] as String?;

    if (folderId == null || folderId.isEmpty) {
      throw Exception('Drive folder ID missing in response.');
    }

    return folderId;
  }

  String _formatTodayFolderName() {
    final DateTime now = DateTime.now();
    final String year = now.year.toString();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _buildDriveVideoFileName(
    String orderId, {
    required RecordingFlowType flowType,
    required String extension,
  }) {
    final DateTime now = DateTime.now();
    final String timestamp =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    return '${flowType.filePrefix}_${orderId}_$timestamp.$extension';
  }

  String _getFileExtension(String path) {
    final String fileName = path.split('/').last;
    if (!fileName.contains('.')) {
      return 'mp4';
    }

    final String ext = fileName.split('.').last.toLowerCase().trim();
    if (ext.isEmpty) {
      return 'mp4';
    }

    return ext;
  }

  String _getVideoMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case '3gp':
        return 'video/3gpp';
      case 'mkv':
        return 'video/x-matroska';
      case 'webm':
        return 'video/webm';
      default:
        return 'video/mp4';
    }
  }

  MediaType _toMediaType(String mimeType) {
    final List<String> parts = mimeType.split('/');
    if (parts.length != 2) {
      return MediaType('video', 'mp4');
    }
    return MediaType(parts[0], parts[1]);
  }

  String _escapeGoogleQuery(String input) {
    return input.replaceAll("'", r"\'");
  }
}

class DriveUploadResult {
  final String fileId;
  final String fileName;
  final String folderId;
  final String? webViewLink;

  DriveUploadResult({
    required this.fileId,
    required this.fileName,
    required this.folderId,
    this.webViewLink,
  });
}

class _DriveFolderRef {
  const _DriveFolderRef({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}
