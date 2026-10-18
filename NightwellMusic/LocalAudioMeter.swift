import AVFoundation
import MediaToolbox

/// The tap observes the player's PCM. It never records the microphone or changes samples.
final class LocalAudioMeter {
    private let lock = NSLock()
    private var value = 0.0
    private var updated = 0.0
    private var format = AudioStreamBasicDescription()
    private var low = 0.0, dc = 0.0, sum = 0.0, bassSum = 0.0
    private var lowAlpha = 0.0, dcAlpha = 0.0
    private var frames = 0, window = 2205
    private(set) var attached = false

    func attach(to item: AVPlayerItem) {
        // AVAudioMixInputParametersTrackID.mixID is 0 in the iOS 27 SDK.
        // Using the documented value keeps the app buildable with Xcode 16.4.
        guard #available(iOS 27.0, *) else { return }
        var callbacks = MTAudioProcessingTapCallbacks(version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: Unmanaged.passRetained(self).toOpaque(),
            init: { _, client, storage in storage.pointee = client },
            finalize: { tap in Unmanaged<LocalAudioMeter>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).release() },
            prepare: { tap, _, description in
                let meter = Unmanaged<LocalAudioMeter>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
                meter.configure(description.pointee)
            }, unprepare: { _ in },
            process: { tap, count, _, buffers, produced, flags in
                let status = MTAudioProcessingTapGetSourceAudio(tap, count, buffers, flags, nil, produced)
                guard status == noErr, produced.pointee > 0 else { return }
                let meter = Unmanaged<LocalAudioMeter>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
                meter.consume(buffers, frames: Int(produced.pointee))
            })
        var result: Unmanaged<MTAudioProcessingTap>?
        let status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects, &result)
        guard status == noErr, let result else {
            Unmanaged<LocalAudioMeter>.fromOpaque(callbacks.clientInfo!).release(); return
        }
        let parameters = AVMutableAudioMixInputParameters()
        parameters.trackID = 0
        parameters.audioTapProcessor = result.takeRetainedValue()
        let mix = AVMutableAudioMix(); mix.inputParameters = [parameters]
        item.audioMix = mix; attached = true
    }

    private func configure(_ description: AudioStreamBasicDescription) {
        format = description
        let rate = max(1, description.mSampleRate)
        window = max(1, Int(rate / 20)); frames = 0; low = 0; dc = 0; sum = 0; bassSum = 0
        lowAlpha = 1 - exp(-2 * .pi * 220 / rate); dcAlpha = 1 - exp(-2 * .pi * 30 / rate)
    }
    private func consume(_ pointer: UnsafeMutablePointer<AudioBufferList>, frames count: Int) {
        guard format.mFormatID == kAudioFormatLinearPCM else { return }
        let floating = format.mFormatFlags & kAudioFormatFlagIsFloat != 0
        let bits = Int(format.mBitsPerChannel), bytes = bits / 8
        guard (floating && bits == 32) || (!floating && bits == 16) else { return }
        let buffers = UnsafeMutableAudioBufferListPointer(pointer)
        for frame in 0..<count {
            var mono = 0.0, power = 0.0, channels = 0
            for buffer in buffers {
                guard let data = buffer.mData else { continue }
                let n = Int(buffer.mNumberChannels)
                for channel in 0..<n {
                    let offset = (frame * n + channel) * bytes
                    guard offset + bytes <= Int(buffer.mDataByteSize) else { continue }
                    let raw = floating ? Double(data.load(fromByteOffset: offset, as: Float.self)) : Double(data.load(fromByteOffset: offset, as: Int16.self)) / 32768
                    let sample = raw.isFinite ? raw : 0
                    mono += sample; power += sample * sample; channels += 1
                }
            }
            guard channels > 0 else { continue }
            mono /= Double(channels); power /= Double(channels)
            dc += dcAlpha * (mono - dc); low += lowAlpha * (mono - dc - low)
            sum += power; bassSum += low * low; frames += 1
            if frames >= window {
                let level = min(1, sqrt(sum / Double(frames)) * 0.7 + sqrt(bassSum / Double(frames)) * 3.8)
                // Never block the audio callback while the UI reads the meter.
                if lock.try() { value = level; updated = ProcessInfo.processInfo.systemUptime; lock.unlock() }
                frames = 0; sum = 0; bassSum = 0
            }
        }
    }
    func level(playing: Bool) -> Double {
        lock.lock(); defer { lock.unlock() }
        return playing && ProcessInfo.processInfo.systemUptime - updated < 0.25 ? value : 0
    }
}

