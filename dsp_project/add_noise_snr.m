function [x, n_scaled] = add_noise_snr(s, noise, snr_db)
s = s(:);
noise = noise(:);
N = length(s);

% make sure noise is long enough, then take a random segment
if length(noise) < N
    noise = repmat(noise, ceil(N / length(noise)), 1);
end
start = randi(length(noise) - N + 1);
n = noise(start : start + N - 1);

% scale noise so that 10*log10(Ps/Pn) = snr_db exactly
Ps = mean(s.^2);
Pn = mean(n.^2);
k = sqrt(Ps / (Pn * 10^(snr_db / 10)));
n_scaled = k * n;

x = s + n_scaled;
end
