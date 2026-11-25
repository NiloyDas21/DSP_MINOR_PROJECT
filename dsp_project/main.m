clear; close all; clc;
rng(1);                                  % reproducible noise

%% ---------------- Settings ----------------
fs           = 16000;
speech_files = {'audio/speech1.flac', 'audio/speech2.flac'};
babble_file  = 'audio/babble.wav';
snr_list     = [0 5 10 15];              % input SNRs (dB)
noise_types  = {'white', 'babble'};
filt_names   = {'FIR band-pass', 'IIR Butterworth', 'Spectral subtraction'};
fir_order    = 200;
iir_order    = 4;                        % band-pass => 8th-order filter

if ~exist('results', 'dir'), mkdir('results'); end

%% ---------------- Load clean speech ----------------
speech = cell(1, numel(speech_files));
for i = 1:numel(speech_files)
    [s, fs0] = audioread(speech_files{i});
    s = mean(s, 2);                      % mono
    if fs0 ~= fs, s = resample(s, fs, fs0); end
    speech{i} = s / max(abs(s));
end

%% ---------------- Noise sources ----------------
noise = cell(1, numel(noise_types));
noise{1} = randn(10 * fs, 1);            % white Gaussian noise

if isfile(babble_file)
    [bab, fsb] = audioread(babble_file);
    bab = mean(bab, 2);
    if fsb ~= fs, bab = resample(bab, fs, fsb); end
else
    warning('audio/babble.wav not found: synthesizing babble from the speech clips.');
    Lb  = 10 * fs;
    bab = zeros(Lb, 1);
    for k = 1:6
        sp = speech{mod(k - 1, numel(speech)) + 1};
        sp = repmat(sp, ceil(Lb / numel(sp)), 1);
        bab = bab + circshift(sp(1:Lb), randi(Lb));
    end
end
noise{2} = bab;

%% ---------------- Design filters + response plots ----------------
[b_fir, b_iir, a_iir] = design_filters(fs, fir_order, iir_order);
plot_responses(b_fir, b_iir, a_iir, fs);
fprintf('IIR stable: %d\n', all(abs(roots(a_iir)) < 1));

%% ---------------- Main sweep ----------------
nN = numel(noise_types); nS = numel(snr_list); nF = 3; nC = numel(speech);
out_snr = zeros(nN, nS, nF, nC);
seg_out = zeros(nN, nS, nF, nC);
in_snr  = zeros(nN, nS, nC);             % sanity check: should equal snr_list

for c = 1:nC
    s = speech{c};
    for n = 1:nN
        for k = 1:nS
            x = add_noise_snr(s, noise{n}, snr_list(k));
            in_snr(n, k, c) = compute_metrics(s, x, fs);

            y = {filter(b_fir, 1, x), filter(b_iir, a_iir, x), spec_sub(x, fs)};
            for f = 1:nF
                [out_snr(n, k, f, c), seg_out(n, k, f, c)] = compute_metrics(s, y{f}, fs);
            end
        end
    end
end

disp('Input SNR check (should match snr_list):');
disp(squeeze(mean(in_snr, 3)));

out_m = mean(out_snr, 4);                % average over clips
seg_m = mean(seg_out, 4);

%% ---------------- Results table ----------------
rows = {};
for n = 1:nN
    for k = 1:nS
        for f = 1:nF
            rows(end + 1, :) = {noise_types{n}, snr_list(k), filt_names{f}, ...
                out_m(n, k, f), out_m(n, k, f) - snr_list(k), seg_m(n, k, f)}; %#ok<SAGROW>
        end
    end
end
T = cell2table(rows, 'VariableNames', ...
    {'Noise', 'InputSNR_dB', 'Filter', 'OutputSNR_dB', 'Improvement_dB', 'SegSNR_dB'});
disp(T);
writetable(T, 'results/results_table.csv');

%% ---------------- Main plot: output SNR vs input SNR ----------------
figure('Name', 'Output SNR vs Input SNR', 'Position', [100 100 1000 400]);
for n = 1:nN
    subplot(1, nN, n);
    plot(snr_list, squeeze(out_m(n, :, :)), '-o', 'LineWidth', 1.4); hold on;
    plot(snr_list, snr_list, 'k--');
    grid on; xlabel('Input SNR (dB)'); ylabel('Output SNR (dB)');
    title(['Noise: ' noise_types{n}]);
    legend([filt_names {'No filtering (y = x)'}], 'Location', 'northwest');
