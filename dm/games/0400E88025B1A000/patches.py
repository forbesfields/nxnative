# StarFox (0400E88025B1A000): the rewriter's patches of this game's own builds. dm/tools/patch_nso.py loads every profile's patches.py and applies those of a module's NSO build ID;
# FRAME_STEP and CAPABILITIES as described there ("Registered patches"). Patches of Nintendo SDK module builds are in dm/tools/sdk_patches.py
from nso_asm import ADRP, B, STP_PRE, LDP_POST

# Resolution scale (state +0xa0, a float the loader writes from DM_RESOLUTION_SCALE; 0 = the game's own). The renderer (main+0xb447300) sizes its scene each frame as its target
# (1920x1080 at graphics scale 0) times a scale it reads from its settings at main+0xb4498a8: render.resolution_scale_console docked (0.5) or render.resolution_scale_handheld
# (0.83), and runs DLSS at that size, as anti-aliasing; its own upscaler (NDSR) then takes the picture to the target. The stub replaces the value read, the load at main+0xb4498ac,
# when the state holds one: the rest (a near-zero value falls back to render.resolution_scale, the minimum with the benchmark scale, GameShare's scales) runs as before. x9, s1
# and the flags are dead there: main+0xb4498b4, +0xb4498b8 and +0xb4498bc set them. With 0 every instruction the game runs is its own
def frame_step(ctx):
    here, emit, site, put, state = ctx.here, ctx.emit, ctx.site, ctx.put, ctx.state
    site(0xb4498ac, 'e0a343bd')                          # ldr s0,[sp,#0x3a0]: the scale read from the settings
    ctx.area(0xb4498ac)                                  # main's text is 189 MB: the back patch area reaches the site
    start = here()
    emit(0xbd43a3e0)                                     # ldr s0,[sp,#0x3a0]   (original)
    emit(ADRP(9, here(), state))
    for w in (0xbd40a121,                                # ldr s1,[x9,#0xa0]    the host's scale
              0x1e202028,                                # fcmp s1,#0.0
              0x5400004d,                                # b.le done (+8)       0: the game's own
              0x1e204020):                               # fmov s0,s1
        emit(w)
    emit(B(here(), 0xb4498b0))                           # done
    put(0xb4498ac, [B(0xb4498ac, start)], 'scene resolution scale from the host (DM_RESOLUTION_SCALE; 0 = the game\'s own)')

    # Optional native quality settings. Zero keeps the original instruction's
    # result. Save both scratch registers, and run SP-relative loads before
    # changing SP. None of these instructions changes the incoming flags.
    def integer_setting(at, original, reg, offset, label, record=None):
        site(at, original.to_bytes(4, 'little').hex())
        ctx.area(at)
        stub = here()
        emit(original)
        emit(STP_PRE(16, 17, 31, -16))
        emit(ADRP(16, here(), state))
        if record is not None:
            emit(0xb9000000 | (record // 4 << 10) | (16 << 5) | reg)  # original value, for bring-up diagnostics
        emit(0xb9400000 | (offset // 4 << 10) | (16 << 5) | 17)  # ldr w17,[x16,#offset]
        emit(0x34000051)                                # cbz w17,+8
        emit(0x2a1103e0 | reg)                          # mov wReg,w17
        emit(LDP_POST(16, 17, 31, 16))
        emit(B(here(), at + 4))
        put(at, [B(at, stub)], label)

    # The engine accepts 512/1024/2048/4096. Override the consumers after their
    # contextual/per-light selection, including reserve pages (native -1=4096).
    for at, original, reg in ((0xb44bd30, 0x12003d08, 8),
                               (0xb453bf8, 0xb85003a9, 9),
                               (0xb4d6f14, 0xb85f03b4, 20),
                               (0xb453b58, 0xb85003b4, 20)):
        integer_setting(at, original, reg, 0xa4, 'native shadow size from DM_SHADOW_SIZE (0 = the game\'s own)')
    integer_setting(0xb8af574, 0xb98003f4, 20, 0xa8,
                    'streaming memory budget in MiB from DM_TEXTURE_BUDGET_MB (0 = the game\'s own)')
    integer_setting(0xb8b838c, 0xb9466ae6, 6, 0xac,
                    'native model LOD plus one from DM_MODEL_LOD (0 = automatic)')
    # Native streaming policy: 1=all, 2=blurry. Apply it consistently to package
    # loading, allocation, updates, renderer state and cleanup from startup.
    for i, (at, original, reg) in enumerate(((0xb3eddb4, 0xb9403be8, 8),
                                             (0xb3fbcf0, 0xb94113f3, 19),
                                             (0xb8af540, 0xb94003e8, 8),
                                             (0xb8af788, 0xb94003e8, 8),
                                             (0xb8afc58, 0xb9407bf8, 24),
                                             (0xb8bdc54, 0xb94733e8, 8))):
        integer_setting(at, original, reg, 0xb8,
                        'native texture streaming policy from DM_TEXTURE_STREAMING (0 = the game\'s own)', 0xc0 + 4 * i)

    # q0 holds the selected integer width/height. Change the renderer's target,
    # before its scaled allocations; the 4K presentation buffers stay the game's.
    at = 0xb448768
    site(at, 'e0b7803d')
    ctx.area(at)
    stub = here()
    emit(STP_PRE(16, 17, 31, -16))
    emit(ADRP(16, here(), state))
    emit(0xb9400000 | (0xb0 // 4 << 10) | (16 << 5) | 17)
    emit(0x34000051)                                    # cbz w17,+8
    emit(0xfd400000 | (0xb0 // 8 << 10) | (16 << 5))    # ldr d0,[x16,#0xb0]
    emit(LDP_POST(16, 17, 31, 16))
    emit(0x3d80b7e0)                                    # str q0,[sp,#0x2d0] (original)
    emit(B(here(), at + 4))
    put(at, [B(at, stub)], 'render target dimensions from DM_SCENE_SIZE (unset = the game\'s own)')

FRAME_STEP = {'a7730d0f74d168d90422354c8317f76f': frame_step}
# The launcher offers DM_RESOLUTION_SCALE (dm/games/settings.tsv) only for this build
CAPABILITIES = {'a7730d0f74d168d90422354c8317f76f': ('RESOLUTION_SCALE',)}

# How general each patch is and could be (dm/tools/docs_patches.py "Binding", listed in docs/agents/game-patches.md): what, its binding now, the loosest it could have (goal),
# purpose, why; blocked or kept: why the gap stays open (cannot close yet, or left open on purpose); checked: what was checked on game files (else a judgement)
BINDING = [
    {'what': 'scene resolution scale', 'now': 'build', 'goal': 'game', 'purpose': 'rendering',
     'why': "the game's own settings read in its renderer",
     'blocked': 'frame-step stubs have no function-matched form yet'},
    {'what': 'native render quality overrides', 'now': 'build', 'goal': 'game', 'purpose': 'rendering',
     'why': 'the engine\'s own shadow, streamer budget, model LOD and target-size consumers',
     'blocked': 'the consumers are identified only in this main build'},
]
