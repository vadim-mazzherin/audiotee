import Foundation

/// Protocol for handling audio output in different formats
public protocol AudioOutputHandler {
  /// Called with a pointer to raw PCM audio data. The pointer is only
  /// valid for the duration of this call.
  func handleAudioData(_ pointer: UnsafeRawPointer, count: Int)
  /// Called with raw PCM audio data plus timing metadata for the first sample.
  /// The pointer is only valid for the duration of this call.
  func handleAudioPacket(_ pointer: UnsafeRawPointer, count: Int, timing: AudioPacketTiming?)
  func handleMetadata(_ metadata: AudioStreamMetadata)
  func handleStreamStart()
  func handleStreamStop()
}

public extension AudioOutputHandler {
  func handleAudioPacket(_ pointer: UnsafeRawPointer, count: Int, timing: AudioPacketTiming?) {
    handleAudioData(pointer, count: count)
  }
}
