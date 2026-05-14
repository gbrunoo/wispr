//
//  TranscriptDocument.swift
//  wispr
//
//  FileDocument type for exporting meeting transcripts via SwiftUI .fileExporter().
//

import SwiftUI
import UniformTypeIdentifiers

struct TranscriptDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.plainText]
    let text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
