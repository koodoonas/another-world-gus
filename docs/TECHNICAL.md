# Technical design

## Loader boundary

AWGUS is a small 16-bit DOS COM launcher requiring a 386. The default build
targets one `ANOTHER.EXE`; a compile-time profile produces `OTWGUS.COM` for one
`WORLD.EXE`. Before installing hooks, each launcher checks the exact filename,
size, and CRC-32, shrinks its own memory block, resets and probes the GF1, and
installs temporary interrupt vectors.

The game materializes its executable body at runtime. AWGUS observes the
game's `CONFIG.DAT` open, verifies independent rolling checksums over each
required region, then writes only new branch, return, and software-interrupt
instructions at the verified hook sites. Original bytes are not embedded or
restored; the patched child image disappears when DOS releases it.

## Four-channel shadow engine

The supported games use a self-modifying four-channel mono software mixer.
AWGUS bypasses sample lookup, scaling, summing, and Sound Blaster output while
maintaining the mixer's externally visible channel state:

- 8.8 fixed-point source position and step;
- remaining length;
- intro and loop positions;
- active-channel mask;
- pitch and volume changes;
- single-channel and global stop paths.

The game's audio timer still runs at its selected 5 or 10 KHz rate. Most mixer
hooks take a minimal return path. Every 16 hooks, AWGUS synchronizes all four
voices and advances each shadow channel through 16 source steps. The normal
path performs that 8.8 fixed-point advance in one calculation; only a
sample-end or loop boundary falls back to the exact tick-by-tick transitions.
This reduces the expensive per-interrupt bookkeeping that caused the intro
animation to fall behind during the first user test. Starts, stops, pitch
changes, and volume changes can be delayed by at most one batch (about 1.6 ms
at 10 KHz).

Each active game channel owns the GF1 voice with the same number. The default
pan table is `0,15,0,15` (hard left/right alternating). `/P:C` changes the table
to `7,7,7,7`, and `/P:n,n,n,n` accepts four positions from 0 through 15.

The `WORLD.EXE` single-channel stop hook must return through the original
common cleanup's `STI` instruction at `04116h`. Returning one byte later leaves
hardware interrupts masked and caused its observed intro-transition freeze.
The two releases do not share an identical trailing layout: physical testing
showed that the supported `ANOTHER.EXE` must retain its earlier `03EADh` return
point. The exact AW runtime image was unavailable for static revalidation.

## Sound-bank preload and fallback cache

After detecting all four writable 256 KiB GF1 banks, the launcher scans the
game's `MEMLIST.BIN`, reads every type-0 resource from its `BANKxx` file, and
decodes packed resources into a temporary 64 KiB DOS block. Its in-place
ByteKiller implementation verifies the packed stream's CRC and output length.
The block is released before the game is launched.

Variable-length signed 8-bit payloads are packed into the first 768 KiB of GF1
RAM without crossing a 256 KiB bank boundary. The top 256 KiB remains a
four-slot fallback cache. In the tested `WORLD.EXE` release this preloads all
97 sound resources, totaling 699,090 payload bytes.

`OTWGUS.COM` resolves a live game resource ID, maps it directly to a preload
record, and revalidates its segment on reuse. Both launchers can fall back to
validated length/content signatures, with a per-channel constant-time cache
for repeated starts. The signature route is deliberately used for
`ANOTHER.EXE` because an exact runtime image was not available to revalidate
that release's resource-table address.

If a complete 1 MiB layout is not detected, the launcher instead uses four
64 KiB on-demand cache slots. Cache identity includes the source segment,
lengths, and three small content signatures. Replacement uses the
least-recently-used slot that is not owned by another live channel. The same
cache mechanism handles an unexpected preload miss in the reserved top bank.

GF1 loop endpoints are inclusive. One-shot and looped addresses are therefore
programmed separately, and a channel that wraps in game state is resynchronized
to its GF1 position when necessary.

## Rate and volume conversion

The game's 8.8 source step is converted to the GF1 10-bit frequency control
for a 44.1 KHz GF1 output rate:

`round(step_8_8 * game_rate * 1024 / (256 * 44100))`

The implementation combines the `256` denominator with `1024`, hence its
equivalent multiplier of four.

The original mixer gives each of four channels approximately 8/64 through
16/64 of full-scale gain before summation. AWGUS maps the game's 64 volume
levels to those GF1 current-volume values.

## GF1 ownership

The driver uses voices 0 through 3 and configures the GF1 for fourteen active
voices, which yields a 44.1 KHz output rate. DMA and GF1 IRQs are not used for
sample playback; the corresponding `ULTRASND` fields are parsed and validated
only as part of a standard card configuration.

AWGUS writes GF1 core, voice, and sample-RAM registers. It deliberately does
not program the original card's board-level analog mixer/interface latch or
the GUS MAX codec. Consequently, the card must be initialized before launch,
and any pre-existing mute state remains outside AWGUS's control.

## Timing tradeoffs

On a complete 1 MiB card, PIO transfers occur at launcher startup instead of
the live audio path. The startup is longer, but expected game sample starts do
not pause for transfer. Cards using the fallback cache still perform a
first-request PIO upload with interrupts masked. This avoids GF1
register-selection races and requires no DMA channel or resident IRQ handler,
but it can stall the game.

Batching avoids full channel inspection on 15 of every 16 audio ticks and the
common position path no longer repeats sixteen individual updates, but it does
not remove the game's high-rate timer interrupt. A transient descriptor caught
while the game is changing a channel is treated as silence and retried on the
next batch. A future implementation could move more state maintenance out of
the interrupt path if real hardware still shows visual slowdown.

## Cleanup

On normal child return, the launcher stops the fourteen configured voices and
restores the previous INT 1h, 21h, 60h, 61h, and 62h vectors. It does not try to
reconstruct a previous GF1 playback session.
