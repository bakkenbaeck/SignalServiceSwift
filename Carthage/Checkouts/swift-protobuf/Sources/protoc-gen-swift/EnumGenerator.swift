// Sources/protoc-gen-swift/EnumGenerator.swift - Enum logic
//
// Copyright (c) 2014 - 2016 Apple Inc. and the project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See LICENSE.txt for license information:
// https://github.com/apple/swift-protobuf/blob/master/LICENSE.txt
//
// -----------------------------------------------------------------------------
///
/// This file handles the generation of a Swift enum for each .proto enum.
///
// -----------------------------------------------------------------------------

import Foundation
import SwiftProtobufPluginLibrary
import SwiftProtobuf

/// The name of the case used to represent unrecognized values in proto3.
/// This case has an associated value containing the raw integer value.
private let unrecognizedCaseName = "UNRECOGNIZED"

/// Generates a Swift enum from a protobuf enum descriptor.
class EnumGenerator {
  private let enumDescriptor: EnumDescriptor
  private let generatorOptions: GeneratorOptions
  private let namer: SwiftProtobufNamer

  /// The values that aren't aliases, sorted by number.
  private let mainEnumValueDescriptorsSorted: [EnumValueDescriptor]

  private let swiftRelativeName: String
  private let swiftFullName: String

  init(descriptor: EnumDescriptor,
       generatorOptions: GeneratorOptions,
       namer: SwiftProtobufNamer
  ) {
    self.enumDescriptor = descriptor
    self.generatorOptions = generatorOptions
    self.namer = namer

    mainEnumValueDescriptorsSorted = descriptor.values.filter({
      return $0.aliasOf == nil
    }).sorted(by: {
      return $0.number < $1.number
    })

    swiftRelativeName = namer.relativeName(enum: descriptor)
    swiftFullName = namer.fullName(enum: descriptor)
  }

  func generateMainEnum(printer p: inout CodePrinter) {
    let visibility = generatorOptions.visibilitySourceSnippet

    p.print("\n")
    p.print(enumDescriptor.protoSourceComments())
    p.print("\(visibility)enum \(swiftRelativeName): SwiftProtobuf.Enum {\n")
    p.indent()
    p.print("\(visibility)typealias RawValue = Int\n")

    // Cases/aliases
    generateCasesOrAliases(printer: &p)

    // Generate the default initializer.
    p.print("\n")
    p.print("\(visibility)init() {\n")
    p.indent()
    let dottedDefault = namer.dottedRelativeName(enumValue: enumDescriptor.defaultValue)
    p.print("self = \(dottedDefault)\n")
    p.outdent()
    p.print("}\n")

    p.print("\n")
    generateInitRawValue(printer: &p)

    p.print("\n")
    generateRawValueProperty(printer: &p)

    p.outdent()
    p.print("\n")
    p.print("}\n")
  }

  func generateRuntimeSupport(printer p: inout CodePrinter) {
    p.print("\n")
    p.print("extension \(swiftFullName): SwiftProtobuf._ProtoNameProviding {\n")
    p.indent()
    generateProtoNameProviding(printer: &p)
    p.outdent()
    p.print("}\n")
  }

  /// Generates the cases or statics (for alias) for the values.
  ///
  /// - Parameter p: The code printer.
  private func generateCasesOrAliases(printer p: inout CodePrinter) {
    let visibility = generatorOptions.visibilitySourceSnippet
    for enumValueDescriptor in namer.uniquelyNamedValues(enum: enumDescriptor) {
      let comments = enumValueDescriptor.protoSourceComments()
      if !comments.isEmpty {
        p.print("\n", comments)
      }
      let relativeName = namer.relativeName(enumValue: enumValueDescriptor)
      if let aliasOf = enumValueDescriptor.aliasOf {
        let aliasOfName = namer.relativeName(enumValue: aliasOf)
        p.print("\(visibility)static let \(relativeName) = \(aliasOfName)\n")
      } else {
        p.print("case \(relativeName) // = \(enumValueDescriptor.number)\n")
      }
    }
    if enumDescriptor.hasUnknownPreservingSemantics {
      p.print("case \(unrecognizedCaseName)(Int)\n")
    }
  }

  /// Generates the mapping from case numbers to their text/JSON names.
  ///
  /// - Parameter p: The code printer.
  private func generateProtoNameProviding(printer p: inout CodePrinter) {
    let visibility = generatorOptions.visibilitySourceSnippet

    p.print("\(visibility)static let _protobuf_nameMap: SwiftProtobuf._NameMap = [\n")
    p.indent()
    for v in mainEnumValueDescriptorsSorted {
      if v.aliases.isEmpty {
        p.print("\(v.number): .same(proto: \"\(v.name)\"),\n")
      } else {
        let aliasNames = v.aliases.map({ "\"\($0.name)\"" }).joined(separator: ", ")
        p.print("\(v.number): .aliased(proto: \"\(v.name)\", aliases: [\(aliasNames)]),\n")
      }
    }
    p.outdent()
    p.print("]\n")
  }

  /// Generates `init?(rawValue:)` for the enum.
  ///
  /// - Parameter p: The code printer.
  private func generateInitRawValue(printer p: inout CodePrinter) {
    let visibility = generatorOptions.visibilitySourceSnippet

    p.print("\(visibility)init?(rawValue: Int) {\n")
    p.indent()
    p.print("switch rawValue {\n")
    for v in mainEnumValueDescriptorsSorted {
      let dottedName = namer.dottedRelativeName(enumValue: v)
      p.print("case \(v.number): self = \(dottedName)\n")
    }
    if enumDescriptor.hasUnknownPreservingSemantics {
      p.print("default: self = .\(unrecognizedCaseName)(rawValue)\n")
    } else {
      p.print("default: return nil\n")
    }
    p.print("}\n")
    p.outdent()
    p.print("}\n")
  }

  /// Generates the `rawValue` property of the enum.
  ///
  /// - Parameter p: The code printer.
  private func generateRawValueProperty(printer p: inout CodePrinter) {
    let visibility = generatorOptions.visibilitySourceSnippet

    p.print("\(visibility)var rawValue: Int {\n")
    p.indent()
    p.print("switch self {\n")
    for v in mainEnumValueDescriptorsSorted {
      let dottedName = namer.dottedRelativeName(enumValue: v)
      p.print("case \(dottedName): return \(v.number)\n")
    }
    if enumDescriptor.hasUnknownPreservingSemantics {
      p.print("case .\(unrecognizedCaseName)(let i): return i\n")
    }
    p.print("}\n")
    p.outdent()
    p.print("}\n")
  }
}
