function [snr_db, seg_snr] = compute_metrics(s, y, fs)
s = s(:);
y = y(:);

% --- delay alignment ---
maxlag = 600;                       % samples (~37 ms at 16 kHz)
L0 = min(numel(s), numel(y));
[c, lags] = xcorr(y(1:L0), s(1:L0), maxlag);
[~, i] = max(c);
m = lags(i);                        % y lags s by m samples
if m > 0
    y = y(m + 1:end);
elseif m < 0
    s = s(-m + 1:end);
end
L = min(numel(s), numel(y));
s = s(1:L);
y = y(1:L);

% --- overall SNR ---
e = s - y;                          % leftover noise + any speech damage
snr_db = 10 * log10(sum(s.^2) / (sum(e.^2) + eps));

% --- segmental SNR (20 ms frames, per-frame SNR clipped to [-10, 35] dB) ---
fl  = round(0.02 * fs);
nfr = floor(L / fl);
v = zeros(nfr, 1);
for i = 1:nfr
    ix = (i - 1) * fl + (1:fl);
    v(i) = 10 * log10((sum(s(ix).^2) + eps) / (sum(e(ix).^2) + eps));
end
v = min(max(v, -10), 35);
seg_snr = mean(v);
end
