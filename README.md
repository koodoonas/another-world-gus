# AWGUS

Native Gravis UltraSound audio for the DOS releases of *Another World* and
*Out of This World*.

AWGUS is a DOS launcher that redirects the four-channel audio engine in two
exact game builds to Gravis UltraSound GF1 hardware voices. Music and sound
effects use the GF1 instead of being mixed into an 8-bit Sound Blaster stream
by the CPU.

## Status

**Version 0.3.1-alpha is confirmed working on physical hardware with both
supported game releases.** Music, effects, synchronization, sound-bank
preload, the intro-to-game transition, and continued gameplay were tested on
an AMD 386DX-40 with a 1 MiB GUS MAX. A successful additional real-hardware
test was completed on a 486/133 with a GUS PnP.

The alpha label remains because compatibility beyond these tested systems,
RAM configurations, and exact game executable variants has not been broadly
established.

## Download

For normal installation, download `AWGUS-0.3.1-alpha.zip` from the GitHub
Releases page. The source archive and SHA-256 checksum file are provided beside
it. GitHub's automatically generated source archives do not contain the built
DOS launchers.

## What it does

- verifies the matching game executable before touching the GF1;
- obtains the card resources from the standard `ULTRASND` environment variable;
- probes GF1 sample RAM and selects preload or cache operation accordingly;
- launches the unmodified game and installs narrowly scoped in-memory hooks;
- on a complete 1 MiB card, decodes and preloads all sound resources before
  launching the game, while reserving 256 KiB for unexpected samples;
- otherwise uploads signed 8-bit sample payloads to four 64 KiB cache slots
  on demand;
- maps the original four mono mixer channels to GF1 voices 0 through 3;
- follows channel starts, stops, pitch, volume, position, and loop state;
- batches full channel synchronization every 16 sample ticks and uses one
  fixed-point position update when no boundary is crossed;
- configures fourteen GF1 voices for the chip's 44.1 KHz output rate;
- provides alternating hard pan by default and command-line pan control;
- silences its voices and restores interrupt vectors when the game exits.

The launcher does not modify either executable or any other game file on disk. It
does not contain game code, music, samples, graphics, text, or other game
assets.

AWGUS does not access the GUS MAX codec. It also does not write the original
GUS board-level analog mixer/interface ports, so it is designed not to change
the existing line-input setting. The card must already have an audible GF1
output path; initialize and configure it before running AWGUS.

## Supported targets

Each launcher accepts only its matching executable:

| Launcher | Game executable | Size | CRC-32 |
|---|---|---:|---:|
| `AWGUS.COM` | `ANOTHER.EXE` | 20,788 bytes | `23726B6B` |
| `OTWGUS.COM` | `WORLD.EXE` | 21,316 bytes | `06098240` |

The strict check is intentional. A differently localized, repacked, patched,
or re-released executable is rejected rather than patched at uncertain
addresses.

## Requirements

- a 386 or later CPU;
- DOS and a legally installed copy of the supported game build;
- a card exposing the original GF1 register interface;
- at least 256 KiB of writable GF1 sample RAM;
- a valid five-field `ULTRASND` variable;
- `CONFIG.DAT`, normally created by the game's setup program.

Automated coverage uses DOSBox's GUS emulation. Physical testing covers the
listed `ANOTHER.EXE` and `WORLD.EXE` on a 386DX-40 with a 1 MiB GUS MAX. An
additional 486/133 and GUS PnP configuration has also run the patch
successfully. Compatibility with GUS Classic, ACE, Extreme, PicoGUS, other
clones, and other RAM configurations remains to be established.

## Installation and use

1. Run the game's `CONFIG.EXE` or `SETUP.EXE`, as supplied by that release.
2. Select VGA and **Sound Blaster at 10 KHz**. The keyboard/joystick choice is
   independent of AWGUS.
3. Initialize the GUS using the normal utilities for your card and verify that
   `ULTRASND` is present. For example:

   ```dos
   SET ULTRASND=240,7,7,7,7
   ```

4. Copy the matching launcher into the game directory with `CONFIG.DAT`:

   - use `AWGUS.COM` with the listed `ANOTHER.EXE`;
   - use `OTWGUS.COM` with the listed `WORLD.EXE`.

