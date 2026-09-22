# Validation record

This record separates checks that were actually completed from work that still
requires physical hardware.

## Completed

### Reproducible release builds

- Assembler: NASM 2.16.01
- Flags: `-w+all -Werror -f bin`
- `AWGUS.COM`: 11,808 bytes, SHA-256
  `195753ce7755edce3dec7d7b850f47e2a85a4532eb55c1d77f26867398839839`
- `OTWGUS.COM`: 12,080 bytes, SHA-256
  `2803f901dd0e7c1ffb696c4699d99903fb84f494be8c2ed984f2711df1e15dfe`

Both release profiles and all four install/audio test variants assembled with
warnings treated as errors.

### Target identification

- `ANOTHER.EXE`: 20,788 bytes, CRC-32 `23726B6B`.
- `WORLD.EXE`: 21,316 bytes, CRC-32 `06098240`.

Each launcher's runtime checksum set was independently derived from the
materialized image of that exact executable. Neither executable nor runtime
image is included in the project.

### Earlier `ANOTHER.EXE` integration coverage

The 0.1.0 `ANOTHER.EXE` profile passed install/cleanup and active-audio tests
under DOSBox 0.74-3. That run required at least 256 mixer hooks, a real sample
upload, a live GF1 voice, no runtime error, and successful parent cleanup. It
reached `PASS` after approximately 19.2 seconds.

The exact `ANOTHER.EXE` was not available during the 0.2.0 validation pass, so
the new shared batching path was not rerun against that profile. The profile
still assembles with warnings as errors; its address/checksum map is unchanged.

### Current `WORLD.EXE` integration coverage

The 0.3.1 `OTWGUS.COM` profile was tested with the exact identified
`WORLD.EXE` under DOSBox 0.74-3 with GUS emulation and EMS disabled.

The install-only variant passed all of these gates:

- packed-file size and CRC-32;
- GF1 probe and sample-RAM detection;
- all runtime rolling checksums;
- patch installation;
- child-to-parent return, GF1 silence, and vector restoration.

The transition-aware active-audio variant could report `PASS` only after:

- at least 256 raw mixer-hook calls;
- at least one completed 16-sample synchronization batch;
- at least one live GF1 hardware voice;
- all 97 sound resources were preloaded;
- at least one single-channel stop hook executed;
- mixer activity continued after that stop hook;
- no recorded runtime error;
- child return through launcher cleanup.

The default hard-pan run reached `PASS` after 1,549,540 mixer hooks and 96,846
complete batches, leaving four pending ticks as expected. It observed 692 voice
starts, 692 preload hits, four single-channel stops, two global stops, zero
preload misses, zero fallback cache uploads, zero runtime failures, and zero
transient descriptors. This proves the corrected stop return was followed by
continued timer activity in the emulator.

The captured startup stream also contained the temporary loading notice,
followed by a carriage-return clear and the normal preload-success line.

An independent decoder check unpacked all 97 compressed/uncompressed sound
resources, validated each ByteKiller CRC, and verified each sample header fit
inside its decoded resource. The payload total was 699,090 bytes. The live
integration run then found all 692 requested samples in the preload table.

Install tests also passed with `/P:C` and `/P:1,2,14,15`.
`/P:16,2,3,4` was correctly rejected, and `/?` returned a successful syntax
summary.

### Initial user test

The user reported that 0.1.0 produced working sound and intro SFX with correct
event timing, but the music ended before the visibly slowed intro. After the
0.2.0 batching change, the user reported correct synchronization in both
versions. `AWGUS.COM` entered gameplay; `OTWGUS.COM` froze after the intro.
Inspection showed that the OOTW single-channel stop hook resumed one byte after
the original `STI`. Version 0.3.0 resumes at `STI`; the transition-aware
emulator test above passed, but the repair still needs confirmation on the
same physical machine.

### Subsequent 0.3.0 hardware result

The user reported that sound-bank preload worked in both releases.
`OTWGUS.COM` completed the intro and operated normally. `AWGUS.COM` instead
froze after the intro. Relative to the earlier AW build that entered gameplay,
0.3.0 had changed only this release's common stop return from `03EADh` to the
adjacent, unverified `03EACh`. Version 0.3.1 restores `03EADh`; that correction
was subsequently confirmed on hardware.

### Final 0.3.1 hardware result

The user reported that both launchers now work correctly through the complete
intro transition and into gameplay. Sound-bank preload works in both profiles.
Testing used an AMD 386DX-40 and a 1 MiB GUS MAX configured as
`ULTRASND=240,7,7,7,7`.

## Not completed

- Audible placement of `/P:C` and custom pan values was not specifically
  characterized on hardware; their parsing and launch paths pass emulator
  integration tests.
- No captured waveform comparison against original Sound Blaster output.
- Audible balance, clicks at starts and loops, long-session fallback behavior,
  startup preload duration, and real-machine output remain incompletely
  characterized.
- 256 KiB and partially populated 512/768 KiB cards have not been tested.
- The 5 KHz game configuration has not received an active-audio integration
  run.
- The updated `ANOTHER.EXE` profile was hardware-tested but was not rerun under
  DOSBox because that exact executable is unavailable in the private emulator
  workspace. Its preload lookup uses the conservative signature path rather
  than an inferred resource-table address.

## Suggested physical test sequence

1. Cold boot with the normal GUS initialization and known-good mixer settings.
2. Confirm `ULTRASND` and ordinary GF1 playback before starting the launcher.
3. Run the matching game in 10 KHz mode and watch/listen through the full intro.
4. Compare default hard pan with `/P:C` and one custom four-value layout.
5. Check music, effects, retriggering, looping ambience, and scene-change
   silence.
6. Exit normally and confirm that DOS remains stable and GF1 voices are quiet.
7. Record any remaining visual/music drift, lock, delayed frame, pitch error,
   click, missing voice, or balance problem with scene and approximate time.
