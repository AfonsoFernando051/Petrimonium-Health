import 'package:flutter/material.dart';

import '../../../core/app/health_scope.dart';
import '../../../core/theme/health_theme.dart';
import '../../../core/widgets/health_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../health/domain/mentor_models.dart';
import '../../health/presentation/health_controller.dart';

/// `tabIsMentor` — the shared Mentor, wired to the real `POST /api/mentor/chat`
/// (also used by Academy/Wallet). RAG citations (`sources`) render under the
/// "Por que estou vendo isto?" disclosure, per-message, matching the PRD's
/// "toda recomendação tem affordance por que estou vendo isto" guardrail.
class MentorScreen extends StatefulWidget {
  const MentorScreen({super.key});

  @override
  State<MentorScreen> createState() => _MentorScreenState();
}

class _MentorScreenState extends State<MentorScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _requestedSuggestions = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(HealthController controller, [String? text]) {
    final message = text ?? _inputController.text;
    if (message.trim().isEmpty) return;
    _inputController.clear();
    controller.sendMentorMessage(message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = HealthScope.of(context);
    final l10n = AppLocalizations.of(context);

    if (!_requestedSuggestions) {
      _requestedSuggestions = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.loadMentorSuggestions());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        children: [
          _MentorHeader(controller: controller, l10n: l10n),
          Expanded(
            child: controller.mentorMessages.isEmpty
                ? _EmptyState(controller: controller, l10n: l10n, onSend: (text) => _send(controller, text))
                : _Transcript(controller: controller, scrollController: _scrollController),
          ),
          if (controller.mentorError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(l10n.mentorSendError, style: const TextStyle(fontSize: 12, color: HealthColors.negative)),
            ),
          _InputBar(controller: _inputController, l10n: l10n, busy: controller.mentorBusy, onSend: () => _send(controller)),
        ],
      ),
    );
  }
}

class _MentorHeader extends StatelessWidget {
  const _MentorHeader({required this.controller, required this.l10n});

  final HealthController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: HealthColors.inputFill,
        border: Border.all(color: HealthColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Color(0x38C5ABFF), Color(0x14C1502E), Colors.transparent]),
            ),
            alignment: Alignment.center,
            child: ClipOval(child: Image.asset('assets/pets/fox.png', width: 40, height: 40, fit: BoxFit.contain)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.mentorLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: HealthColors.textPrimary)),
                const SizedBox(height: 1),
                Text(l10n.mentorSubtitle, style: const TextStyle(fontSize: 11, color: HealthColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.mentorNewChat,
            onPressed: controller.startNewMentorConversation,
            icon: const Icon(Icons.edit_outlined, size: 18, color: HealthColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.controller, required this.l10n, required this.onSend});

  final HealthController controller;
  final AppLocalizations l10n;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Color(0x38C5ABFF), Color(0x14C1502E), Colors.transparent]),
            ),
            alignment: Alignment.center,
            child: ClipOval(child: Image.asset('assets/pets/fox.png', width: 40, height: 40, fit: BoxFit.contain)),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.mentorEmptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HealthColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.mentorEmptySubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: HealthColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: controller.mentorSuggestions.map((prompt) {
              return GestureDetector(
                onTap: () => onSend(prompt),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: HealthColors.textPrimary.withValues(alpha: .14)),
                  ),
                  child: Text(prompt, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: HealthColors.textPrimary)),
                ),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({required this.controller, required this.scrollController});

  final HealthController controller;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
      itemCount: controller.mentorMessages.length + (controller.mentorBusy ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= controller.mentorMessages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        final message = controller.mentorMessages[index];
        final isUser = message.author == ChatAuthor.user;
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? Theme.of(context).colorScheme.primary : HealthColors.inputFill,
                border: isUser ? null : Border.all(color: HealthColors.border),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser) ...[
                    ProvenanceBadge(
                      label: l10n.mentorAiLabel,
                      color: HealthColors.mentorAccent,
                      tint: HealthColors.mentorTint,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    message.text,
                    style: TextStyle(fontSize: 14, height: 1.4, color: isUser ? Colors.white : HealthColors.textPrimary),
                  ),
                  if (!isUser && message.sources.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => controller.toggleMessageWhy(message.id),
                      child: Text(
                        l10n.mentorInsightWhy,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    if (message.whyOpen) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.only(top: 8),
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: HealthColors.border))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.mentorWhySourcesTitle.toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: HealthColors.textMuted),
                            ),
                            const SizedBox(height: 6),
                            ...message.sources.map((source) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 6, right: 6),
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(source, style: const TextStyle(fontSize: 11, color: HealthColors.textSecondary)),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.l10n, required this.busy, required this.onSend});

  final TextEditingController controller;
  final AppLocalizations l10n;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: HealthColors.inputFill,
        border: Border.all(color: HealthColors.border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: l10n.mentorInputHint,
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14, color: HealthColors.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: busy ? null : onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_upward_rounded, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
