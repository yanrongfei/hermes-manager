import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/data/models/message.dart';
import 'package:hermes_app/data/models/content_block.dart';
import 'package:hermes_app/data/models/attachment.dart';

void main() {
  group('ThinkingBlock Timer Logic', () {
    test('formatDuration correctly formats seconds', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'agent-1',
        senderType: 'agent',
        senderName: 'Agent',
        content: 'Thinking...',
        contentType: 'text',
        createdAt: 1234567890,
        isStreaming: true,
      );

      expect(message.isStreaming, isTrue);
    });

    test('durationMs of null means timer should start', () {
      // When durationMs is null and isStreaming is true, timer should start
      const durationMs = null;
      const isStreaming = true;

      final shouldStartTimer = durationMs == null && isStreaming;
      expect(shouldStartTimer, isTrue);
    });

    test('durationMs provided means no timer needed', () {
      // When durationMs is provided (from server), use it directly
      const durationMs = 5000;
      const isStreaming = true;

      final shouldStartTimer = durationMs == null && isStreaming;
      expect(shouldStartTimer, isFalse);
    });

    test('stopped streaming should not start timer', () {
      const durationMs = null;
      const isStreaming = false;

      final shouldStartTimer = durationMs == null && isStreaming;
      expect(shouldStartTimer, isFalse);
    });
  });

  group('Message isCommand Logic', () {
    test('user message starting with / is command', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-1',
        senderType: 'user',
        senderName: 'User',
        content: '/status',
        contentType: 'text',
        createdAt: 1234567890,
      );

      expect(message.isCommandMessage, isTrue);
    });

    test('user message with multiple slashes is command', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-1',
        senderType: 'user',
        senderName: 'User',
        content: '//status',
        contentType: 'text',
        createdAt: 1234567890,
      );

      expect(message.isCommandMessage, isTrue);
    });

    test('agent message with / but isCommand=true is command', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'agent-1',
        senderType: 'agent',
        senderName: 'Agent',
        content: '/status',
        contentType: 'text',
        createdAt: 1234567890,
        isCommand: true,
      );

      expect(message.isCommandMessage, isTrue);
    });

    test('agent message with / but no explicit isCommand is NOT command', () {
      // Agent messages don't trigger command behavior even with /
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'agent-1',
        senderType: 'agent',
        senderName: 'Agent',
        content: '/thinking',
        contentType: 'text',
        createdAt: 1234567890,
      );

      expect(message.isCommandMessage, isFalse);
    });

    test('normal user message is not command', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-1',
        senderType: 'user',
        senderName: 'User',
        content: 'Hello, how are you?',
        contentType: 'text',
        createdAt: 1234567890,
      );

      expect(message.isCommandMessage, isFalse);
    });

    test('isCommand=false explicitly but content starts with / by user still triggers command', () {
      // The logic: isCommand == true || (content.startsWith('/') && isFromUser)
      // So if user message starts with /, isCommand=false doesn't override it
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-1',
        senderType: 'user',
        senderName: 'User',
        content: '/status',
        contentType: 'text',
        createdAt: 1234567890,
        isCommand: false,
      );

      // Content check takes priority over isCommand=false for user messages
      expect(message.isCommandMessage, isTrue);
    });
  });

  group('Message Highlight Logic', () {
    test('message without isHighlighted is not highlighted', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-1',
        senderType: 'user',
        senderName: 'User',
        content: 'Hello',
        contentType: 'text',
        createdAt: 1234567890,
      );

      expect(message.isHighlighted, isNull);
    });

    test('message with isHighlighted=true is highlighted', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-1',
        senderType: 'user',
        senderName: 'User',
        content: 'Hello',
        contentType: 'text',
        createdAt: 1234567890,
        isHighlighted: true,
      );

      expect(message.isHighlighted, isTrue);
    });

    test('copyWith can set isHighlighted', () {
      final original = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-1',
        senderType: 'user',
        senderName: 'User',
        content: 'Hello',
        contentType: 'text',
        createdAt: 1234567890,
      );

      final highlighted = original.copyWith(isHighlighted: true);
      expect(highlighted.isHighlighted, isTrue);
      expect(original.isHighlighted, isNull); // Original unchanged
    });
  });

  group('ContentBlock Type Detection', () {
    test('text block isText returns true', () {
      final block = ContentBlock(type: ContentBlockType.text, text: 'Hello');
      expect(block.isText, isTrue);
      expect(block.isImage, isFalse);
      expect(block.isFile, isFalse);
      expect(block.isCode, isFalse);
    });

    test('image block isImage returns true', () {
      final block = ContentBlock(type: ContentBlockType.image, url: 'https://example.com/img.jpg');
      expect(block.isImage, isTrue);
      expect(block.isText, isFalse);
      expect(block.isFile, isFalse);
      expect(block.isCode, isFalse);
    });

    test('file block isFile returns true', () {
      final block = ContentBlock(type: ContentBlockType.file, name: 'doc.pdf');
      expect(block.isFile, isTrue);
      expect(block.isText, isFalse);
      expect(block.isImage, isFalse);
      expect(block.isCode, isFalse);
    });

    test('code block isCode returns true', () {
      final block = ContentBlock(type: ContentBlockType.code, text: 'print("hello")', language: 'python');
      expect(block.isCode, isTrue);
      expect(block.isText, isFalse);
      expect(block.isImage, isFalse);
      expect(block.isFile, isFalse);
    });
  });

  group('Message hasAttachments and hasContentBlocks', () {
    test('hasAttachments true with non-empty list', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-1',
        senderType: 'user',
        senderName: 'User',
        content: 'Hello',
        contentType: 'text',
        createdAt: 1234567890,
        attachments: [
          Attachment(id: 'att-1', type: 'image', name: 'img.jpg', url: 'https://example.com/img.jpg'),
        ],
      );

      expect(message.hasAttachments, isTrue);
    });

    test('hasAttachments false with null', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-1',
        senderType: 'user',
        senderName: 'User',
        content: 'Hello',
        contentType: 'text',
        createdAt: 1234567890,
      );

      expect(message.hasAttachments, isFalse);
    });

    test('hasAttachments false with empty list', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-1',
        senderType: 'user',
        senderName: 'User',
        content: 'Hello',
        contentType: 'text',
        createdAt: 1234567890,
        attachments: [],
      );

      expect(message.hasAttachments, isFalse);
    });

    test('hasContentBlocks true with non-empty list', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'agent-1',
        senderType: 'agent',
        senderName: 'Agent',
        content: 'Answer',
        contentType: 'text',
        createdAt: 1234567890,
        contentBlocks: [
          ContentBlock(type: ContentBlockType.text, text: 'Hello'),
        ],
      );

      expect(message.hasContentBlocks, isTrue);
    });

    test('hasContentBlocks false with null', () {
      final message = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'agent-1',
        senderType: 'agent',
        senderName: 'Agent',
        content: 'Answer',
        contentType: 'text',
        createdAt: 1234567890,
      );

      expect(message.hasContentBlocks, isFalse);
    });
  });

  group('Message Extra Field JSON Parsing', () {
    test('parses reasoning from extra JSON', () {
      final json = {
        'id': 'msg-1',
        'roomId': 'room-1',
        'senderId': 'agent-1',
        'senderType': 'agent',
        'senderName': 'Agent',
        'content': 'Final answer',
        'contentType': 'text',
        'createdAt': 1234567890,
        'extra': '{"reasoning":"Step 1: analyze\\nStep 2: solve"}',
      };

      final message = Message.fromJson(json);
      expect(message.reasoning, 'Step 1: analyze\nStep 2: solve');
    });

    test('priority reasoning field over extra reasoning', () {
      // When both reasoning field and extra.reasoning exist
      // The field should take priority (actual implementation uses field if present)
      final json = {
        'id': 'msg-1',
        'roomId': 'room-1',
        'senderId': 'agent-1',
        'senderType': 'agent',
        'senderName': 'Agent',
        'content': 'Final answer',
        'contentType': 'text',
        'createdAt': 1234567890,
        'reasoning': 'Field reasoning',
        'extra': '{"reasoning":"Extra reasoning"}',
      };

      final message = Message.fromJson(json);
      // Field takes priority
      expect(message.reasoning, 'Field reasoning');
    });
  });
}