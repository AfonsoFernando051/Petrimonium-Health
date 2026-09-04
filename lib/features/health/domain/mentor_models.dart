/// Result of `POST /api/mentor/chat` — the shared Mentor endpoint used by
/// Academy and Wallet too. `sources` is the RAG citation list the design
/// calls "Fontes consultadas" under "Por que estou vendo isto?".
final class MentorReply {
  const MentorReply({
    required this.reply,
    required this.conversationId,
    required this.title,
    required this.sources,
  });

  factory MentorReply.fromJson(Map<String, dynamic> json) => MentorReply(
        reply: json['reply'] as String? ?? '',
        conversationId: (json['conversationId'] as num?)?.toInt(),
        title: json['title'] as String?,
        sources: ((json['sources'] as List?) ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
      );

  final String reply;
  final int? conversationId;
  final String? title;
  final List<String> sources;
}

enum ChatAuthor { mentor, user }

/// One bubble in the Mentor tab's transcript. `sources` and `whyOpen` only
/// apply to mentor replies — the "Por que estou vendo isto?" disclosure is
/// per-message, matching the prototype's `whyOpen` toggle.
final class ChatMessage {
  ChatMessage({
    required this.id,
    required this.author,
    required this.text,
    this.sources = const [],
    this.whyOpen = false,
  });

  final String id;
  final ChatAuthor author;
  final String text;
  final List<String> sources;
  bool whyOpen;
}
