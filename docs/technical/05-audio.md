# Complete audio import and runtime

## Corpus and ownership

The implemented pinned `sound/` inventory contains 4,699 playable files: 4,683
Ogg Vorbis, 12 XM, two MOD, and two S3M files, 25,193.749 seconds of runtime
audio (about seven hours). It records 4,189 mono and 510 stereo outputs, 16
tracker conversions, and 29 byte-identical duplicate aliases. Source paths,
media properties, Git blob IDs, and SHA-256 values make these release
invariants.

All playable source files are imported and addressable. Core content activates
only deliberately classified cues; an imported but unused clip remains
available to data/mod definitions and credits rather than being deleted.

Repository layers are:

```text
assets/upstream/goon/sound/          immutable source bytes (Git LFS)
assets/source/goon/audio/            preserved editable/source masters
assets/runtime/goon/audio/           copied/converted runtime media and catalog
assets/runtime/goon/audio/provenance.json and upstream inventory
```

Existing valid Ogg Vorbis is copied byte-for-byte. It is not decoded/re-encoded
for uniformity, loudness, resampling, channel conversion, or metadata cleanup.
LÖVE supports Ogg Vorbis in both static and stream sources
([audio formats](https://love2d.org/wiki/Audio_Formats)).

## Stable IDs and manifest

Every source path receives a committed permanent `ContentId`; an importer may
propose path-derived IDs, but later renames do not change them. Byte-identical
files may share one stored output while every logical alias remains.

```json
{
  "format_version": 1,
  "pack_id": "org.simstation.goon",
  "source_commit": "1b2b...",
  "voice_limit": 64,
  "decoded_cache_mib": 96,
  "buses": ["master", "music", "ambience", "speech", "ui",
            "alarms", "machinery", "sfx"],
  "entries": {
    "org.simstation.goon:audio/sound/machines/firealarm": {
      "id": "org.simstation.goon:audio/sound/machines/firealarm",
      "source_path": "sound/machines/firealarm.ogg",
      "source_commit": "1b2b...",
      "source_sha256": "...",
      "runtime_path": "sound/machines/firealarm.ogg",
      "runtime_sha256": "...",
      "duration_seconds": 2.24,
      "channels": 1,
      "sample_rate": 44100,
      "codec": "vorbis",
      "source_type": "static",
      "bus": "machinery",
      "positional": true,
      "loop": false,
      "loop_start_samples": null,
      "loop_end_samples": null,
      "gain_db": 0,
      "loudness_status": "pending-review",
      "priority": 50,
      "max_instances": 4,
      "cooldown_ms": 0,
      "caption_key": null,
      "rights_basis": "goon-root-license",
      "license": "CC-BY-NC-SA-3.0-US",
      "conversion": null,
      "content_duplicate_of": null
    }
  }
}
```

`duration_seconds` and `gain_db` are non-authoritative presentation metadata;
loop boundaries are integer decoded sample indices. `source_type` is `static`
or `stream`. `positional = true` is valid only for mono world audio; curated
definitions may additionally classify a cue as `radio` or `structural`.
Priorities are 0–100. Before a semantic cue is activated by core content, its
`loudness_status`, bus, loop, gain, priority, limits, and caption must be
reviewed rather than relying on importer defaults. Pure music/continuous
ambience may use a descriptive now-playing key instead of an event caption.

Sound sets select clips without code:

```json
{
  "id": "org.simstation.core:sound-set/alarm/fire",
  "schema": 1,
  "name_key": "sound-set.alarm.fire.name",
  "description_key": "sound-set.alarm.fire.description",
  "tags": ["alarm"],
  "replaces": null,
  "data": {
    "selection": "event-hash",
    "clips": [
      {"id": "org.simstation.goon:audio/sound/machines/firealarm", "weight": 3},
      {"id": "org.simstation.goon:audio/sound/machines/firealarm-alt", "weight": 1}
    ]
  }
}
```

Selection hashes the canonical `event_id`, sound-set ID, and occurrence index,
then performs integer weighted choice. It never consumes simulation RNG.

## Validation and conversion

The implemented entry points are:

```text
python3 tools/assets.py fetch-goon
python3 tools/assets.py build-audio
python3 tools/assets.py audit
```

`python3 tools/assets.py all` rebuilds both media forks.

For Ogg inputs, the tool verifies container, Vorbis codec, decodability,
duration, channel count, sample rate, peaks, and tags, then copies the original.
An invalid/truncated file fails the import. A necessary repair creates a new
output, preserves the original, records the reason and exact command, and
requires audible review.

Tracker modules are source/provenance only. Pin FFmpeg and libopenmpt versions,
render one finite duration reported by libopenmpt at 48 kHz stereo, remove
container metadata, and encode Vorbis quality 5. The implemented converter
currently invokes:

```text
ffmpeg -v error -y -i <input> -map_metadata -1 -ar 48000 -ac 2 \
  -c:a libvorbis -q:a 5 <output.ogg>
```

The tool invokes arguments directly, never a shell string. Because FFmpeg's
Ogg muxer chooses a randomized stream serial, the compiler then replaces it
with a source-hash-derived serial and recomputes every Ogg page CRC. Conversion
metadata records a repository-relative placeholder recipe rather than
machine-specific absolute paths. Independent regeneration now produces
byte-identical Ogg output for all 16 trackers.

Before M2 exits it must also lock binary/library versions, add decoded PCM
fingerprints, record the selected libopenmpt demuxer and subsong, and fail
rather than silently selecting a different decoder. Multiple subsongs require
explicit manifest entries and separate outputs.

Tracker looping defaults to whole rendered output only after a human verifies
the boundary. Otherwise it is nonlooping. Curated loop points are sample
indices recorded in metadata; no runtime parser attempts to recover tracker
patterns.

Loudness analysis writes metadata, not modified Vorbis:

| Class | Initial integrated target |
|---|---:|
| music | −16 LUFS |
| speech/announcements | −18 LUFS |
| ambience | −24 LUFS |
| one-shot SFX | manual peak and semantic review |

Gain is clamped so predicted true peak stays at or below −1 dBTP. Any gain over
+12 dB or below −24 dB requires review. Runtime gain is the sum of clip, bus,
distance/acoustic, incident, and user gain, clamped before applying to a Source.

Mono derivatives are allowed only when a stereo master must be spatialized and
review confirms it contains no meaningful stereo image. The derivative uses
equal-power downmix, records its conversion, and leaves the master intact.

## Runtime source policy

Static clips are ten seconds or shorter unless explicitly overridden. On first
use, create a static prototype `Source`; overlapping playback uses
`Source:clone` or a bounded pool. Decoded cache cost is
`samples × channels × bytes-per-sample` reported by decoded `SoundData`, not
compressed size.

- Default decoded static-cache budget: 96 MiB.
- Evict least-recently-used idle prototypes between frames.
- Active and scheduled sources are pinned.
- A cue larger than 16 MiB decoded defaults to stream even if short.
- Music, ambience, advertisements, long speech, and loops use stream Sources.
- Stream buffers and filesystem access are presentation state and excluded
  from saves.

LÖVE distinguishes static preload and streamed decode through `SourceType`
([`newSource`](https://love2d.org/wiki/love.audio.newSource),
[`SourceType`](https://love2d.org/wiki/SourceType)).

## Buses, voices, and stealing

Logical buses are `master`, `music`, `ambience`, `speech`, `ui`, `alarms`,
`machinery`, and `sfx`. Each source's effective gain multiplies master, its bus,
and cue/acoustic gain. User bus settings persist in preferences, not campaigns.

At most 64 voices play concurrently. Admission first enforces per-cue
`cooldown_ms` and `max_instances`; event projection separately coalesces
repeated events in the same room/tick. When full, choose the lowest tuple:

```text
priority class, audibility, start tick, cue ID, event ID
```

Priority classes from highest to lowest are:

1. UI confirmation, critical alarms, and intelligible speech;
2. immediate visible gameplay;
3. ordinary gameplay and machinery;
4. ambience and incidental flavor.

A new cue steals only a strictly lower-priority voice, or the stable oldest
voice in its own class if its definition permits same-class replacement.
Critical/UI reserved capacity is eight voices. A rejected or stolen cue affects
presentation only.

At 2×/4×, repeated machine/work cues within five simulation ticks and one room
are coalesced into one cue with capped gain; critical alarms and speech are not
time-compressed. Pausing fades world/machinery/ambience to −24 dB over 100 ms
while leaving UI and pause-menu preview audible. Music pause behavior is a user
setting defaulting to continue quietly.

## Spatial and station acoustics

Only mono clips use world positioning. Stereo music, ambience beds, and
announcements are non-positional. The camera center is the listener.

For `world-mono`:

1. Cull sources outside the current viewed map unless routed as radio.
2. Calculate distance from tile centers; full gain through 4 tiles, then
   inverse-distance attenuation to silence at 32 tiles.
3. Traverse the deterministic room/portal graph from source to listener with a
   maximum of eight portals.
4. Apply −2 dB per open portal, −12 dB and a low-pass filter per closed ordinary
   door, and −18 dB per reinforced closed door.
5. If either endpoint room is below 20,000 Pa, mute airborne sound. A
   `structural` cue instead uses −24 dB and strong low-pass when connected by
   station structure.
6. Pan/position the mono source relative to camera coordinates and clamp the
   final value.

Camera/sensor feeds do not automatically transmit ordinary audio. A powered,
data-connected microphone or radio route creates a non-positional `radio` cue
with static/quality metadata. Thus sound follows the same information model as
visual knowledge rather than granting omniscience.

Room revisions invalidate cached acoustic paths. Path caches affect only
presentation, so their eviction/order cannot affect simulation.

## Device loss and accessibility

Audio initialization or device loss must not block loading or simulation. Stop
and discard presentation Sources, show one diagnostic, then allow device
reinitialization from settings. Missing media substitutes silence while still
showing its caption.

Caption events include localized description, direction arrow, near/far class,
speaker/cue category where known, and persistent alarm state. Captions obey
visibility and microphone rules. Independent sliders, mute toggles, dynamic
range presets, mono mix, and flashing-alarm alternatives are required.

## Mod audio safety

Packaged mods ship valid Ogg plus a compiled manifest. Loose development audio
may be validated at title-screen reload, never during a simulation frame.
Archive limits are 32 MiB per compressed audio file, 512 MiB total compressed
audio, and two hours per clip. The loader verifies hashes and declared decoded
properties before creating a Source. Unknown codecs, tracker modules, absolute
paths, and network URLs are rejected at runtime.

## Verification and provenance

- Inventory every playable source and fail on an unexplained addition/removal.
- Decode every runtime clip on Windows, Linux, and macOS.
- Verify copied Ogg hashes exactly equal source hashes.
- Render trackers twice and compare Ogg bytes and decoded PCM fingerprints.
- Verify duration, sample count, channel/spatial rules, loop seams, loudness,
  true peak, captions, cooldowns, and instance caps.
- Stress 64 voices, the 96 MiB cache, device loss, rapid camera movement, 4×
  event coalescing, vacuum, closed doors, and missing files.
- Generate complete human credits and per-file provenance.

## Implemented foundation

`tools/assets.py` has copied all 4,683 valid Vorbis inputs byte-for-byte,
converted the 16 tracker files, and emitted the 4,699-entry runtime/provenance
catalog. All 4,699 entries are currently marked `pending-review` for loudness
and most captions/classifications remain importer defaults.

A generated 12 KiB foundation selection maps 11 cues to simulation events.
The adapter lazy-creates Sources, applies bus gain and cooldown/per-cue limits,
and uses priority/age eviction under a 32-voice cap. `verify-audio` hashes every
entry, proves the 4,683 copied Ogg files remain byte-identical, probes tracker
outputs, and confirms the seven-hour catalog duration. Full curation,
stream/cache budgeting, camera-relative acoustics, captions, device recovery,
and the 64-voice target stress gate remain M2 work.

The owner-selected rights basis and incompatible-evidence stop rule are
documented in [audio rights risk](../legal/audio-rights-risk.md). The importer
must also retain Goonstation's pinned
[audio guidelines](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/.github/AUDIO_GUIDELINES.md)
and [root license](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/LICENSE).
