const std = @import("std");

const ma = @import("miniaudio");

extern "c" fn puts([*:0]const u8) c_int;
extern "c" fn getchar() c_int;

const State = enum {
    processing,
    err,
    success,
};

var state: State = .processing;
var result_: ma.ma_result = 0;

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();
    var iter = try init.minimal.args.iterateAllocator(alloc);
    _ = iter.next();

    const fname = iter.next() orelse {
        std.debug.print("usage: waz [file.wav]\n", .{});
        return;
    };

    var decoder: ma.ma_decoder = undefined;
    var result = ma.ma_decoder_init_file(fname, null, &decoder);
    if (result != ma.MA_SUCCESS) {
        std.debug.print("Failed to load WAV file.\n", .{});
        return error.AudioLoadFailed;
    }
    defer _ = ma.ma_decoder_uninit(&decoder);

    // 2. Configure the playback device
    var deviceConfig = ma.ma_device_config_init(ma.ma_device_type_playback);
    deviceConfig.playback.format = decoder.outputFormat;
    deviceConfig.playback.channels = decoder.outputChannels;
    deviceConfig.sampleRate = decoder.outputSampleRate;
    deviceConfig.dataCallback = dataCallback;
    deviceConfig.pUserData = &decoder;

    // 3. Initialize the device
    var device: ma.ma_device = undefined;
    result = ma.ma_device_init(null, &deviceConfig, &device);
    if (result != ma.MA_SUCCESS) {
        std.debug.print("Failed to initialize audio device.\n", .{});
        return error.DeviceInitFailed;
    }
    defer ma.ma_device_uninit(&device);

    // 4. Start playback
    result = ma.ma_device_start(&device);
    if (result != ma.MA_SUCCESS) {
        std.debug.print("Failed to start audio device.\n", .{});
        return error.DeviceStartFailed;
    }

    while (true) {
        _ = try init.io.sleep(.fromMilliseconds(100), .real);

        switch (state) {
            .success => break,
            .processing => {},
            .err => {
                const desc = ma.ma_result_description(result_);
                std.debug.print("Failed during playback: {s}\n", .{desc});
                std.process.exit(@intCast(@mod(result_, 256)));
            },
        }
    }
}

fn dataCallback(
    pDevice: ?*ma.ma_device,
    pOutput: ?*anyopaque,
    pInput: ?*const anyopaque,
    frameCount: ma.ma_uint32,
) callconv(.c) void {
    _ = pInput;
    const device = pDevice orelse return;
    const user_data = device.pUserData orelse return;
    const decoder: *ma.ma_decoder = @ptrCast(@alignCast(user_data));

    var readFrames: ma.ma_uint64 = 0;
    result_ = ma.ma_decoder_read_pcm_frames(decoder, pOutput, frameCount, &readFrames);
    state = if (result_ == ma.MA_AT_END)
        .success
    else if (result_ != ma.MA_SUCCESS)
        .err
    else
        .processing;
}

