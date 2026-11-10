// What the providers need of the machine: asking an upstream for its
// models, the local proxy, and the environment a session on a provider
// starts with. None of it on the web.

import 'codex/codex_service.dart';
import 'image_api.dart';
import 'model_provider.dart';
import 'model_runtime_stub.dart'
    if (dart.library.io) 'model_runtime_io.dart'
    as platform;
import 'upstream.dart';

/// [provider]'s models, as it lists them (`GET /v1/models`), asked with
/// [key]. Throws [UpstreamException].
Future<List<RemoteModel>> listUpstreamModels(
  ModelProvider provider,
  String? key,
) => platform.listUpstreamModels(provider, key);

/// The environment (Claude Code's `--settings` `env`) for a session on
/// [provider] that asks for [model] ([requestedModel]): the proxy started
/// for it, if it needs one, and its key read.
Future<Map<String, String>> providerLaunchEnvironment(
  ModelProvider provider,
  String model,
) => platform.providerLaunchEnvironment(provider, model);

/// [request]'s pictures, made by [model] (an image model) of [provider]:
/// the bytes of each (fetched where it answered with a link). Throws
/// [UpstreamException].
Future<List<GeneratedImage>> generateImages(
  ModelProvider provider,
  ProviderModel model,
  ImageRequest request, {
  String? session,
}) => platform.generateImages(provider, model, request, session: session);

/// Asks [model] (a provider's, [modelRef], as [ModelProviders.compaction]
/// names it) [messages] after [system], through the local proxy, its
/// answer streamed: [onText] has each piece of its text as it comes. The call is
/// kept (Settings → Usage) as a [requestClass] one, under the conversation
/// [session]. Completing [cancel] gives it up, and it then throws
/// [ModelCallCancelled]; it throws [UpstreamException] for no answer.
Future<ModelAnswer> askModel(
  String model, {
  required String system,
  required List<Map<String, Object?>> messages,
  int maxTokens = 20000,
  String? requestClass,
  String? session,
  void Function(String text)? onText,
  Future<void>? cancel,
}) => platform.askModel(
  model,
  system: system,
  messages: messages,
  maxTokens: maxTokens,
  requestClass: requestClass,
  session: session,
  onText: onText,
  cancel: cancel,
);

/// What [askModel] was answered.
class ModelAnswer {
  const ModelAnswer(this.text, {this.inputTokens, this.outputTokens});

  final String text;

  /// As the upstream counted them, if it did.
  final int? inputTokens;
  final int? outputTokens;
}

class ModelCallCancelled implements Exception {
  const ModelCallCancelled();
}

/// The ChatGPT (Codex) providers' accounts: signing in, their quota.
CodexService get codexService => platform.codexService;

/// Stops the local proxy, as the app quits.
Future<void> stopModelProxy() => platform.stopModelProxy();

class UpstreamException implements Exception {
  const UpstreamException(this.message);

  final String message;

  @override
  String toString() => message;
}
