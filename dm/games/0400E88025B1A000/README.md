# Star Fox (`0400E88025B1A000`)

A Switch 2 game: update v131072, SDK 21.4.4 built for the Switch 2 (`Ounce`), NVN2 with DLSS. A custom engine (its own prefixes: `vfs`, `vrender`, `vjob`, `vscript`, `vspirv`, `veffects`, `vphysics`; project name `eclipse`), with Wwise 2024.1 for audio, Bullet physics and NPLN for online play. Modules `main`, `sdk`, `subsdk0` (the SDK's movie module), `subsdk3` (`nn::camera`); `subsdk1` (the C library) and `subsdk2` (`NintendoSDK_DLSS`) are shipped but `main` imports nothing from them. **Plays on the Mac** (M4 Pro, 48 GB): the title, the prologue cinematic and the tutorial flight, with sound. The tutorial runs at 56 to 60 fps with a 4K screenshot every 4 s and at 60 without them; the cinematic at 30 fps, which looks like the game's own choice (not checked). Scripted input here reached the tutorial's first lesson and worked its options menus; flying under input has not been watched on this Mac (pull request #1259's author reports 7 minutes of it with a controller on an M5 Max). No IPA has been built.

## What it needs

| Setting | Where | Why |
|---|---|---|
| `mem_alias 0x400000000`, `mem_reserve 0x550000000`, `mem_stack 0x10000000`, `app_pool 0x240000000` | [`game.tsv`](game.tsv) | the Switch 2's 9 GB. The alias region mapped up to +8.26 GB of its 16 GB, 6.78 GB at most at once, through the tutorial's start; 8.5 GB resident, 4 GB of it allocated on the GPU |
| `sys_resource 0x1000000` | `game.tsv` | the NPDM declares 16 MB, so virtual address memory is on; `main` never sets a heap |
| `modules main subsdk0 subsdk3 sdk` | `game.tsv` | `main` imports 17 movie functions from `subsdk0` and 19 `nn::camera` functions from `subsdk3`, nothing from `subsdk1` or `subsdk2` |
| `romfs_marker data.zip` | `game.tsv` | the RomFS has two files, and this is the game |
| `zip_store .zip:.metallib` | `game.tsv` | the archive's members are LZ4-compressed already |
| `shader_groups /data.zip=shader` | `game.tsv` | every shader is a member of the archive |

The resolution override is gated to v131072's build ID. The base game, v0, has not been run.

## Files

