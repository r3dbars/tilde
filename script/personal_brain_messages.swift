#!/usr/bin/env swift
import Foundation
import SQLite3
import CryptoKit
enum Failure: Error { case safe }
let requiredMessageColumns: Set<String> = [
    "date", "text", "attributedBody", "is_from_me", "is_sent", "is_finished", "error", "service",
    "is_system_message", "is_service_message", "is_auto_reply", "is_forward", "is_audio_message",
    "is_spam", "group_action_type", "message_action_type", "date_retracted", "date_edited", "item_type",
    "associated_message_type", "associated_message_guid", "associated_message_emoji", "is_corrupt",
    "cache_has_attachments", "balloon_bundle_id",
]
let cleanSQL = """
  SELECT m.date, m.text, m.attributedBody, MIN(cmj.chat_id)
  FROM message AS m
  JOIN chat_message_join AS cmj ON cmj.message_id=m.ROWID
  WHERE (CASE WHEN abs(m.date)>=1000000000000 THEN m.date/1000000000.0 ELSE m.date END)<=?1
    AND m.is_from_me=1 AND m.is_sent=1 AND m.is_finished=1 AND m.error=0
    AND m.service IN ('iMessage','SMS','RCS')
    AND m.is_system_message=0 AND m.is_service_message=0 AND m.is_auto_reply=0
    AND m.is_forward=0 AND m.is_audio_message=0 AND m.is_spam=0
    AND m.group_action_type=0 AND m.message_action_type=0
    AND m.date_retracted=0 AND m.date_edited=0 AND m.item_type=0
    AND m.associated_message_type=0 AND NULLIF(m.associated_message_guid,'') IS NULL
    AND NULLIF(m.associated_message_emoji,'') IS NULL AND m.is_corrupt=0
    AND m.cache_has_attachments=0
    AND NOT EXISTS (SELECT 1 FROM message_attachment_join maj WHERE maj.message_id=m.ROWID)
    AND NULLIF(m.balloon_bundle_id,'') IS NULL
    AND ((typeof(m.text)='text' AND length(trim(m.text))>0)
      OR ((m.text IS NULL OR length(trim(m.text))=0)
        AND typeof(m.attributedBody)='blob' AND length(m.attributedBody)>0))
  GROUP BY m.ROWID HAVING COUNT(DISTINCT cmj.chat_id)=1
  ORDER BY m.date,m.ROWID
  """
