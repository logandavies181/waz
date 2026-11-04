const std = @import("std");

const ma = @import("miniaudio");

extern "c" fn puts([*:0]const u8) c_int;
extern "c" fn getchar() c_int;

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
    _ = ma.ma_decoder_read_pcm_frames(decoder, pOutput, frameCount, null);
}

pub fn main() !void {
    _ = puts("Playing sound.wav... Press Enter to quit.");

    // 1. Initialize the decoder with your WAV file
    var decoder: ma.ma_decoder = undefined;
    var result = ma.ma_decoder_init_file("sound.wav", null, &decoder);
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

    // Keep the program alive while playing
    _ = getchar();
}
