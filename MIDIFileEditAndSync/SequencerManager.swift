// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AudioKit
import Foundation

class SequencerManager {
    let engine = AudioEngine()
    var seq: AppleSequencer?
    let oscBank = Synth(attackDuration: 0.01, decayDuration: 0.03)
    let mixer = Mixer()
    var node: MIDINode!

    let minLoopLength = Duration(beats: 4)

    init() {
        setUpSequencer()
        startAudioKit()
    }

    fileprivate func setUpSequencer() {
        seq = AppleSequencer(filename: "D_mixolydian_01")
        seq?.setLength(minLoopLength)
        seq?.enableLooping()
        node = MIDINode(node: oscBank)
        seq?.setGlobalMIDIOutput(node.midiIn)
        mixer.addInput(oscBank)
        engine.output = mixer
    }

    fileprivate func startAudioKit() {
        do {
            try engine.start()
        } catch {
            Log("Couldn't start AudioKit")
        }
    }

    // MARK: - Interface
    func play() {
        seq?.rewind()
        seq?.play()
    }

    func stop() {
        seq?.stop()
    }

    func getURLwithMIDIFileData() -> URL? {
        guard let seq = seq,
            let data = seq.genData() else { return nil }
        let fileName = "ExportedMIDI.mid"
        do {
            let tempPath = URL(fileURLWithPath: NSTemporaryDirectory().appending(fileName))
            try data.write(to: tempPath as URL)
            return tempPath
        } catch {
            Log("couldn't write to URL")
        }
        return nil
    }

    func sequencerTracksChanged() {
        guard let seq = seq else { return }
        if seq.length < minLoopLength {
            seq.setLength(minLoopLength)
        }

        if seq.loopEnabled {
            seq.enableLooping()
        }

        seq.setGlobalMIDIOutput(node.midiIn)
    }

    // MARK: - MIDI editing
    // general helper to alter MIDINoteData arrays for selected tracks
    fileprivate func modifyNotesInSelectedTracks(_ selectedTracks: Set<Int>,
                                                 modification: (MIDINoteData) -> MIDINoteData) {
        guard let seq = seq else { return }
        for (i, track) in seq.tracks.enumerated() {
            if selectedTracks.contains(i) {
                var result = track.getMIDINoteData()
                for (j, note) in result.enumerated() {
                    result[j] = modification(note)
                }
                track.replaceMIDINoteData(with: result)
            }
        }
    }

    func filterNotes(_ selectedTracks: Set<Int>,
                     filterFunction: (MIDINoteData) -> MIDINoteData) {
        modifyNotesInSelectedTracks(selectedTracks, modification: filterFunction)
    }

    func doubleTrackLengths(_ selectedTracks: Set<Int>) {
        modifyNotesInSelectedTracks(selectedTracks) { note in
            var newNote = note
            newNote.position = Duration(beats: note.position.beats * 2)
            newNote.duration = Duration(beats: note.duration.beats * 2)
            return newNote
        }
    }

    func halveTrackLengths(_ selectedTracks: Set<Int>) {
        modifyNotesInSelectedTracks(selectedTracks) { note in
            var newNote = note
            newNote.position = Duration(beats: note.position.beats / 2)
            let newDuration = note.duration.beats / 2
            // very weird things happen when durations get shorter than the default PPQN of 24
            if newDuration >= 1 / 24 {
                newNote.duration = Duration(beats: newDuration)
            } else {
                Log("Note is already too short")
            }
            return newNote
        }
    }

    func shiftRight(_ selectedTracks: Set<Int>) {
        modifyNotesInSelectedTracks(selectedTracks) { note in
            var newNote = note
            newNote.position = Duration(beats: note.position.beats + 1)
            return newNote
        }
    }

    func shiftLeft(_ selectedTracks: Set<Int>) {
        modifyNotesInSelectedTracks(selectedTracks) { note in
            var newNote = note
            newNote.position = Duration(beats: note.position.beats - 1)
            return newNote
        }
    }

    func deleteSelectedTracks(_ selectedTracks: Set<Int>) {
        guard let seq = seq else { return }
        seq.stop()
        var trackIndices = selectedTracks.sorted()
        while trackIndices.isNotEmpty {
            let index = trackIndices[0]
            seq.deleteTrack(trackIndex: index)
            trackIndices.removeFirst()
            for i in 0 ..< trackIndices.count {
                trackIndices[i] -= 1
            }
        }
        seq.setGlobalMIDIOutput(node.midiIn)
    }
}
