import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ChatScreen extends StatefulWidget {
  final String requestId;
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.requestId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Color bgTop     = Color(0xFF1A1A2E);
  static const Color kCardNavy = Color(0xFF16213E);
  static const Color kDeep     = Color(0xFF0F3460);
  static const Color kCyan     = Color(0xFF00FFB3);
  static const Color kBlue     = Color(0xFF00D4FF);
  static const Color kDark     = Color(0xFF0F0F1A);

  final TextEditingController _msgController = TextEditingController();
  final ScrollController      _scrollController = ScrollController();
  final String _currentUid =
      FirebaseAuth.instance.currentUser?.uid ?? '';

  bool    _isSending    = false;
  String? _driverPhotoUrl;          // ✅ real photo URL
  String  _driverDisplayName = '';  // ✅ real name
  bool    _profileLoaded = false;

  String get _chatPath => 'chats/${widget.requestId}';

  // ════════════════════════════════════════════════════════════════════
  // ✅ FETCH DRIVER PROFILE — tries users / drivers / Drivers nodes
  // ════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _loadDriverProfile();
  }

  Future<void> _loadDriverProfile() async {
    if (widget.otherUserId.isEmpty) {
      setState(() {
        _driverDisplayName = widget.otherUserName;
        _profileLoaded     = true;
      });
      return;
    }

    final nodesToTry = ['users', 'drivers', 'Drivers', 'Users'];

    for (final node in nodesToTry) {
      try {
        final snap = await FirebaseDatabase.instance
            .ref()
            .child('$node/${widget.otherUserId}')
            .get();

        if (snap.exists && snap.value != null) {
          final data = Map<String, dynamic>.from(snap.value as Map);

          final String name = data['name']?.toString()        ??
              data['fullName']?.toString()                    ??
              data['displayName']?.toString()                 ??
              data['userName']?.toString()                    ??
              data['driverName']?.toString()                  ??
              widget.otherUserName;

          final String? photo = data['photoUrl']?.toString()  ??
              data['profileImage']?.toString()                ??
              data['imageUrl']?.toString()                    ??
              data['photo']?.toString()                       ??
              data['profilePhoto']?.toString()                ??
              data['driverImage']?.toString();

          if (mounted) {
            setState(() {
              _driverDisplayName = name;
              _driverPhotoUrl    = (photo != null && photo.isNotEmpty)
                  ? photo : null;
              _profileLoaded     = true;
            });
          }
          return; // found — stop trying
        }
      } catch (_) {
        continue;
      }
    }

    // Fallback
    if (mounted) {
      setState(() {
        _driverDisplayName = widget.otherUserName;
        _profileLoaded     = true;
      });
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // SEND MESSAGE
  // ════════════════════════════════════════════════════════════════════
  Future<void> _sendMessage() async {
    final String text = _msgController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _msgController.clear();

    try {
      final ref = FirebaseDatabase.instance
          .ref()
          .child(_chatPath)
          .push();

      await ref.set({
        'messageId':  ref.key,
        'senderId':   _currentUid,
        'receiverId': widget.otherUserId,
        'text':       text,
        'timestamp':  DateTime.now().millisecondsSinceEpoch,
        'isRead':     false,
      });

      Future.delayed(const Duration(milliseconds: 200), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve:    Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('Send error: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _markAsRead(String messageId) {
    FirebaseDatabase.instance
        .ref()
        .child(_chatPath)
        .child(messageId)
        .update({'isRead': true});
  }

  String _formatTime(int timestamp) {
    final dt     = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour   = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  bool _isSameDay(int ts1, int ts2) {
    final d1 = DateTime.fromMillisecondsSinceEpoch(ts1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(ts2);
    return d1.year == d2.year &&
        d1.month == d2.month &&
        d1.day == d2.day;
  }

  String _dayLabel(int timestamp) {
    final dt        = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now       = DateTime.now();
    if (_isSameDay(timestamp, now.millisecondsSinceEpoch)) return 'Today';
    final yesterday =
        now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    if (_isSameDay(timestamp, yesterday)) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgTop,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(child: _buildMessageList()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // ✅ APP BAR — real driver photo + real name
  // ════════════════════════════════════════════════════════════════════
  Widget _buildAppBar() {
    final String displayName = _driverDisplayName.isNotEmpty
        ? _driverDisplayName
        : widget.otherUserName;
    final String initial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kDark,
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.4),
              blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          // Back
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),

          // ✅ Driver Avatar — real photo or initial fallback
          Container(
            width:  46,
            height: 46,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              border: Border.all(color: kCyan, width: 2),
              boxShadow: [
                BoxShadow(
                    color:      kCyan.withOpacity(0.3),
                    blurRadius: 8)
              ],
            ),
            child: ClipOval(child: _buildAvatar(46)),
          ),

          const SizedBox(width: 12),

          // ✅ Real driver name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _profileLoaded
                    ? Text(
                  displayName,
                  style: GoogleFonts.poppins(
                    color:      Colors.white,
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines:  1,
                  overflow:  TextOverflow.ellipsis,
                )
                    : _shimmerBar(width: 110, height: 14),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    width:  7,
                    height: 7,
                    decoration: const BoxDecoration(
                        color: kCyan, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  const Text('Online',
                      style: TextStyle(color: kCyan, fontSize: 11)),
                ]),
              ],
            ),
          ),

          // Ride chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:        kCyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(color: kCyan.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.directions_car, color: kCyan, size: 12),
              const SizedBox(width: 4),
              const Text('RIDE',
                  style: TextStyle(
                      color:      kCyan,
                      fontSize:   10,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // MESSAGE LIST
  // ════════════════════════════════════════════════════════════════════
  Widget _buildMessageList() {
    return StreamBuilder(
      stream: FirebaseDatabase.instance
          .ref()
          .child(_chatPath)
          .orderByChild('timestamp')
          .onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: kCyan));
        }

        if (!snap.hasData || snap.data!.snapshot.value == null) {
          return _buildEmptyChat();
        }

        final Map raw = snap.data!.snapshot.value as Map;
        final List<Map> messages = [];

        raw.forEach((key, value) {
          final Map msg = Map.from(value);
          msg['_key'] = key;
          if (msg['receiverId'] == _currentUid &&
              msg['isRead'] == false) {
            _markAsRead(key);
          }
          messages.add(msg);
        });

        messages.sort((a, b) {
          final ta = int.tryParse(a['timestamp']?.toString() ?? '0') ?? 0;
          final tb = int.tryParse(b['timestamp']?.toString() ?? '0') ?? 0;
          return ta.compareTo(tb);
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
                _scrollController.position.maxScrollExtent);
          }
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg  = messages[index];
            final prev = index > 0 ? messages[index - 1] : null;

            final bool isMe =
                msg['senderId']?.toString() == _currentUid;
            final int ts = int.tryParse(
                msg['timestamp']?.toString() ?? '0') ??
                0;
            final int prevTs = prev != null
                ? int.tryParse(
                prev['timestamp']?.toString() ?? '0') ??
                0
                : 0;
            final bool showDay =
                prev == null || !_isSameDay(ts, prevTs);

            return Column(
              children: [
                if (showDay) _buildDayDivider(_dayLabel(ts)),
                _buildBubble(msg, isMe, ts),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width:  80,
            height: 80,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              color:  kCyan.withOpacity(0.08),
              border: Border.all(color: kCyan.withOpacity(0.2), width: 2),
            ),
            child: Icon(Icons.chat_bubble_outline_rounded,
                color: kCyan.withOpacity(0.5), size: 36),
          ),
          const SizedBox(height: 20),
          Text('Start the conversation!',
              style: GoogleFonts.poppins(
                color:      Colors.white60,
                fontSize:   16,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 6),
          const Text('Messages are end-to-end secure',
              style: TextStyle(color: Colors.white30, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDayDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        const Expanded(child: Divider(color: Colors.white12)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color:        kDeep,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10)),
          ),
        ),
        const Expanded(child: Divider(color: Colors.white12)),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // ✅ BUBBLE — driver side uses real photo avatar
  // ════════════════════════════════════════════════════════════════════
  Widget _buildBubble(Map msg, bool isMe, int ts) {
    final String text   = msg['text']?.toString() ?? '';
    final bool   isRead = msg['isRead'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [

          // ✅ Driver avatar in bubble row — real photo
          if (!isMe) ...[
            Container(
              width:  32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape:  BoxShape.circle,
                border: Border.all(color: kCyan, width: 1.5),
              ),
              child: ClipOval(child: _buildAvatar(32)),
            ),
          ],

          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                    colors: [kCyan, kBlue],
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight)
                    : null,
                color:         isMe ? null : kCardNavy,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(18),
                  topRight:    const Radius.circular(18),
                  bottomLeft:  Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                      color: isMe
                          ? kCyan.withOpacity(0.2)
                          : Colors.black26,
                      blurRadius: 8,
                      offset:     const Offset(0, 3))
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(text,
                      style: TextStyle(
                        color:    isMe ? Colors.black : Colors.white,
                        fontSize: 14,
                      )),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(ts),
                        style: TextStyle(
                          color: isMe
                              ? Colors.black45
                              : Colors.white30,
                          fontSize: 9,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size:  12,
                          color: isRead ? Colors.black54 : Colors.black38,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // INPUT BAR
  // ════════════════════════════════════════════════════════════════════
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: kDark,
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset:     const Offset(0, -3))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color:        kCardNavy,
                borderRadius: BorderRadius.circular(28),
                border:       Border.all(color: kCyan.withOpacity(0.15)),
              ),
              child: TextField(
                controller: _msgController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines:   4,
                minLines:   1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText:  'Type a message...',
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                  border:    InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width:  50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kCyan, kBlue]),
                shape:    BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color:      kCyan.withOpacity(0.4),
                      blurRadius: 12,
                      offset:     const Offset(0, 4))
                ],
              ),
              child: _isSending
                  ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                      color: Colors.black, strokeWidth: 2))
                  : const Icon(Icons.send_rounded,
                  color: Colors.black, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // ✅ SHARED AVATAR BUILDER — real photo OR gradient initial
  // ════════════════════════════════════════════════════════════════════
  Widget _buildAvatar(double size) {
    final String displayName = _driverDisplayName.isNotEmpty
        ? _driverDisplayName
        : widget.otherUserName;
    final String initial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : '?';

    // Still loading
    if (!_profileLoaded) {
      return Container(
        width:  size,
        height: size,
        color:  kCardNavy,
        child:  const Center(
          child: SizedBox(
            width:  16,
            height: 16,
            child:  CircularProgressIndicator(
                strokeWidth: 1.5, color: kCyan),
          ),
        ),
      );
    }

    // Has real photo
    if (_driverPhotoUrl != null && _driverPhotoUrl!.isNotEmpty) {
      return Image.network(
        _driverPhotoUrl!,
        width:  size,
        height: size,
        fit:    BoxFit.cover,
        loadingBuilder: (ctx, child, prog) => prog == null
            ? child
            : Container(
          color: kCardNavy,
          child: const Center(
            child: SizedBox(
              width:  16,
              height: 16,
              child:  CircularProgressIndicator(
                  strokeWidth: 1.5, color: kCyan),
            ),
          ),
        ),
        errorBuilder: (ctx, e, s) => _initialAvatar(initial, size),
      );
    }

    // Fallback — gradient with initial letter
    return _initialAvatar(initial, size);
  }

  Widget _initialAvatar(String initial, double size) {
    return Container(
      width:  size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [kCyan, kBlue]),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
              color:      Colors.black,
              fontWeight: FontWeight.bold,
              fontSize:   size * 0.35),
        ),
      ),
    );
  }

  // Shimmer placeholder for name while loading
  Widget _shimmerBar({required double width, required double height}) {
    return Container(
      width:  width,
      height: height,
      decoration: BoxDecoration(
        color:        Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
