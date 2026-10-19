[Srpski (latinica)](README.md) | [English](README.en.md) | [Русский](README.ru.md)

# Apple TV 17.0.3: region `rs` patch for LG webOS

This offline tool verifies the original `main.js` and `app.js` files using SHA-256 and creates two locally modified copies in a new directory. It does not connect to the TV, Apple, LG, or the network. The repository contains no complete Apple JavaScript files, firmware, binaries, keys, or account data. Modified copies are generated only locally from your original files.

Compatibility is restricted to the exact input SHA-256 values in [patches.json](patches.json), corresponding to Apple TV 17.0.3 on the tested device. The program stops on any mismatch. The generator does not change firmware, the executable, signatures, DRM, the installed TV application, Store settings, or automatic Store updates. An Apple TV application update may replace the patch or make it incompatible; these files must not be reused after any update without a new compatibility check. The persistent changes to both files were verified after an ordinary reboot on one device; a cold power cycle has not been separately tested. Details are in [VALIDATION-RU.md](VALIDATION-RU.md), in Russian. The generator itself does not test application runtime behavior.

The patch adjusts regional service parameters for region `rs` and disables the JSUpdater automatic update path for this exact version. Automatic Store updates remain enabled. This is not a promise of lasting compatibility, successful sign-in, or playback of DRM-protected video.

## Prerequisite: root access on the TV

Before applying changes on the TV, you must already have verified root access. The local offline generator on your computer does not require root; writing application files and migrating to the persistent overlay on the TV do.

The tested device was rooted using [SlopBro by throwaway96](https://github.com/throwaway96/slopbro), at the [historically recorded revision `21023d56ca424607bb03d2939609cc658c655fc7`](https://github.com/throwaway96/slopbro/tree/21023d56ca424607bb03d2939609cc658c655fc7), which installs [webOS Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel). SlopBro is the rooting utility used; Homebrew Channel is the associated tooling installed by that procedure.

Before choosing a root method, check the author's current documentation for support of your exact model, regional suffix, and firmware version. This is not a universal method for every LG TV. Matching Apple TV JS hashes does not establish firmware compatibility with a root method.

Rooting and persistent modifications carry a risk of data loss or a nonfunctional device. Restoring factory firmware through USB is not guaranteed and must not be treated as a reliable recovery plan. This patch's scripts do not perform rooting and do not download or run SlopBro or install Homebrew Channel; preparing root access is a separate step.

## Usage

You need Python 3.9+ and a directory containing the original `main.js` and `app.js`, obtained lawfully from your own TV or backup.

```sh
python3 apply_patch.py --input-dir /path/to/your/original-js --output-dir /path/to/new/local-candidates
```

The output directory must not already exist. The program first verifies both input files and builds both results in memory. Only after verifying both expected output SHA-256 values does it create a new directory and write `main.js`, `app.js`, and `SHA256SUMS.json`. It does not overwrite an existing output directory. Keep generated files local and do not add them to Git.

`patches.json` stores only base and target SHA-256 values, offsets, deletion lengths, SHA-256 values of removed bytes, and Base64-encoded inserted bytes. It contains no original vendor anchor strings, complete Apple files, or surrounding source context. Applying the patch always requires originals with exactly matching SHA-256 values.

## Verification

The following command uses only synthetic test data:

```sh
python3 -m unittest discover -s tests
```

Neither the tests nor the generator modify the TV. Checking real originals confirms only that the result matches a previously prepared modified copy byte for byte; it does not prove runtime behavior, sign-in, or playback.

## License and provenance

The original idea and regional adaptation are related to [mircea1223/lg-appletv-romania](https://github.com/mircea1223/lg-appletv-romania/tree/a0fdd116310305d2d85f14bcdbd321d31b13bd28). Its tool declares SPDX `AGPL-3.0-or-later`; the attribution and that SPDX identifier are retained here for the generator and patch metadata. The upstream Python code and its minified Apple anchor strings were not copied into this package. The full GNU AGPL version 3 text is provided in [LICENSE](LICENSE) and [COPYING](COPYING). SPDX `AGPL-3.0-or-later` applies; the origin of the changes is documented in [PROVENANCE.md](PROVENANCE.md), in English.

The guarded migration from the previous local installation using bind-mount substitutions is in [tv-migration/](tv-migration/). Its prerequisites, limitations, and conditions for restoring the original files are documented separately in [tv-migration/README-RU.md](tv-migration/README-RU.md), in Russian. This package contains neither a universal installer nor complete firmware.

Playback after the latest permanent installation and reboot is still awaiting the owner's verification. Preserved JS files, normal Apple TV application startup, and preservation of Home v6 have been confirmed.
