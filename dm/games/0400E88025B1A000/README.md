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

The current profile has build-gated scene and native quality overrides in `patches.py`. Only v131072 has a build row; the base game, v0, has not been run.

## Files

- A NUP container of 30 GB: a base package (v0) and an update package (v131072), each with its own ExeFS and RomFS. Neither package carries a NACP or an icon, so the name comes from the profile, the display version is the placeholder `v131072`, and the app has no icon.
- The RomFS is two files: `data.zip` (14.5 GB) and `veclipse_build.cvar` (a JSON line: `system.is_shipping_build: true`). `main` opens `rom:/data.zip` through its own virtual file system (`vfs.zip.c`): [LZ4-chained zip members behind a VZIP preamble](https://github.com/seedds/nxnative/blob/67f1d005/docs/reference/shaders.md#lz4-chained-zip-members-behind-a-vzip-preamble-and-shader-binaries-of-one-stage). Its 114,154 members are named by a 16-digit hash with no folders or extensions; 92,069 are chained, 22,085 (the Wwise `RIFF` sound files and `BKHD` banks) stored plain.
- `main` is 192 MB of code with 1,036 imports, of which the host and the other modules supply all but two (gRPC thread-local initialisers, `_ZTH…`). No shader is in any code module.

## Shaders

2,856 in [`shader_map.tsv`](shader_map.tsv): 1,483 vertex, 1,305 pixel, 68 compute; 2,828 one per archive member, no task or mesh shaders, and the rest from the two NDSR upscaler networks embedded in `VIPR` containers. A build takes about 4 minutes in all on an M4 Pro. Each member is the engine's shader binary (`_vrender_shader_binary_t`), read as a single-stage program and paired at draw time (`separable_pairs`: 1,480 cover pairs).

## The picture

Every 3D target is 768x432 from the first frame of the title to the tutorial: MetalFX stands in for DLSS at 768x432 to 768x432, the game's NDSR compute networks take that to 1536x864, and the result reaches the 3840x2160 swap chain, whose top-left 1920x1080 holds the picture. The game's own defaults give the reason for the figure, not the cause: `render.dynres_min_scale_x` is 0.5 and `max` 1.0, so 768x432 is the minimum of a 1536x864 base, at 6 to 11 ms of GPU time a frame on the M4 Pro. `gpu_timestamps segment` changes nothing. Whether a console stays there too is not known.

## Driving it on the Mac

`python3 scripts/build_ipa_from_nsp.py <folder> --platform mac` builds the Mac shaders and the host and prints the run command. Headless, through `DM_CTL`: the title is up about 40 s after boot and `A` starts the game. The prologue cinematic follows, about 4 minutes on every run (a save holds no progress yet, and skipping it was not tried), then the tutorial's first question, about 300 s after boot: `LDown`, `A` answers no. Shots of the swap chain hold the picture in their top-left quarter. A `shot` takes about 165 ms: a hitch every few seconds in a run that takes them is the shot's.

## Found on this game

- [SDK 21 socket initialization and overloads](https://github.com/seedds/nxnative/blob/67f1d005/docs/reference/services.md#sdk-21-socket-initialization-and-overloads) and [Socket `Poll` and `Select` with nothing to wait on](https://github.com/seedds/nxnative/blob/67f1d005/docs/reference/services.md#socket-poll-and-select-with-nothing-to-wait-on): the game's HTTP thread aborted on a failed `poll`.
- [SDK 21's OutputStream on a virtual output device](https://github.com/seedds/nxnative/blob/67f1d005/docs/reference/audio.md#sdk-21s-outputstream-on-a-virtual-output-device) and [SDK 21's hardware Opus decoder manager](https://github.com/seedds/nxnative/blob/67f1d005/docs/reference/audio.md#sdk-21s-hardware-opus-decoder-manager): its voice and music.
- [GameChat queries from the title screen (SDK 21)](https://github.com/seedds/nxnative/blob/67f1d005/docs/reference/services.md#gamechat-queries-from-the-title-screen-sdk-21): a null read in `nn::chat::GetChattingUid`.
- [The camera commands of SDK 21's own camera module](https://github.com/seedds/nxnative/blob/67f1d005/docs/reference/services.md#the-camera-commands-of-sdk-21s-own-camera-module): the game's own camera module, a console with no camera plugged in.
- [The DLSS network resized](https://github.com/seedds/nxnative/blob/67f1d005/docs/reference/rendering.md#the-dlss-network-resized): `nvnDlssNetworkResize`.
- [TXD through a uniform register kept no handle](https://github.com/seedds/nxnative/blob/67f1d005/docs/reference/shaders.md#txd-through-a-uniform-register-kept-no-handle): 281 pixel shaders, the fur shells among them.
- [A handle pair ORed sampler word first](https://github.com/seedds/nxnative/blob/67f1d005/docs/reference/shaders.md#a-handle-pair-ored-sampler-word-first): 62 pixel shaders.
- [NVN2 compute's separate handles in c\[0\]](https://github.com/seedds/nxnative/blob/67f1d005/docs/reference/shaders.md#nvn2-computes-separate-handles-in-c0): `1002069a331ceded`, dispatched in the prologue.

## Open

- [The picture](#the-picture): why the 3D stays at 768x432.
- 3 shaders do not translate: Ampere opcodes 0x925 (2 compute shaders, as their first instruction) and 0x21b (1). None has been asked for in play so far.
- `[RED] DLSS: the game's bias mask (a reactive mask for MetalFX) is not passed on`.
- The game's wake-up eventfd fails (the host refuses `nn::socket::EventFd`), so its HTTP thread polls without a wake-up; harmless offline.
- A `pso_manifest.tsv` has not been recorded; `render_cond` not tried; the later levels and combat, and iOS, not tested.
- Mario Kart World 1.8.0 has not been run with the camera answers changed for this game.

## Android bring-up

Experimental Star Fox host based on BananaNative's Android branch. This is not
an established playable port. Vulkan shaders are prepared on the Mac from the
user's dump. The APK's embedded release translator has not been rebuilt for
these added instructions; do not use phone-side Prepare for this build.

The SDK 21 service and audio changes come from nxnative commit 67f1d005.
The scene scale patch comes from the tested Mac integration 913c42eb.
The Android loader accepts `DM_RESOLUTION_SCALE=0.75` or `1` to select the
known path without DLSS evaluation. DLSS control objects are implemented;
actual DLSS evaluation stops with an explicit error because Vulkan has no
replacement here. Lower scene scales need a real replacement before use.

RP5 preflight: Android 13, Snapdragon 865 / Adreno 650, 7.5 GiB usable RAM.
The system driver reports Vulkan 1.1.128 and fails the core requirements.
Turnip 26.0.0 R8 reports Vulkan 1.3.335 and passes the core Vulkan feature
checks. These checks do not establish that Star Fox runs or fits in RAM.

### Armv8 CPU compatibility

The first RP5 launch stopped at `sdk+0x171fdc`, `RETAB`, during
`nnosInitialize`. This CPU does not expose pointer authentication. The Android
rewriter lowers compiler return signing and authentication together and turns
`RETAA`/`RETAB` into ordinary returns. The SDK's 58 `PACGA` instructions guard
saved contexts: their original comparisons and traps remain, and a process-keyed
SipHash-2-4 MAC replaces the unavailable hardware operation. It preserves the
full tagged inputs and the upper-32-bit result format. Signatures are local to
the host process and do not interoperate with hardware QARMA. Unexpected forms
and PACGA operands naming virtualized x18 are rejected. See
[Android pointer authentication](../../../docs/reference/rewriter.md#android-pointer-authentication).

### RP5 quality and stability tests

The Android port reaches the title, the 3D prologue and the flight tutorial.
This does not establish sustained campaign play. Turnip 26.0.0 R8 passed the
600-frame graphics self-test, but repeatedly lost the GPU during the prologue
or tutorial. Moving clears outside render passes avoids its first-scene fault;
robust access, skipping compute, and disabling the command encoder did not
remove the later fault. Turnip 25.3.0 R8 survived a 9-minute launch-to-tutorial run at 540p and a separate run at 720p. It is the selected RP5 driver; this does not prove that every scene is stable.

The build-gated settings preserve the engine's allocation and rendering paths:

- `DM_SCENE_SIZE=960x540`, `DM_RESOLUTION_SCALE=1`: 540p scene, without DLSS evaluation.
- `DM_SHADOW_SIZE=512`: smaller native shadow pages.
- `DM_TEXTURE_STREAMING=2`, `DM_TEXTURE_BUDGET_MB=512`: the engine's blurry streaming policy and budget. The original mode queried on this build was 1 (all).
- `DM_MODEL_LOD=2`: native LOD1, clamped to the model's available levels.
- `DM_OPMODE=0`, `DM_GRAPHICS_SCALE=2`: handheld layout and crop.
- `DM_VK_PASS_CLEARS=0`, `DM_VK_ENC=0`, `TU_DEBUG=sysmem,nolrz`: current driver diagnostic configuration.
- `DM_VK_FSR=1`: scale the result for presentation.

All quality overrides require a restart. Zero keeps each engine setting;
`DM_SCENE_SIZE` is unset for its default. `DM_TEXTURE_STREAMING=2` can reduce
texture detail and does not guarantee a process memory limit. Quality stubs
check the main build ID and original instructions before rewriting.

A 540p first prologue shot reached 27 fps / 33–35 ms GPU time with Turnip 26.
Other prologue shots were slower. The 540p tutorial with Turnip 25.3 reached
60 presented fps in a 60-frame diagnostic sample, about 16 ms GPU time, with
steering observed through the touch controls. A 720p sample on the same driver
and native quality settings reported 49.4 presented fps / 19.53 ms GPU time;
other tutorial samples and screenshots were slower. The smoother 540p preset
is the default for the RP5 test installation. These are different workloads;
there is no claim of a comparable whole-game speedup. The player later accepted
the built-in controls and mostly 60 fps flight, but reached the GPU loss below.
Full campaign and long-term stability remain unchecked.

Build the C# translator from the changed sources with .NET 10 before using
`pack_android.py`; the checked-in translator binaries are not updated by this
source change. Regenerate the tool lock and chain headers with the normal
`tool_lock.py --update-lock` and `dmsh_chain.py --header` / `vk_android_build.py
--header` steps after a different tool build. The supplied prepared library
contains all 2,856 Vulkan shaders, checked by `spirv-val` and the C library
loader. Game data and compiled artifacts are not part of this repository.

The Vulkan translator also drops an unused CullDistance member: its eight
ClipDistance outputs plus that unused member exceeded the RP5's combined limit
of eight. The validation-layer error is absent after this change. The texture
backend offers compatible 32-bit component views for unknown scalar classes;
this enables the observed zero clear of an integer volume. Arbitrary integer
payloads through floating-point views can still lose NaN or denormal bit
patterns and are not established by that zero-clear test.

Player testing reached the tutorial's live-fire exercise. The player reported
good built-in controls and mostly 60 fps with occasional drops, then a crash
after 983 seconds of the run. The log reports `VK_ERROR_DEVICE_LOST` at
submission 50951 and exits deliberately; Android reports EXIT_SELF, with
4.1 GiB PSS / 4.2 GiB RSS, rather than a low-memory kill. Thus Turnip 25.3
is also not established as stable. Save data was copied before stability trials.

One-variable trials on Turnip 25.3 did not fix the fault: `DM_VK_UBWC=0`
failed after 392 seconds, `DM_VK_ZSHARE=0` after 130 seconds, Turnip
`flushall` after 352 seconds, and `IR3_SHADER_DEBUG=nouboopt` after 189
seconds. Turnip `syncdraw` also produced kernel GPU faults before a manual
stop. These elapsed times cover different tutorial routes and do not rank
the settings by reliability.

An unmodified Mesa 26.2.6 source build for API 33 passed the 600-frame
graphics self-test with `android-strict=false` (the strict extension filter
hides its implemented placed-memory dependency on Android 13). The game
still lost the GPU after about 130 seconds. Disabling the replay worker
caused missing text on both drivers and was rejected. Turnip 25.3 and the
baseline 540p preset are restored; none of these trials is a stability fix.

Further one-variable trials also failed. Robust buffer and image access
(`DM_VK_ROBUST=1`) produced two recoverable kernel GPU faults during a
roughly 13-minute tutorial run. A temporary worker timing probe that waited
for each present to be replayed, while retaining the replay thread, kept
text intact and reached 60.2 presented fps / 14.97 ms GPU in the first
lesson, but also produced a kernel GPU fault. The probe was removed.
Removing the forced Turnip `sysmem` mode lost the GPU near 59 seconds,
during the intro. These observations reject the tested settings as fixes;
they do not identify the faulting shader or establish a root cause.

A second temporary probe waited for the last reserved GPU submission at
each worker-backed present. The same first-lesson workload fell to 49.8
presented fps / 14.48 ms GPU, then also lost the GPU. The probe was removed
and the original APK and baseline preset were restored. Thus neither
tested CPU/GPU timing change is a stability fix.

A captured tutorial flight frame now executes all 587 draws in the
standalone replayer after its lazy-buffer-placement fix (see
[Android testing](../../../android/TESTING.md)). Three replays took 14.03,
14.03 and 14.50 ms GPU with no new kernel fault, but all differ from the
captured live image. Core validation reported no error; full GPU-assisted
validation itself faulted without an invalid-access report. GPU-assisted
validation with forced robustness completed at 1706 ms GPU, also without
an invalid-access report, and retained the same image mismatch. These
results do not reproduce or diagnose the game's intermittent hang. All
temporary validation properties were restored. Combat stability is open.
