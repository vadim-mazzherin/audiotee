import AudioTeeCore
import Foundation

/// Writes length-prefixed PCM frames to stdout. Each frame contains a fixed
/// little-endian header followed immediately by the PCM payload, keeping audio
/// bytes and their source timing metadata atomically associated.
class FramedBinaryOutputHandler: AudioOutputHandler {
  private static let headerSize = 64
  private static let version: UInt16 = 1
  private let fd = STDOUT_FILENO
  private var metadata: AudioStreamMetadata?

  func handleAudioData(_ pointer: UnsafeRawPointer, count: Int) {
    handleAudioPacket(pointer, count: count, timing: nil)
  }

  func handleAudioPacket(_ pointer: UnsafeRawPointer, count: Int, timing: AudioPacketTiming?) {
    var header = [UInt8](repeating: 0, count: Self.headerSize)
    header[0] = 0x41  // A
    header[1] = 0x54  // T
    header[2] = 0x46  // F
    header[3] = 0x31  // 1

    let bytesPerSample = Int(max((metadata?.bitsPerChannel ?? 16) / 8, 1))
    let channels = Int(max(metadata?.channelsPerFrame ?? 1, 1))
    let sampleCount = UInt32(count / max(bytesPerSample * channels, 1))
    let timestampValid = timing?.sourceTimestampMs != nil
    let hostTimeValid = timing?.hostTimeNs != nil
    var flags: UInt32 = 0
    if timestampValid {
      flags |= 1 << 0
    }
    if hostTimeValid {
      flags |= 1 << 1
    }

    writeUInt16(UInt16(Self.headerSize), into: &header, at: 4)
    writeUInt16(Self.version, into: &header, at: 6)
    writeUInt64(timing?.sequence ?? 0, into: &header, at: 8)
    writeDouble(timing?.sourceTimestampMs ?? 0, into: &header, at: 16)
    writeUInt64(timing?.hostTimeNs ?? 0, into: &header, at: 24)
    writeDouble(metadata?.sampleRate ?? 0, into: &header, at: 32)
    writeUInt32(sampleCount, into: &header, at: 40)
    writeUInt32(UInt32(count), into: &header, at: 44)
    writeUInt16(UInt16(metadata?.channelsPerFrame ?? 0), into: &header, at: 48)
    writeUInt16(UInt16(metadata?.bitsPerChannel ?? 0), into: &header, at: 50)
    writeUInt32(metadata?.isFloat == true ? 1 : 0, into: &header, at: 52)
    writeUInt32(flags, into: &header, at: 56)

    header.withUnsafeBytes { bytes in
      if let baseAddress = bytes.baseAddress {
        writeAll(baseAddress, count: Self.headerSize)
      }
    }
    writeAll(pointer, count: count)
  }

  func handleMetadata(_ metadata: AudioStreamMetadata) {
    self.metadata = metadata
    AudioTeeLogging.logger.writeMessage(.metadata, data: metadata)
  }

  func handleStreamStart() {
    AudioTeeLogging.logger.writeMessage(.streamStart, data: Optional<String>.none)
  }

  func handleStreamStop() {
    AudioTeeLogging.logger.writeMessage(.streamStop, data: Optional<String>.none)
  }

  private func writeAll(_ pointer: UnsafeRawPointer, count: Int) {
    var written = 0
    while written < count {
      let result = write(fd, pointer.advanced(by: written), count - written)
      if result >= 0 {
        written += result
      } else if errno == EINTR {
        continue
      } else {
        break
      }
    }
  }

  private func writeUInt16(_ value: UInt16, into header: inout [UInt8], at offset: Int) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { bytes in
      header.replaceSubrange(offset..<offset + 2, with: bytes)
    }
  }

  private func writeUInt32(_ value: UInt32, into header: inout [UInt8], at offset: Int) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { bytes in
      header.replaceSubrange(offset..<offset + 4, with: bytes)
    }
  }

  private func writeUInt64(_ value: UInt64, into header: inout [UInt8], at offset: Int) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { bytes in
      header.replaceSubrange(offset..<offset + 8, with: bytes)
    }
  }

  private func writeDouble(_ value: Double, into header: inout [UInt8], at offset: Int) {
    writeUInt64(value.bitPattern, into: &header, at: offset)
  }
}