5. Start the European build with `AWGUS`, or the U.S. build with `OTWGUS`.

The default pan layout is hard alternating stereo: voices 0 and 2 are left,
and voices 1 and 3 are right. Center all voices with:

   ```dos
   AWGUS /P:C
   ```

Use the corresponding `OTWGUS` command for the U.S. build. Four explicit GF1
pan positions (0 = left, 15 = right) can be supplied in voice order:

```dos
AWGUS /P:0,5,10,15
```

Run either launcher with `/?` for the compact syntax summary.

If the game displays its own memory-manager warning, option `1` continues in
the normal audio mode. That prompt is produced by the game, not AWGUS.

To uninstall, delete `AWGUS.COM` or `OTWGUS.COM`. No original file needs to be
restored.

## Current limitations and risks

- Hardware verification currently covers a 386DX-40 with a 1 MiB GUS MAX and
  a 486/133 with a GUS PnP. The GUS PnP RAM population was not recorded.
- Default playback is verified; the `/P:C` and custom pan parsers pass emulator
  integration tests, but their audible placement has not been separately
  characterized on hardware.
- A complete 1 MiB card incurs a startup pause while sound resources are read,
  decoded, and uploaded. The tested `WORLD.EXE` bank contains 97 sound
  resources and 699,090 payload bytes.
- Cards without a complete writable 1 MiB layout use the on-demand cache. An
  unexpected preload miss also uses the reserved fallback cache. A first-time
  large upload can pause a slow machine.
- Interrupts are masked during an on-demand upload to keep GF1 register
  selection atomic. A worst-case upload is just under 64 KiB.
- Full channel synchronization occurs every 16 output ticks. Control changes
  can therefore reach the GF1 up to about 1.6 ms later at 10 KHz, or 3.2 ms at
  5 KHz.
- Default hard pan is intentionally wider than the original mono output. Use
  `/P:C` for the original centered presentation.
- Sample payloads larger than 65,528 bytes are rejected.
- Cards with 256, 512, or 768 KiB use four cache slots in the first 256 KiB. A
  fully detected 1 MiB card uses the preload layout described above.
- AWGUS resets the GF1 core at startup and silences it on exit. Do not run it
  concurrently with a resident program that is using GF1 voices.
- The 5 KHz Sound Blaster game setting is accounted for by the driver but has
  not received the same integration coverage as the recommended 10 KHz mode.

A transient sample descriptor observed while the game is updating a channel
is silenced and retried on the next synchronization batch. A hard lock from an
unknown cause can still prevent the launcher from reporting an error.

## Building

NASM 2.x is required:

```sh
make
```

The results are `build/AWGUS.COM` and `build/OTWGUS.COM`. Equivalent direct
commands are:

```sh
nasm -w+all -Werror -f bin -I src/ -o build/AWGUS.COM src/awgus.asm
nasm -w+all -Werror -D TARGET_OOTW=1 -f bin -I src/ \
  -o build/OTWGUS.COM src/awgus.asm
```

Release sizes and SHA-256 hashes are recorded in `docs/VALIDATION.md` and the
release checksum file.

## Other GUS Patches

[Gravis Ultrasound Game Patches](https://github.com/koodoonas/gus-game-patches-and-fixes)

## AI usage disclosure

These patches have been heavily assisted by AI and, in some cases, developed almost entirely with its help.

I remain ambivalent about AI and its human and environmental costs. But since it’s already here, I might as well use it for something fun until it consumes us all.

## Source and licensing boundary

All distributed source in this repository is newly written compatibility code
under the MIT License. Low-level GF1 routines were adapted from the author's
MIT-licensed PRE2GUS project; see `THIRD_PARTY_NOTICES.md`.

No original game source, executable bytes, runtime dump, resource, asset,
vendor SDK code, or proprietary library is included. The BANK-resource decoder
is an independent implementation. Target addresses, file identifiers, and
independently derived checksums are included only to identify and safely
interoperate with the supported executable.

See `docs/VALIDATION.md` and `docs/TECHNICAL.md` for implementation and test
details. See `CONTRIBUTING.md` before submitting a new executable profile or
test artifact.

## License

MIT. See `LICENSE`.