func framed(_ data: Data, into hasher: inout SHA256) {
    var size = UInt64(data.count).bigEndian
    withUnsafeBytes(of: &size) { hasher.update(data: Data($0)) }
    hasher.update(data: data)
}
func selectionHasher() -> SHA256 {
    var hasher = SHA256()
    framed(Data("tilde.personal-brain-selection.v1".utf8), into: &hasher)
    return hasher
}
func addSelection(timestamp: String, chat: Int64, source: String, text: String, to hasher: inout SHA256) {
    for field in [timestamp, String(chat), source, text] { framed(Data(field.utf8), into: &hasher) }
}
func finished(_ hasher: SHA256) -> String {
    hasher.finalize().map { String(format: "%02x", $0) }.joined()
}
func stop(_ reason: String) -> Never {
    FileHandle.standardError.write(Data((reason + "\n").utf8))
    exit(2)
}
func writeJSON(_ value: [String: Any], to handle: FileHandle) throws {
    let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    try handle.write(contentsOf: data)
    try handle.write(contentsOf: Data([0x0A]))
}
func decodedBody(_ data: Data) -> (String, String)? {
    guard let unarchiver = NSUnarchiver(forReadingWith: data) else { return nil }
    guard let value = try? unarchiver.decodeTopLevelObject(),
          let attributed = value as? NSAttributedString else { return nil }
    return (attributed.string, String(describing: type(of: attributed)))
}
func schemaIsValid(_ database: OpaquePointer) -> Bool {
    func columns(_ table: String) -> Set<String>? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA table_info(\(table))", -1, &statement, nil) == SQLITE_OK,
              let statement else { return nil }
        defer { sqlite3_finalize(statement) }
        var result: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW, let bytes = sqlite3_column_text(statement, 1) {
            result.insert(String(cString: bytes))
        }
        return result
    }
    guard let message = columns("message"), let join = columns("chat_message_join"),
          let attachments = columns("message_attachment_join") else { return false }
    return requiredMessageColumns.isSubset(of: message)
        && Set(["message_id", "chat_id"]).isSubset(of: join)
        && Set(["message_id"]).isSubset(of: attachments)
}
func stream(databasePath: String, descriptor: Int32, cutoff: Double) throws {
    guard descriptor > STDERR_FILENO else { throw Failure.safe }
    let attributes = try FileManager.default.attributesOfItem(atPath: databasePath)
    guard attributes[.type] as? FileAttributeType == .typeRegular else { throw Failure.safe }
    let output = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
    var database: OpaquePointer?
    guard sqlite3_open_v2(databasePath, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
          let database else { throw Failure.safe }
    defer { sqlite3_close(database) }
    guard sqlite3_exec(database, "PRAGMA query_only=ON", nil, nil, nil) == SQLITE_OK else { throw Failure.safe }
    guard schemaIsValid(database) else { throw Failure.safe }
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, cleanSQL, -1, &statement, nil) == SQLITE_OK,
          let statement else { throw Failure.safe }
    defer { sqlite3_finalize(statement) }
    guard cutoff.isFinite, cutoff > 0, sqlite3_bind_double(statement, 1, cutoff) == SQLITE_OK else {
        throw Failure.safe
    }
    var textRows = 0
    var bodyRows = 0
    var decodeFailures = 0
    var bodyTypes: [String: Int] = [:]
    var selection = selectionHasher()
    while sqlite3_step(statement) == SQLITE_ROW {
        let timestamp = sqlite3_column_double(statement, 0)
        let timestampIdentity = sqlite3_column_type(statement, 0) == SQLITE_INTEGER
            ? String(sqlite3_column_int64(statement, 0))
            : String(format: "%.17g", locale: Locale(identifier: "en_US_POSIX"), timestamp)
        let chat = sqlite3_column_int64(statement, 3)
        var text: String?
        var source = "text"
        if sqlite3_column_type(statement, 1) == SQLITE_TEXT,
           let bytes = sqlite3_column_text(statement, 1) {
            let candidate = String(cString: bytes)
            if !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                text = candidate
                textRows += 1
            }
        }
        if text == nil, sqlite3_column_type(statement, 2) == SQLITE_BLOB,
           let bytes = sqlite3_column_blob(statement, 2) {
            let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 2)))
            if let decoded = decodedBody(data),
               !decoded.0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                text = decoded.0
                source = "attributed_body"
                bodyRows += 1
                bodyTypes[decoded.1, default: 0] += 1
            } else {
                decodeFailures += 1
            }
        }
        if let text {
            addSelection(timestamp: timestampIdentity, chat: chat, source: source, text: text, to: &selection)
            try writeJSON([
                "kind": "message", "timestamp": timestamp, "chat": chat,
                "text": text, "source": source,
            ], to: output)
        }
    }
    guard sqlite3_errcode(database) == SQLITE_DONE || sqlite3_errcode(database) == SQLITE_OK else {
        throw Failure.safe
    }
    try writeJSON([
        "kind": "summary", "selected_clean_rows": textRows + bodyRows, "text_rows": textRows,
        "selection_digest": finished(selection),
        "attributed_body_candidates": bodyRows + decodeFailures,
        "attributed_body_rows": bodyRows, "attributed_body_decode_failures": decodeFailures,
        "attributed_body_types": bodyTypes,
    ], to: output)
}
func selftest() throws {
    let sentinel = "RAW_NATIVE_SENTINEL"
    let immutable = NSArchiver.archivedData(withRootObject: NSAttributedString(string: sentinel))
    let mutable = NSArchiver.archivedData(withRootObject: NSMutableAttributedString(string: sentinel))
    let decoded = [immutable, mutable].compactMap(decodedBody)
    guard decoded.count == 2, decoded.allSatisfy({ $0.0 == sentinel }) else { throw Failure.safe }
    let failures = decodedBody(Data([0x00])) == nil ? 1 : 0
    guard decoded.count + failures == 3 else { throw Failure.safe }
    var first = selectionHasher(), second = selectionHasher(), changed = selectionHasher()
    addSelection(timestamp: "1", chat: 2, source: "text", text: sentinel, to: &first)
    addSelection(timestamp: "1", chat: 2, source: "text", text: sentinel, to: &second)
    addSelection(timestamp: "1", chat: 2, source: "text", text: sentinel + "x", to: &changed)
    guard finished(first) == finished(second), finished(first) != finished(changed) else { throw Failure.safe }
    var types: [String: Int] = [:]
    decoded.forEach { types[$0.1, default: 0] += 1 }
    let predicates = [
        "m.is_finished=1", "m.error=0", "m.service IN ('iMessage','SMS','RCS')",
        "m.is_service_message=0", "m.is_auto_reply=0", "m.is_forward=0", "m.is_audio_message=0",
        "m.is_spam=0", "m.group_action_type=0", "m.message_action_type=0", "m.date_retracted=0",
        "m.date_edited=0", "NULLIF(m.associated_message_guid,'') IS NULL",
        "NULLIF(m.associated_message_emoji,'') IS NULL", "m.cache_has_attachments=0",
        "NOT EXISTS", "NULLIF(m.balloon_bundle_id,'') IS NULL", "COUNT(DISTINCT cmj.chat_id)=1",
    ]
    guard requiredMessageColumns.count == 25, predicates.allSatisfy(cleanSQL.contains),
          cleanSQL.contains("CASE WHEN abs(m.date)>=1000000000000 THEN m.date/1000000000.0 ELSE m.date END)<=?1"),
          !cleanSQL.contains("is_delivered") else { throw Failure.safe }
    try writeJSON([
        "decoded_attributed_bodies": decoded.count, "body_types": types,
        "attributed_body_candidates": decoded.count + failures, "decode_failures": failures,
        "raw_text_output": false, "required_message_columns": requiredMessageColumns.count,
        "strict_query_predicates": predicates.count, "selection_digest_selftest": true,
    ], to: .standardOutput)
}
let arguments = Array(CommandLine.arguments.dropFirst())
do {
    if arguments == ["--selftest"] {
        try selftest()
    } else if arguments.count == 4, arguments[0] == "--stream-fd",
              let descriptor = Int32(arguments[1]), let cutoff = Double(arguments[3]) {
        try stream(databasePath: arguments[2], descriptor: descriptor, cutoff: cutoff)
    } else {
        throw Failure.safe
    }
} catch {
    stop("personal_brain_messages: invalid input or database")
}