end
saveas(gcf, 'results/output_vs_input_snr.png');

%% ---------------- Order sweep (white noise, 5 dB, clip 1) ----------------
s = speech{1};
x = add_noise_snr(s, noise{1}, 5);
fir_orders = 20:20:400;
iir_orders = 1:10;
r_fir = zeros(size(fir_orders));
r_iir = zeros(size(iir_orders));
for i = 1:numel(fir_orders)
    bb = fir1(fir_orders(i), [300 3400] / (fs / 2), 'bandpass', hamming(fir_orders(i) + 1));
    r_fir(i) = compute_metrics(s, filter(bb, 1, x), fs);
end
for i = 1:numel(iir_orders)
    [bb, aa] = butter(iir_orders(i), [300 3400] / (fs / 2), 'bandpass');
    r_iir(i) = compute_metrics(s, filter(bb, aa, x), fs);
end
figure('Name', 'Order sweep', 'Position', [100 100 1000 400]);
subplot(1, 2, 1); plot(fir_orders, r_fir, '-o'); grid on;
xlabel('FIR order'); ylabel('Output SNR (dB)'); title('FIR: order vs output SNR (white, 5 dB in)');
subplot(1, 2, 2); plot(iir_orders, r_iir, '-o'); grid on;
xlabel('Butterworth prototype order n'); ylabel('Output SNR (dB)'); title('IIR: order vs output SNR');
saveas(gcf, 'results/order_sweep.png');

%% ---------------- Spectrograms + audio (white noise, 5 dB, clip 1) ----------------
y_fir = filter(b_fir, 1, x);
y_iir = filter(b_iir, a_iir, x);
y_ss  = spec_sub(x, fs);

sigs   = {s, x, y_fir, y_iir, y_ss};
titles = {'Clean', 'Noisy (white, 5 dB)', 'FIR band-pass', 'IIR Butterworth', 'Spectral subtraction'};
figure('Name', 'Spectrograms', 'Position', [50 50 1200 700]);
for i = 1:5
    subplot(2, 3, i);
    spectrogram(sigs{i}, hamming(512), 384, 512, fs, 'yaxis');
    title(titles{i}); clim([-120 -20]);
end
saveas(gcf, 'results/spectrograms.png');

names = {'clean', 'noisy', 'fir', 'iir', 'specsub'};
for i = 1:5
    v = sigs{i}; v = v / (max(abs(v)) + eps) * 0.9;
    audiowrite(['results/' names{i} '.wav'], v, fs);
end

%% ---------------- Babble demo (clip 1, 5 dB) ----------------
% Placed AFTER filter design and after the sweep, so b_fir/b_iir/a_iir exist
% and the sweep results are unchanged.
s = speech{1};
x_bab = add_noise_snr(s, noise{2}, 5);          % clean speech + babble

y_fir_b = filter(b_fir, 1, x_bab);
y_iir_b = filter(b_iir, a_iir, x_bab);
y_ss_b  = spec_sub(x_bab, fs);

names_b = {'noisy_babble', 'fir_babble', 'iir_babble', 'specsub_babble'};
sigs_b  = {x_bab, y_fir_b, y_iir_b, y_ss_b};
for i = 1:4
    v = sigs_b{i} / (max(abs(sigs_b{i})) + eps) * 0.9;
    audiowrite(['results/' names_b{i} '.wav'], v, fs);
end

figure('Name', 'Spectrograms - babble', 'Position', [50 50 1200 700]);
ttl  = {'Clean', 'Noisy (babble, 5 dB)', 'FIR band-pass', 'IIR Butterworth', 'Spectral subtraction'};
all5 = {s, x_bab, y_fir_b, y_iir_b, y_ss_b};
for i = 1:5
    subplot(2, 3, i);
    spectrogram(all5{i}, hamming(512), 384, 512, fs, 'yaxis');
    title(ttl{i}); clim([-120 -20]);
end
saveas(gcf, 'results/spectrograms_babble.png');

disp('Done. Results saved in the results/ folder.');