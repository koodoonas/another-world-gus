# Contributing to AWGUS

Contributions are welcome, especially independent hardware results and support
for additional legally obtained game builds.

## Building

Install NASM 2.x and run:

```sh
make
```

Warnings are treated as errors. The output files are `build/AWGUS.COM` and
`build/OTWGUS.COM`.

## Bug reports

Include:

- launcher name and version;
- game executable filename, byte size, and CRC-32;
- CPU, GUS model, installed sample RAM, and `ULTRASND` value;
- game sound-rate setting;
- the exact scene and approximate time of the problem;
- whether `/P:C` changes the result;
- whether the machine remains responsive after the fault.

Do not attach a game executable, runtime dump, BANK file, music, sample,
graphic, or other copyrighted game asset to an issue or pull request.

## New executable profiles

A profile must be derived from a legally obtained copy and must use strict
filename, size, CRC-32, and runtime-region verification. Submit only newly
written interoperability code, addresses, checksums, and reproducible analysis
notes. Do not submit original executable bytes or disassembly copied from the
game.

Document emulator coverage separately from physical-hardware results. State
the exact hardware configuration and label anything not directly tested.

## Pull requests

- Keep changes focused and preserve both existing profiles.
- Build both release launchers and all test variants with warnings as errors.
- Update `CHANGELOG.md` and `docs/VALIDATION.md` when behavior changes.
- Confirm that generated packages contain no game files or private test data.
