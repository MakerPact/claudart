import 'dart:math';

/// Builds an IDF corpus from [documents]: `idf(t) = log(N / df(t))`, where
/// `df(t)` is the number of documents containing term `t` at least once
/// and `N` is the document count. Feed the result to [tfidfVector] so
/// terms common across the whole corpus (low signal) score lower than
/// terms unique to a few documents (high signal).
Map<String, double> buildIdfCorpus(List<String> documents) {
  final documentFrequency = <String, int>{};
  for (final doc in documents) {
    for (final term in _tokenize(doc).toSet()) {
      documentFrequency[term] = (documentFrequency[term] ?? 0) + 1;
    }
  }
  final n = documents.length;
  return {
    for (final entry in documentFrequency.entries)
      entry.key: log(n / entry.value),
  };
}

/// Computes a sparse TF-IDF vector for [text] using [idfCorpus].
/// Terms not in corpus receive IDF weight of 1.0.
Map<String, double> tfidfVector(String text, Map<String, double> idfCorpus) {
  final tokens = _tokenize(text);
  if (tokens.isEmpty) return {};

  final tf = <String, int>{};
  for (final t in tokens) {
    tf[t] = (tf[t] ?? 0) + 1;
  }

  final total = tokens.length;
  final vector = <String, double>{};
  for (final entry in tf.entries) {
    final termFreq = entry.value / total;
    final idf = idfCorpus[entry.key] ?? 1.0;
    final weight = termFreq * idf;
    if (weight > 0) vector[entry.key] = weight;
  }
  return vector;
}

/// Computes cosine similarity between two sparse vectors.
/// Returns 0.0 if either vector is empty.
double cosineSimilarity(Map<String, double> a, Map<String, double> b) {
  if (a.isEmpty || b.isEmpty) return 0.0;

  double dot = 0.0;
  for (final entry in a.entries) {
    final bVal = b[entry.key];
    if (bVal != null) dot += entry.value * bVal;
  }

  final magA = sqrt(a.values.fold(0.0, (s, v) => s + v * v));
  final magB = sqrt(b.values.fold(0.0, (s, v) => s + v * v));
  if (magA == 0 || magB == 0) return 0.0;

  return dot / (magA * magB);
}

/// Returns the top-[k] most relevant chunks from [chunks] for [query].
/// Uses TF-IDF vectors + cosine similarity. Chunks are plain text strings.
List<String> topKChunks(
  String query,
  List<String> chunks,
  int k,
  Map<String, double> corpus,
) {
  if (chunks.isEmpty) return [];
  final queryVec = tfidfVector(query, corpus);
  final scored = <(double, String)>[];

  for (final chunk in chunks) {
    final chunkVec = tfidfVector(chunk, corpus);
    final score = cosineSimilarity(queryVec, chunkVec);
    scored.add((score, chunk));
  }

  scored.sort((a, b) => b.$1.compareTo(a.$1));
  return scored.take(k).map((e) => e.$2).toList();
}

final _tokenPattern = RegExp(r'[^a-z0-9]+');

List<String> _tokenize(String text) {
  return text
      .toLowerCase()
      .split(_tokenPattern)
      .where((t) => t.length > 1)
      .toList();
}
