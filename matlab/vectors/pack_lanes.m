function packed = pack_lanes(signal, lanes, width, frac_bits)
%PACK_LANES Pack scalar fixed-point samples into vector lanes.

sig_int = quantize_signed_frac(signal(:), width, frac_bits);
frames = ceil(numel(sig_int) / lanes);
sig_int(end + 1:frames * lanes, 1) = 0;
packed = zeros(frames, 1, 'uint64');

for frame = 1:frames
    base = (frame - 1) * lanes;
    accum = uint64(0);
    for lane = 1:lanes
        value = int64(sig_int(base + lane));
        if value < 0
            value = value + bitshift(int64(1), width);
        end
        accum = bitor(accum, bitshift(uint64(value), (lane - 1) * width));
    end
    packed(frame) = accum;
end
end
