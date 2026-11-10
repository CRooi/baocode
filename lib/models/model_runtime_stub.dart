import 'codex/codex_service.dart';
import 'image_api.dart';
import 'model_provider.dart';
import 'model_runtime.dart';
import 'upstream.dart';

Future<List<RemoteModel>> listUpstreamModels(
  ModelProvider provider,
  String? key,
) async => throw const UpstreamException('Not available on the web.');

Future<Map<String, String>> providerLaunchEnvironment(
  ModelProvider provider,
  String model,
) async => throw const UpstreamException('Not available on the web.');

Future<List<GeneratedImage>> generateImages(
  ModelProvider provider,
  ProviderModel model,
  ImageRequest request, {
  String? session,
}) async => throw const UpstreamException('Not available on the web.');

Future<ModelAnswer> askModel(
  String model, {
  required String system,
  required List<Map<String, Object?>> messages,
  int maxTokens = 20000,
  String? requestClass,
  String? session,
  void Function(String text)? onText,
  Future<void>? cancel,
}) async => throw const UpstreamException('Not available on the web.');

Future<void> stopModelProxy() async {}

final CodexService codexService = CodexUnavailable();