- A NUP container of 30 GB: a base package (v0) and an update package (v131072), each with its own ExeFS and RomFS. Neither package carries a NACP or an icon, so the name comes from the profile, the display version is the placeholder `v131072`, and the app has no icon.
- The RomFS is two files: `data.zip` (14.5 GB) and `veclipse_build.cvar` (a JSON line: `system.is_shipping_build: true`). `main` opens `rom:/data.zip` through its own virtual file system (`vfs.zip.c`): [LZ4-chained zip members behind a VZIP preamble](../../../docs/reference/shaders.md#lz4-chained-zip-members-behind-a-vzip-preamble-and-shader-binaries-of-one-stage). Its 114,154 members are named by a 16-digit hash with no folders or extensions; 92,069 are chained, 22,085 (the Wwise `RIFF` sound files and `BKHD` banks) stored plain.
- `main` is 192 MB of code with 1,036 imports, of which the host and the other modules supply all but two (gRPC thread-local initialisers, `_ZTH…`). No shader is in any code module.

## Shaders

2,856 in [`shader_map.tsv`](shader_map.tsv): 1,483 vertex, 1,305 pixel, 68 compute; 2,828 one per archive member, no task or mesh shaders, and the rest from the two NDSR upscaler networks embedded in `VIPR` containers. All of them translate. A build takes about 4 minutes in all on an M4 Pro. Each member is the engine's shader binary (`_vrender_shader_binary_t`), read as a single-stage program and paired at draw time (`separable_pairs`: 1,480 cover pairs).

## The picture

The scene's size, measured with probes (`DM_PROBE_FP`, `DM_PROBE_POLL=as+…`): the renderer (`main+0xb447300`) takes a target and multiplies it by a scale it reads from its settings at `main+0xb4498a8`, `render.resolution_scale_console` 0.5 docked or `render.resolution_scale_handheld` 0.83. It runs DLSS at that size, as anti-aliasing (input = output: `nvnDlssNetworkResize` from `main+0xb75a440`, an output texture of that size), and its NDSR compute networks take the picture to the target. Docked, the target is the window's size (`[obj+0x400]`), or an override at `[obj+0x428]` that the window manager writes right after it reads the graphics scale: 1536x864, 0.8 of 1920x1080, at graphics scale 1. Hence 768x432 (1536x864 x 0.5). Two host answers made it small, each in a pull request of its own: the graphics scale, 1 docked where the full GPU share is 0 (#1304: 960x540), and the display's largest layer, 1920x1080 where a docked Switch 2 on a 4K screen outputs 4K (#1305: 1920x1080 on a 4K screen). Handheld it renders at 1600x900.

**Resolution** (`DM_RESOLUTION_SCALE`, the launcher's Game's own / 75 % / 100 %) replaces that scale in both modes: `patches.py`, a stub at `main+0xb4498ac` in the back patch area (main's text is 189 MB, beyond the front area's reach: `ctx.area`), state +0xa0, offered through the `RESOLUTION_SCALE` capability of build `a7730d0f`. At 0.75 and 1.0 the game evaluates no DLSS. Measured on an M1 Pro, docked, graphics scale 0, 1080p target, 300 s from boot into the tutorial's flight:

| Scale | Scene | Flight: frame p50 | Flight: GPU p50 / p95 | Cinematic (30 fps): GPU p50 |
|---|---|---|---|---|
| Game's own (0.5) | 960x540 | 16.7 ms | 10–11 / 15–16 ms | 22–24 ms |
| 0.75 | 1440x810 | 16.7 ms | 9–11 / 17–19 ms | 17–18 ms |
| 1.0 | 1920x1080 | 16.7 ms | 9–11 / 16–17 ms | 19 ms |

At 1.0 Peppy's close-up (frame 3,000) shows the fur and whiskers sharply that 0.5 blurs.

## Driving it on the Mac

This fork combines upstream pull requests #1304, #1305, #1308, #1310 and #1323 for a Mac app. Its `pso_manifest.tsv` records the title, opening cinematic and flight tutorial (772 unique entries: 393 shader, 367 render-pipeline and 12 compute-pipeline rows). It does not cover the campaign. The host prepares this list before the first frame.

On an M5 Pro with 24 GB, macOS 27.0, handheld mode and Resolution 100% give 1920x1080 scene targets. Physical DualSense steering, firing and the full-window picture were confirmed by the player. One 1,800-frame flight sample took 30.01 s (59.98 fps, no dropped presents); a longer 7,636-frame sample with new assets and diagnostic captures took 130.54 s (58.49 fps, 37 dropped presents). First-use and streaming hitches remain; this does not establish flawless campaign performance or 4K/120 fps. The raw screenshot is the whole 3840x2160 texture; the window crop selects its top-left 1920x1080 picture for display.

`python3 scripts/build_ipa_from_nsp.py <folder> --platform mac` builds the Mac shaders and the host and prints the run command. Headless, through `DM_CTL`: the title is up about 40 s after boot and `A` starts the game. The prologue cinematic follows, about 4 minutes on every run (a save holds no progress yet, and skipping it was not tried), then the tutorial's first question, about 300 s after boot: `LDown`, `A` answers no. Shots of the swap chain hold the picture in their top-left quarter. A `shot` takes about 165 ms: a hitch every few seconds in a run that takes them is the shot's.

## Experimental Mac test modes

The optional selector in `mac_test_launcher.m` offers **1080p — Uncapped**,
**4K — Uncapped**, and **1080p — 120 fps** in one existing test app. All modes use
one RomFS, shader set and save folder. `scripts/configure_starfox_test.py` updates
only that app's executables and rewritten main, backing up changed files only.
It deliberately accepts the isolated `org.nxnative.starfox.120hz-test` bundle,
not the normal app.

The build-gated output stubs use state +0xa4: -1 (unset) runs the original game
paths, 0 selects its zero desired-frame-time path and current-clock update,
and 120 selects its positive 1/120-second interval. The uncapped path bypasses
both output-stage waits; it does not remove a simulation-thread sleep or scale
the game clock. The two refresh fallbacks use 120 only during the experiment;
correct SDK VI refresh/capability service semantics remain open.

Uncapped modes also set `DM_PRESENT_HZ=0`, `DM_PRESENT_LINK=0` and
`DM_PRESENT_VSYNC=0`. This removes software and Metal synchronization limits;
the number of frames the physical screen can display is still finite. 4K uses
docked mode, `DM_VI_BUFFER_MAX=3` and scene Resolution 100%, then scales the
3840x2160 output to the Mac's screen. The 1080p modes use handheld mode and
`DM_VI_BUFFER_MAX=1`. Render-pass dimensions, not screenshot size alone, establish
the scene resolution.

The source is based on the verified Mac integration so the existing shader
libraries remain usable. Build the host with `make -C dm/host GAME=0400E88025B1A000`,
rewrite main with this profile, then run:

```sh
python3 scripts/configure_starfox_test.py '/path/Star Fox 120 Hz Test.app' \
  --patched /path/to/rewritten-main --backup /path/to/new-backup-folder
```

On the M5 Pro 24 GB, macOS 27.0, the player reported roughly 300 fps in the
1080p uncapped flight and confirmed normal movement, aiming and audio. Pass
captures showed 1920x1080 scene color/depth targets in that mode and 3840x2160
scene targets in 4K mode. This is opening-tutorial evidence, not a campaign or
4K frame-rate guarantee.

The test modes remain experimental: frame throughput does not prove correct
movement speed, physics, audio/movie sync or later-level stability.

## Found on this game

- The avatar settings present the virtual camera's picture into an NVN window of their own; the host makes it an off-screen window: [GameChat queries from the title screen (SDK 21)](../../../docs/reference/services.md#gamechat-queries-from-the-title-screen-sdk-21).
- [SDK 21 socket initialization and overloads](../../../docs/reference/services.md#sdk-21-socket-initialization-and-overloads) and [Socket `Poll` and `Select` with nothing to wait on](../../../docs/reference/services.md#socket-poll-and-select-with-nothing-to-wait-on): the game's HTTP thread aborted on a failed `poll`.
- [SDK 21's OutputStream on a virtual output device](../../../docs/reference/audio.md#sdk-21s-outputstream-on-a-virtual-output-device) and [SDK 21's hardware Opus decoder manager](../../../docs/reference/audio.md#sdk-21s-hardware-opus-decoder-manager): its voice and music.
- [GameChat queries from the title screen (SDK 21)](../../../docs/reference/services.md#gamechat-queries-from-the-title-screen-sdk-21): a null read in `nn::chat::GetChattingUid`.
- [The camera commands of SDK 21's own camera module](../../../docs/reference/services.md#the-camera-commands-of-sdk-21s-own-camera-module): the game's own camera module, a console with no camera plugged in.
- [The DLSS network resized](../../../docs/reference/rendering.md#the-dlss-network-resized): `nvnDlssNetworkResize`.
- [TXD through a uniform register kept no handle](../../../docs/reference/shaders.md#txd-through-a-uniform-register-kept-no-handle): 281 pixel shaders, the fur shells among them.
- [A handle pair ORed sampler word first](../../../docs/reference/shaders.md#a-handle-pair-ored-sampler-word-first): 62 pixel shaders.
- [NVN2 compute's separate handles in c\[0\]](../../../docs/reference/shaders.md#nvn2-computes-separate-handles-in-c0): `1002069a331ceded`, dispatched in the prologue.
- [Ampere BMSK and the read of a covered pixel](../../../docs/reference/shaders.md#ampere-bmsk-and-the-read-of-a-covered-pixel): the last 3 shaders, `58046f286de779e1`, `46040940ce0fd49b` and `826168691af2e211`, none asked for in play so far.

## Open

- Native 120 Hz: the host has no takeover for `nn::vi::QueryDisplayCurrentRefreshRate` or `SetDisplay120HzRefreshRateCapability`. SDK 21 rejects the host's display handle, and the game's refresh queries keep their prefilled 60 Hz answer. Exposing 120 Hz still needs correct display semantics and simulation, audio, movie and input checks. No frame-rate unlock is enabled in this fork.

- [The picture](#the-picture): 768x432 docked until #1304 and #1305 are in; the Resolution setting raises the scene above the game's own scale.
- `[RED] DLSS: the game's bias mask (a reactive mask for MetalFX) is not passed on`.
- The game's wake-up eventfd fails (the host refuses `nn::socket::EventFd`), so its HTTP thread polls without a wake-up; harmless offline.
- The campaign was played through its last level, Venom 2, on a Mac (32 GB) with #1304, #1305, #1308 and #1310 in a test build. Without #1310, the GPU ran out of memory at the load of Venom 2's second part (`map_andross`), after 69 minutes of play: the residency set held 972 textures, 23.8 GB, against a recommended working set of 25.5 GB, and every upload batch after that was dropped, so the screen stayed black. Each scene change had uploaded 60 to 86 of the streamed BC7 arrays again, 4 to 5 GB in one frame. On the same route through Venom 2's first part, #1310 removed those uploads: 0 instead of 20 to 26, at about 1.4 GB each. With that build, the player got through the second part. Scripted runs did not reach it, so the memory there was not measured.
- A `pso_manifest.tsv` has not been recorded; `render_cond` not tried; iOS not tested.
- Mario Kart World 1.8.0 has not been run with the camera answers changed for this game.
