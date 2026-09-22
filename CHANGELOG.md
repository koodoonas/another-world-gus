# Changelog

## 0.3.1-alpha - 2026-09-22

- Restored the `ANOTHER.EXE` single-channel stop return to `03EADh`, the value
  used by the hardware-tested build that continued into gameplay. Version
  0.3.0 had changed it to the adjacent, unverified `03EACh` and then froze at
  the end of the intro on the user's 386.
- Added a second-line loading message before sound-bank preload. The launcher
  clears that line and replaces it with the existing preload success or
  fallback-cache result.
- Kept the working `WORLD.EXE` stop-return address and audio path unchanged.
- Confirmed both supported launchers through the complete intro transition and
  continued gameplay on an AMD 386DX-40 with a 1 MiB GUS MAX.

## 0.3.0-alpha - 2026-09-22

- Fixed the `OTWGUS.COM` post-intro freeze by returning the single-channel
  stop hook through the original `STI` cleanup instruction instead of after
  it. The equivalent `AWGUS.COM` return point was corrected as well.
- Added startup preload of every type-0 sound resource when a complete 1 MiB
  GF1 RAM layout is detected. The first 768 KiB holds packed variable-length
  samples; the top 256 KiB remains a four-slot fallback cache.
- Added an independently implemented in-place ByteKiller decoder for packed
  BANK resources, including the format's CRC check.
- Replaced sixteen ordinary shadow-position updates with one 8.8 fixed-point
  batch update when no sample boundary is crossed. Boundary cases retain the
  exact tick-by-tick loop and one-shot behavior.
- Added constant-time resource-to-preload mapping and validated per-channel
  lookup caches. The `ANOTHER.EXE` profile uses content signatures because its
  live resource-table mapping was not revalidated in the current workspace.
- Treats a transient, half-updated sample descriptor as a silent voice to be
  retried on the next batch instead of recording a fatal runtime error.
- Extended active-audio diagnostics to cover the intro transition, stop hook,
  continued mixer activity, preload hits and misses, fallback uploads, and
  32-bit timer/batch counts.

## 0.2.0-alpha - 2026-09-22

- Added a strict `OTWGUS.COM` profile for the identified U.S. `WORLD.EXE`
  release (21,316 bytes, CRC-32 `06098240`).
- Reduced mixer-hook CPU load by performing full four-channel synchronization
  every 16 output ticks while retaining the game's original timer rate.
- Changed the default layout to hard alternating pan: voices 0/2 left and 1/3
  right.
- Added `/P:C`, `/P:n,n,n,n`, and `/?` launcher options.
- Added install, active-audio, and command-line integration coverage for the
  `WORLD.EXE` profile.

## 0.1.0-alpha - 2026-09-22

- Added strict identification of the supported `ANOTHER.EXE`.
- Added temporary in-memory hooks for the game's four-channel audio engine.
- Added on-demand signed 8-bit sample upload and GF1 RAM caching.
- Added GF1 start, stop, pitch, volume, loop, and position synchronization.
- Added 256 KiB and 1 MiB cache layouts.
- Added standard `ULTRASND` parsing and GF1 RAM probing.
- Kept the GUS MAX codec and board-level analog mixer/interface untouched.
- Added launcher cleanup and interrupt-vector restoration.
- Passed install-only and active-voice DOSBox integration tests.
