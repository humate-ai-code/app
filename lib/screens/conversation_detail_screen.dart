import 'package:flutter/material.dart';
import 'package:flutter_app/models/conversation_model.dart';
import 'package:flutter_app/models/speaker_model.dart';
import 'package:flutter_app/services/conversation_repository.dart';
import 'package:flutter_app/services/speaker_repository.dart';
import 'package:flutter_app/theme/app_theme.dart';
import 'package:audioplayers/audioplayers.dart';

class ConversationDetailScreen extends StatefulWidget {
  final ConversationThread thread;
  final String? initialMessageId;

  const ConversationDetailScreen({super.key, required this.thread, this.initialMessageId});

  @override
  State<ConversationDetailScreen> createState() => _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;

  // Track the index to scroll to
  int _lastAutoScrolledIndex = -1;

  @override
  void initState() {
    super.initState();
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() {
            _currentPosition = p;
            _handleAutoScroll();
        });
      }
    });
  }
  
  @override
  void didChangeDependencies() {
      super.didChangeDependencies();
      // Handle initial scroll if provided
      if (widget.initialMessageId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
               // We need to wait for list to render
               // A simple delay or relying on keys
               Future.delayed(const Duration(milliseconds: 500), () {
                   if (_messageKeys.containsKey(widget.initialMessageId)) {
                       _scrollToKey(_messageKeys[widget.initialMessageId]);
                       // Also highlight?
                   }
               });
          });
      }
  }

  
  // Find which message is active and scroll to it if needed
  void _handleAutoScroll() {
       if (!_isPlaying) return;

       // We need access to the messages. 
       // Ideally we cache them or access via widget if static, but they come from stream.
       // For now, let's grab from repo directly since this is simple
       final thread = ConversationRepository().currentThreads.firstWhere((t) => t.id == widget.thread.id, orElse: () => widget.thread);
       final messages = thread.messages;

       for (int i = 0; i < messages.length; i++) {
            final msg = messages[i];
            if (msg.audioStartTime != null && msg.audioEndTime != null) {
                if (_currentPosition >= msg.audioStartTime! && _currentPosition <= msg.audioEndTime!) {
                    // This is the active message
                    if (_lastAutoScrolledIndex != i) {
                        _scrollToIndex(i);
                        _lastAutoScrolledIndex = i;
                    }
                    break;
                }
            }
       }
  }

  void _scrollToIndex(int index) {
      // Assuming item extent or approximate
      // A safer way in ListView is using a key or external package, but let's try basic arithmetic or EnsureVisible packages.
      // Since we don't have scroll_to_index package, we'll try to scroll based on estimated offset or just jump to bottom if it's new.
      // Wait, standard ListView doesn't support scrollToIndex easily without a package.
      // Let's try to animate to a specific offset if we can calculate it, or just keep it simple:
      // Actually, auto-scrolling to a specific item in a variable height list is hard without keys.
      // Let's rely on the user manually scrolling for now UNLESS the user explicitly asked for "screen follows".
      // "screen glides down".
      // We can try to scroll to the bottom if the playing message is the last one?
      // Or we can try to estimate.
      
      // Better approach: calculate offset? No, items have variable height.
      // Let's assume the list is built. We can use GlobalKeys for each item!
      
      // Implementing GlobalKey approach is reliable.
  }
  
  // Map to store keys
  final Map<String, GlobalKey> _messageKeys = {};

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _togglePlay(String? filePath) async {
      if (filePath == null) return;
      
      if (_isPlaying) {
          await _audioPlayer.pause();
      } else {
          debugPrint("DetailScreen: Playing from $filePath");
          // Play from file
          await _audioPlayer.play(DeviceFileSource(filePath));
      }
  }

  Future<void> _seekToMessage(ConversationMessage msg) async {
      debugPrint("DetailScreen: Seek requested to ${msg.audioStartTime}");
      if (msg.audioStartTime != null && widget.thread.audioFilePath != null) {
          // If not playing, start playing
          if (!_isPlaying) {
             await _audioPlayer.play(DeviceFileSource(widget.thread.audioFilePath!));
          }
          await _audioPlayer.seek(msg.audioStartTime!);
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.thread.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
            if (!widget.thread.isActive && widget.thread.audioFilePath != null)
                IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: () => _togglePlay(widget.thread.audioFilePath),
                ),
        ],
      ),
      body: StreamBuilder<List<ConversationThread>>(
        stream: ConversationRepository().threadsStream,
        initialData: ConversationRepository().currentThreads,
        builder: (context, snapshot) {
          final threads = snapshot.data ?? [];
          final currentThread = threads.firstWhere(
            (t) => t.id == widget.thread.id, 
            orElse: () => widget.thread
          );
          
          final messages = currentThread.messages;

          return Column(
             children: [
                 if (currentThread.summary != null)
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: AppColors.purpleAccent.withValues(alpha: 0.1),
                        child: Text(
                             "SUMMARY: ${currentThread.summary}",
                             style: TextStyle(color: AppColors.purpleAccent, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                    ),
                 Expanded(
                   child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + 1, // +1 for spacer at bottom
                    itemBuilder: (context, index) {
                      if (index == messages.length) return const SizedBox(height: 100);
                      final msg = messages[index];
                      // Highlight if it matches initial ID
                      final isTarget = widget.initialMessageId == msg.id;
                      return _buildMessageBubble(msg, forceHighlight: isTarget);
                    },
                   ),
                 ),
             ],
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(ConversationMessage msg, {bool forceHighlight = false}) {

    if (!_messageKeys.containsKey(msg.id)) {
        _messageKeys[msg.id] = GlobalKey();
    }
    final key = _messageKeys[msg.id];

    final isSystem = msg.sender == 'System';
    
    // Resolve Speaker
    Speaker? speaker;
    if (msg.speakerId != null) {
        speaker = SpeakerRepository().getSpeaker(msg.speakerId);
    }
    
    final isUser = speaker?.isUser ?? false;
    final displayName = speaker?.name ?? msg.sender;
    
    // Check for highlight
    bool isHighlighted = false;
    // Buffer the window slightly (e.g. +200ms) to ensure smooth transition
    if (_isPlaying && !isSystem && msg.audioStartTime != null && msg.audioEndTime != null) {
        if (_currentPosition >= msg.audioStartTime! && _currentPosition <= msg.audioEndTime! + const Duration(milliseconds: 200)) {
            isHighlighted = true;
            _scrollToKey(key); 
        }
    }
    
    // Color Logic
    Color bubbleColor;
    if (isSystem) {
        bubbleColor = AppColors.cardBackground.withValues(alpha: 0.5);
    } else if (isUser) {
        bubbleColor = AppColors.cyanAccent.withValues(alpha: 0.2); // User Color
    } else {
        // Deterministic color for other speakers
        if (speaker != null) {
            // Hash the ID to get a color hue?
            // Simple approach: predefined colors based on hash
            final hash = speaker.id.hashCode;
            final hue = (hash % 360).toDouble();
            final hsl = HSLColor.fromAHSL(1.0, hue, 0.6, 0.4); // Darkish
            bubbleColor = hsl.toColor().withValues(alpha: 0.3);
        } else {
            bubbleColor = AppColors.cyanAccent.withValues(alpha: 0.1); // Default
        }
    }
    
    if (isHighlighted || forceHighlight) {
        bubbleColor = bubbleColor.withValues(alpha: 0.6); // Highlight brighter
    }

    return Align(
      key: key,
      alignment: isSystem 
          ? Alignment.center 
          : isUser 
              ? Alignment.centerRight 
              : Alignment.centerLeft,
      child: GestureDetector(
      onLongPress: () => _showMessageOptions(context, msg, speaker),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: isUser ? const Radius.circular(12) : const Radius.circular(2),
              bottomRight: isUser ? const Radius.circular(2) : const Radius.circular(12),
          ),
          border: Border.all(
             color: isSystem ? Colors.transparent : AppColors.cyanAccent.withValues(alpha: 0.3),
             width: (isHighlighted || forceHighlight) ? 2.0 : 1.0, 
          ),
          boxShadow: isHighlighted ? [
              BoxShadow(
                  color: AppColors.cyanAccent.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 2,
              )
          ] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isSystem)
              Text(
                displayName,
                style: TextStyle(
                  color: AppColors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            if (!isSystem) const SizedBox(height: 4),
            Text(
              msg.text,
              style: TextStyle(
                color: isSystem ? AppColors.textSecondary : Colors.white,
                fontStyle: isSystem ? FontStyle.italic : FontStyle.normal,
              ),
            ),
             if (msg.audioStartTime != null && !isSystem)
               Text(
                 "${msg.audioStartTime!.inSeconds}s",
                 style: TextStyle(fontSize: 8, color: Colors.grey),
               ),
          ],
        ),
      ),
      ),
    );
  }
  
  void _showMessageOptions(BuildContext context, ConversationMessage msg, Speaker? speaker) {
      showModalBottomSheet(
          context: context,
          builder: (context) {
              return Wrap(
                  children: [
                      ListTile(
                          leading: const Icon(Icons.play_circle_outline),
                          title: const Text('Play from here'),
                          onTap: () {
                              Navigator.pop(context);
                              _seekToMessage(msg);
                          },
                      ),
                      if (speaker != null) ...[
                          const Divider(),
                          ListTile(
                              leading: const Icon(Icons.edit),
                              title: const Text('Rename Speaker'),
                              onTap: () {
                                  Navigator.pop(context);
                                  _showRenameDialog(context, speaker);
                              },
                          ),
                          ListTile(
                              leading: const Icon(Icons.person),
                              title: const Text('This is Me'),
                              subtitle: Text(speaker.isUser ? "Currently set as you" : "Set this speaker as you"),
                              onTap: () async {
                                  await SpeakerRepository().setAsUser(speaker.id);
                                  if (context.mounted) {
                                      Navigator.pop(context);
                                      // Refresh UI
                                      setState(() {});
                                  }
                              },
                          ),
                      ],
                  ],
              );
          }
      );
  }
  
  void _showRenameDialog(BuildContext context, Speaker speaker) {
      final controller = TextEditingController(text: speaker.name);
      showDialog(
          context: context, 
          builder: (context) {
              return AlertDialog(
                  title: const Text("Rename Speaker"),
                  content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(labelText: "Name"),
                  ),
                  actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                      ),
                      TextButton(
                          onPressed: () async {
                              if (controller.text.isNotEmpty) {
                                  await SpeakerRepository().updateSpeakerName(speaker.id, controller.text);
                                  if (mounted) setState(() {});
                              }
                              if (context.mounted) Navigator.pop(context);
                          },
                          child: const Text("Save"),
                      ),
                  ],
              );
          }
      );
  }
  
  void _scrollToKey(GlobalKey? key) {
      if (key == null) return;
      final context = key.currentContext;
      if (context != null) {
          // Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 300), alignment: 0.5);
          // Alignment 0.5 means center of viewport? 
          // User asked for "appears at the bottom ... then screen glides down".
          // Alignment 1.0 is bottom.
          Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut, alignment: 0.8);
      }
  }
}
