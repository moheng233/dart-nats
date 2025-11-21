/// SemVer version used by the server
class SemVer {
  const SemVer(this.major, this.minor, this.micro);
  final int major;
  final int minor;
  final int micro;

  @override
  String toString() => '$major.$minor.$micro';
}

/// Parse a semver string like "1.2.3" and return a [SemVer].
SemVer parseSemVer([String s = '']) {
  final m = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(s);
  if (m != null) {
    return SemVer(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }
  throw FormatException("'$s' is not a semver value");
}

/// Compare two semvers: -1 if a < b, 0 if equal, 1 if a > b.
int compare(SemVer a, SemVer b) {
  if (a.major < b.major) return -1;
  if (a.major > b.major) return 1;
  if (a.minor < b.minor) return -1;
  if (a.minor > b.minor) return 1;
  if (a.micro < b.micro) return -1;
  if (a.micro > b.micro) return 1;
  return 0;
}

/// Feature constants used for JetStream capability checks
class Feature {
  static const jsKv = 'js_kv';
  static const jsObjectStore = 'js_objectstore';
  static const jsPullMaxBytes = 'js_pull_max_bytes';
  static const jsNewConsumerCreateApi = 'js_new_consumer_create';
  static const jsAllowDirect = 'js_allow_direct';
  static const jsMultipleConsumerFilter = 'js_multiple_consumer_filter';
  static const jsSimplification = 'js_simplification';
  static const jsStreamConsumerMetadata = 'js_stream_consumer_metadata';
  static const jsConsumerFilterSubjects = 'js_consumer_filter_subjects';
  static const jsStreamFirstSeq = 'js_stream_first_seq';
  static const jsStreamSubjectTransform = 'js_stream_subject_transform';
  static const jsStreamSourceSubjectTransform =
      'js_stream_source_subject_transform';
  static const jsStreamCompression = 'js_stream_compression';
  static const jsDefaultConsumerLimits = 'js_default_consumer_limits';
  static const jsBatchDirectGet = 'js_batch_direct_get';
  static const jsPriorityGroups = 'js_priority_groups';
}

/// Feature version details
class FeatureVersion {
  const FeatureVersion({required this.ok, required this.min});
  final bool ok;
  final SemVer min;
}

/// Maintains current available features for a given server version
class Features {
  Features(SemVer v) {
    update(v);
  }
  late SemVer server;
  final Map<String, FeatureVersion> features = {};
  final List<String> disabled = [];

  /// Removes all disabled entries and recomputes features
  void resetDisabled() {
    disabled.clear();
    update(server);
  }

  /// Disables a particular feature
  void disable(String f) {
    disabled.add(f);
    update(server);
  }

  bool isDisabled(String f) => disabled.contains(f);

  /// Updates the server semver and recalculates feature availability.
  /// Updates the server semver and recalculates feature availability.
  void update(SemVer v) {
    server = v;
    set(Feature.jsKv, const SemVer(2, 6, 2));
    set(Feature.jsObjectStore, const SemVer(2, 6, 3));
    set(Feature.jsPullMaxBytes, const SemVer(2, 8, 3));
    set(Feature.jsNewConsumerCreateApi, const SemVer(2, 9, 0));
    set(Feature.jsAllowDirect, const SemVer(2, 9, 0));
    set(Feature.jsMultipleConsumerFilter, const SemVer(2, 10, 0));
    set(Feature.jsSimplification, const SemVer(2, 9, 4));
    set(Feature.jsStreamConsumerMetadata, const SemVer(2, 10, 0));
    set(Feature.jsConsumerFilterSubjects, const SemVer(2, 10, 0));
    set(Feature.jsStreamFirstSeq, const SemVer(2, 10, 0));
    set(Feature.jsStreamSubjectTransform, const SemVer(2, 10, 0));
    set(Feature.jsStreamSourceSubjectTransform, const SemVer(2, 10, 0));
    set(Feature.jsStreamCompression, const SemVer(2, 10, 0));
    set(Feature.jsDefaultConsumerLimits, const SemVer(2, 10, 0));
    set(Feature.jsBatchDirectGet, const SemVer(2, 11, 0));
    set(Feature.jsPriorityGroups, const SemVer(2, 11, 0));

    disabled.forEach(features.remove);
  }

  /// Register a feature and the minimum server version that enables it
  void set(String f, SemVer requires) {
    features[f] = FeatureVersion(
      min: requires,
      ok: compare(server, requires) >= 0,
    );
  }

  /// Returns whether the feature is available and the min server version
  FeatureVersion get(String f) =>
      features[f] ??
      const FeatureVersion(
        ok: false,
        min: SemVer(0, 0, 0),
      );

  /// Returns true if the feature is supported
  bool supports(String f) => get(f).ok;

  /// Returns true if server meets at least the specified version
  bool require(SemVer v) {
    return compare(server, v) >= 0;
  }
}
