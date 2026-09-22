# v0.3.1-alpha — hardware-verified first release

AWGUS adds native Gravis UltraSound GF1 music and sound effects to two exact
DOS releases of *Another World* / *Out of This World* without modifying the
game files on disk.

## Highlights

- Hardware-tested through the complete intro and into gameplay on an AMD
  386DX-40 with a 1 MiB GUS MAX.
- Supports the identified `ANOTHER.EXE` (20,788 bytes, CRC-32 `23726B6B`) and
  `WORLD.EXE` (21,316 bytes, CRC-32 `06098240`).
- Preloads all sound resources on a complete 1 MiB card and reserves the upper
  256 KiB as a fallback cache.
- Uses four GF1 voices at a 44.1 KHz GF1 output rate.
- Reduces 386 interrupt overhead with 16-tick synchronization batches and a
  fixed-point fast path.
- Provides hard alternating stereo by default, centered playback with `/P:C`,
  and four explicit GF1 pan positions with `/P:n,n,n,n`.
- Strictly verifies the packed executable and materialized runtime regions
  before installing temporary in-memory hooks.
- Restores interrupt vectors and silences its GF1 voices when the game exits.

## Installation

Download `AWGUS-0.3.1-alpha.zip`, select Sound Blaster at 10 KHz in the game's
setup program, initialize the GUS normally, and copy the matching launcher into
the game directory. Use `AWGUS.COM` with `ANOTHER.EXE` or `OTWGUS.COM` with
`WORLD.EXE`.

## Verification

The release binaries are reproducible with NASM 2.16.01:

- `AWGUS.COM` SHA-256:
  `195753ce7755edce3dec7d7b850f47e2a85a4532eb55c1d77f26867398839839`
- `OTWGUS.COM` SHA-256:
  `2803f901dd0e7c1ffb696c4699d99903fb84f494be8c2ed984f2711df1e15dfe`

The release contains no game executable, code, music, samples, graphics, text,
runtime dump, or other game asset. A legally installed supported game version
is required.

## Known limits

Physical testing currently covers one 386DX-40 and one 1 MiB GUS MAX. Other
GF1 cards, clones, RAM sizes, and the 5 KHz game setting need further testing.
The command-line pan paths pass emulator integration tests, but their audible
placement has not been separately characterized on physical hardware.
