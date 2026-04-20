//
//  PNGDocument.swift
//  LineFlow
//
//  Created by macbook Алиса on 15/4/26.
//
import SwiftUI
import UniformTypeIdentifiers

struct PNGDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

