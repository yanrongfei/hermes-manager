import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/data/models/message.dart';
import 'package:hermes_app/data/models/attachment.dart';
import 'package:hermes_app/data/models/content_block.dart';

void main() {
  group('Attachment Model', () {
    test('fromJson parses image attachment correctly', () {
      final json = {
        'id': 'att-1',
        'type': 'image',
        'name': 'photo.jpg',
        'url': 'https://example.com/photo.jpg',
        'size': 102400,
        'mime_type': 'image/jpeg',
      };

      final attachment = Attachment.fromJson(json);
      expect(attachment.id, 'att-1');
      expect(attachment.type, 'image');
      expect(attachment.name, 'photo.jpg');
      expect(attachment.url, 'https://example.com/photo.jpg');
      expect(attachment.size, 102400);
      expect(attachment.isImage, isTrue);
      expect(attachment.isFile, isFalse);
    });

    test('fromJson parses file attachment correctly', () {
      final json = {
        'id': 'att-2',
        'type': 'file',
        'name': 'document.pdf',
        'url': 'https://example.com/document.pdf',
        'size': 204800,
        'mime_type': 'application/pdf',
      };

      final attachment = Attachment.fromJson(json);
      expect(attachment.id, 'att-2');
      expect(attachment.type, 'file');
      expect(attachment.name, 'document.pdf');
      expect(attachment.isFile, isTrue);
      expect(attachment.isImage, isFalse);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'att-3',
        'type': 'image',
        'name': 'unknown',
      };

      final attachment = Attachment.fromJson(json);
      expect(attachment.id, 'att-3');
      expect(attachment.url, isNull);
      expect(attachment.size, isNull);
      expect(attachment.mimeType, isNull);
      expect(attachment.localPath, isNull);
    });

    test('toJson serializes attachment correctly', () {
      final attachment = Attachment(
        id: 'att-1',
        type: 'image',
        name: 'test.jpg',
        url: 'https://example.com/test.jpg',
        size: 50000,
      );

      final json = attachment.toJson();
      expect(json['id'], 'att-1');
      expect(json['type'], 'image');
      expect(json['name'], 'test.jpg');
      expect(json['url'], 'https://example.com/test.jpg');
      expect(json['size'], 50000);
    });

    test('toJson omits null optional fields', () {
      final attachment = Attachment(
        id: 'att-1',
        type: 'file',
        name: 'test.txt',
      );

      final json = attachment.toJson();
      expect(json.containsKey('url'), isFalse);
      expect(json.containsKey('size'), isFalse);
    });

    test('copyWith creates new instance with updated values', () {
      final original = Attachment(
        id: 'att-1',
        type: 'image',
        name: 'original.jpg',
        url: 'https://example.com/original.jpg',
      );

      final updated = original.copyWith(name: 'updated.jpg', url: 'https://example.com/updated.jpg');

      expect(updated.id, 'att-1');
      expect(updated.name, 'updated.jpg');
      expect(updated.url, 'https://example.com/updated.jpg');
      expect(original.name, 'original.jpg'); // Original unchanged
    });

    test('handles local path attachments', () {
      final attachment = Attachment(
        id: 'att-1',
        type: 'image',
        name: 'local_photo.jpg',
        localPath: '/path/to/local/photo.jpg',
      );

      expect(attachment.localPath, '/path/to/local/photo.jpg');
      expect(attachment.isImage, isTrue);
    });
  });

  group('ContentBlock Model', () {
    test('fromJson parses text block correctly', () {
      final json = {
        'type': 'text',
        'text': 'Hello world',
      };

      final block = ContentBlock.fromJson(json);
      expect(block.type, ContentBlockType.text);
      expect(block.text, 'Hello world');
      expect(block.isText, isTrue);
      expect(block.isImage, isFalse);
      expect(block.isFile, isFalse);
      expect(block.isCode, isFalse);
    });

    test('fromJson parses image block correctly', () {
      final json = {
        'type': 'image',
        'url': 'https://example.com/image.jpg',
        'name': 'image.jpg',
        'size': 102400,
      };

      final block = ContentBlock.fromJson(json);
      expect(block.type, ContentBlockType.image);
      expect(block.url, 'https://example.com/image.jpg');
      expect(block.isImage, isTrue);
    });

    test('fromJson parses file block correctly', () {
      final json = {
        'type': 'file',
        'name': 'document.pdf',
        'url': 'https://example.com/document.pdf',
        'size': 204800,
      };

      final block = ContentBlock.fromJson(json);
      expect(block.type, ContentBlockType.file);
      expect(block.name, 'document.pdf');
      expect(block.isFile, isTrue);
    });

    test('fromJson parses code block correctly', () {
      final json = {
        'type': 'code',
        'text': 'def hello():\n    print("Hello")',
        'language': 'python',
      };

      final block = ContentBlock.fromJson(json);
      expect(block.type, ContentBlockType.code);
      expect(block.language, 'python');
      expect(block.isCode, isTrue);
    });

    test('fromJson handles unknown type defaults to text', () {
      final json = {
        'type': 'unknown',
        'text': 'Some content',
      };

      final block = ContentBlock.fromJson(json);
      expect(block.type, ContentBlockType.text);
    });

    test('toJson serializes block correctly', () {
      final block = ContentBlock(
        type: ContentBlockType.code,
        text: 'console.log("test")',
        language: 'javascript',
      );

      final json = block.toJson();
      expect(json['type'], 'code');
      expect(json['text'], 'console.log("test")');
      expect(json['language'], 'javascript');
    });
  });

  group('Message Model - New Fields', () {
    test('fromJson parses message with attachments', () {
      final json = {
        'id': 'msg-1',
        'roomId': 'room-1',
        'senderId': 'user-1',
        'senderType': 'user',
        'senderName': 'User',
        'content': 'Check this image',
        'contentType': 'text',
        'createdAt': 1234567890,
        'extra': '{"attachments":[{"id":"att-1","type":"image","name":"photo.jpg","url":"https://example.com/photo.jpg"}]}',
      };

      final message = Message.fromJson(json);
      expect(message.hasAttachments, isTrue);
      expect(message.attachments!.length, 1);
      expect(message.attachments!.first.name, 'photo.jpg');
    });

    test('fromJson parses message with content_blocks', () {
      final json = {
        'id': 'msg-1',
        'roomId': 'room-1',
        'senderId': 'agent-1',
        'senderType': 'agent',
        'senderName': 'Agent',
        'content': '',
        'contentType': 'text',
        'createdAt': 1234567890,
        'extra': '{"content_blocks":[{"type":"text","text":"Hello"},{"type":"image","url":"https://example.com/img.jpg"}]}',
      };

      final message = Message.fromJson(json);
      expect(message.hasContentBlocks, isTrue);
      expect(message.contentBlocks!.length, 2);
      expect(message.contentBlocks![0].isText, isTrue);
      expect(message.contentBlocks![1].isImage, isTrue);
    });

    test('fromJson parses message with reasoning from extra', () {
      final json = {
        'id': 'msg-1',
        'roomId': 'room-1',
        'senderId': 'agent-1',
        'senderType': 'agent',
        'senderName': 'Agent',
        'content': 'Final answer',
        'contentType': 'text',
        'createdAt': 1234567890,
        'extra': '{"reasoning":"Let me think about this..."}',
      };

      final message = Message.fromJson(json);
      expect(message.reasoning, 'Let me think about this...');
    });

    test('fromJson parses isHighlighted field', () {
      final json = {
        'id': 'msg-1',
        'roomId': 'room-1',
        'senderId': 'user-1',
        'senderType': 'user',
        'senderName': 'User',
        'content': 'Important message',
        'contentType': 'text',
        'createdAt': 1234567890,
        'is_highlighted': true,
      };

      final message = Message.fromJson(json);
      expect(message.isHighlighted, isTrue);
    });

    test('fromJson parses isCommand field', () {
      final json = {
        'id': 'msg-1',
        'roomId': 'room-1',
        'senderId': 'user-1',
        'senderType': 'user',
        'senderName': 'User',
        'content': '/status',
        'contentType': 'text',
        'createdAt': 1234567890,
        'is_command': true,
      };

      final message = Message.fromJson(json);
      expect(message.isCommand, isTrue);
    });

    test('isCommandMessage returns true for / commands by user', () {
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

    test('isCommandMessage returns false for regular user messages', () {
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

    test('isCommandMessage respects isCommand flag', () {
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

    test('hasAttachments returns false for message without attachments', () {
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

    test('hasContentBlocks returns false for message without content blocks', () {
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

      expect(message.hasContentBlocks, isFalse);
    });

    test('copyWith preserves attachments', () {
      final original = Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-1',
        senderType: 'user',
        senderName: 'User',
        content: 'Hello',
        contentType: 'text',
        createdAt: 1234567890,
        attachments: [
          Attachment(id: 'att-1', type: 'image', name: 'photo.jpg'),
        ],
      );

      final updated = original.copyWith(isStreaming: true);

      expect(updated.attachments!.length, 1);
      expect(updated.attachments!.first.name, 'photo.jpg');
    });

    test('copyWith preserves contentBlocks', () {
      final original = Message(
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

      final updated = original.copyWith(content: 'Updated answer');

      expect(updated.contentBlocks!.length, 1);
      expect(updated.contentBlocks!.first.text, 'Hello');
    });

    test('copyWith can update isHighlighted', () {
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

      final highlighted = message.copyWith(isHighlighted: true);
      expect(highlighted.isHighlighted, isTrue);
    });
  });

  group('Message Model - Extra Field Parsing', () {
    test('handles invalid extra JSON gracefully', () {
      final json = {
        'id': 'msg-1',
        'roomId': 'room-1',
        'senderId': 'user-1',
        'senderType': 'user',
        'senderName': 'User',
        'content': 'Hello',
        'contentType': 'text',
        'createdAt': 1234567890,
        'extra': 'not valid json',
      };

      final message = Message.fromJson(json);
      expect(message.hasAttachments, isFalse);
      expect(message.hasContentBlocks, isFalse);
    });

    test('handles extra with non-Map JSON gracefully', () {
      final json = {
        'id': 'msg-1',
        'roomId': 'room-1',
        'senderId': 'user-1',
        'senderType': 'user',
        'senderName': 'User',
        'content': 'Hello',
        'contentType': 'text',
        'createdAt': 1234567890,
        'extra': '["array", "not", "map"]',
      };

      final message = Message.fromJson(json);
      expect(message.hasAttachments, isFalse);
      expect(message.hasContentBlocks, isFalse);
    });

    test('handles reasoning in extra field with JSON encoding', () {
      final extraData = {'reasoning': 'My thinking process'};
      final json = {
        'id': 'msg-1',
        'roomId': 'room-1',
        'senderId': 'agent-1',
        'senderType': 'agent',
        'senderName': 'Agent',
        'content': 'Answer',
        'contentType': 'text',
        'createdAt': 1234567890,
        'extra': jsonEncode(extraData),
      };

      final message = Message.fromJson(json);
      expect(message.reasoning, 'My thinking process');
    });
  });

  group('Message Model - Edge Cases', () {
    test('handles empty attachments array', () {
      final json = {
        'id': 'msg-1',
        'roomId': 'room-1',
        'senderId': 'user-1',
        'senderType': 'user',
        'senderName': 'User',
        'content': 'Hello',
        'contentType': 'text',
        'createdAt': 1234567890,
        'extra': '{"attachments":[]}',
      };

      final message = Message.fromJson(json);
      expect(message.hasAttachments, isFalse);
    });

    test('handles empty content_blocks array', () {
      final json = {
        'id': 'msg-1',
        'roomId': 'room-1',
        'senderId': 'agent-1',
        'senderType': 'agent',
        'senderName': 'Agent',
        'content': 'Answer',
        'contentType': 'text',
        'createdAt': 1234567890,
        'extra': '{"content_blocks":[]}',
      };

      final message = Message.fromJson(json);
      expect(message.hasContentBlocks, isFalse);
    });

    test('senderType with snake_case maps correctly', () {
      final json = {
        'id': 'msg-1',
        'roomId': 'room-1',
        'sender_id': 'agent-1',
        'sender_type': 'agent',
        'sender_name': 'Agent',
        'content': 'Hello',
        'contentType': 'text',
        'created_at': 1234567890,
      };

      final message = Message.fromJson(json);
      expect(message.senderId, 'agent-1');
      expect(message.senderType, 'agent');
      expect(message.senderName, 'Agent');
    });

    test('roomId with snake_case maps correctly', () {
      final json = {
        'id': 'msg-1',
        'room_id': 'room-1',
        'senderId': 'user-1',
        'senderType': 'user',
        'senderName': 'User',
        'content': 'Hello',
        'contentType': 'text',
        'createdAt': 1234567890,
      };

      final message = Message.fromJson(json);
      expect(message.roomId, 'room-1');
    });
  });
}