import Foundation

public struct AudioPacketTiming {
  public let sequence: UInt64
  public let sourceTimestampMs: Double?
  public let hostTimeNs: UInt64?

  public init(sequence: UInt64, sourceTimestampMs: Double?, hostTimeNs: UInt64?) {
    self.sequence = sequence
    self.sourceTimestampMs = sourceTimestampMs
    self.hostTimeNs = hostTimeNs
  }

  public func advanced(byDurationMs durationMs: Double) -> AudioPacketTiming {
    let durationNs = UInt64((durationMs * 1_000_000.0).rounded())
    return AudioPacketTiming(
      sequence: sequence,
      sourceTimestampMs: sourceTimestampMs.map { $0 + durationMs },
      hostTimeNs: hostTimeNs.map { $0 + durationNs }
    )
  }

  public func withSequence(_ sequence: UInt64) -> AudioPacketTiming {
    return AudioPacketTiming(
      sequence: sequence,
      sourceTimestampMs: sourceTimestampMs,
      hostTimeNs: hostTimeNs
    )
  }
}
