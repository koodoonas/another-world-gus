AWGUS 0.3.1-alpha
=================

Experimental native GF1 music and sound effects for two exact DOS builds of
Another World / Out of This World.

WARNING
-------

Both supported releases complete the intro and continue into gameplay on the
hardware-tested AMD 386DX-40 with a 1 MiB GUS MAX. This remains an alpha because
other GF1 cards, clones, RAM sizes, and executable variants are not yet tested.
Keep the original game and saved games backed up while evaluating it.

SUPPORTED EXECUTABLES
---------------------

AWGUS.COM:
  ANOTHER.EXE  20,788 bytes  CRC-32 23726B6B

OTWGUS.COM:
  WORLD.EXE    21,316 bytes  CRC-32 06098240

Other builds are rejected. Neither launcher modifies the game on disk.

SETUP
-----

1. Run CONFIG.EXE or SETUP.EXE, as supplied, and select:
     VGA
     Sound Blaster at 10 KHz
     Keyboard or joystick, as preferred

2. Initialize the GUS normally and make sure ULTRASND is set. Example:

     SET ULTRASND=240,7,7,7,7

3. Put the matching launcher in the directory containing CONFIG.DAT:

     AWGUS.COM   for the listed ANOTHER.EXE
     OTWGUS.COM  for the listed WORLD.EXE

4. Run AWGUS or OTWGUS, respectively.

Default stereo layout is hard alternating pan: voices 0/2 left and 1/3 right.
To center all four voices:

     AWGUS /P:C

For custom GF1 positions (0=left, 15=right):

     AWGUS /P:0,5,10,15

Use OTWGUS in the same commands for WORLD.EXE. Run either launcher with /?
for syntax.

If the game warns that a memory manager was detected, press 1 to continue in
the normal audio mode.

NOTES
-----

* Requires a 386 or later and at least 256 KiB of GF1 sample RAM.
* The GUS MAX codec is not used.
* AWGUS does not write the board-level analog mixer/interface ports. Set up an
  audible GF1 output before launching it.
* Full channel synchronization is batched every 16 sample ticks to reduce
  386 CPU load, with one fixed-point update in the common path. Maximum control
  latency is about 1.6 ms in 10 KHz mode.
* /P:C reproduces the original centered mono placement.
* On a complete 1 MiB GUS, all sound resources are decoded and loaded before
  the game starts. This can add a startup pause but avoids expected in-game
  sample uploads. The top 256 KiB remains available as a fallback cache.
* Cards with less than a complete writable 1 MiB use a four-slot on-demand
  cache; a first-time sample upload can pause on a slow machine.
* GF1 output is configured for 44.1 KHz.
* AWGUS resets the GF1 core. Do not use it while another resident program is
  playing through GF1 voices.

UNINSTALL
---------

Delete AWGUS.COM or OTWGUS.COM. No original game file has to be restored.

LICENSE AND CONTENTS
--------------------

AWGUS is MIT-licensed original compatibility code. The package contains no
game executable, code, music, samples, graphics, text, or other game assets.
The original game is required and is not distributed with AWGUS.
