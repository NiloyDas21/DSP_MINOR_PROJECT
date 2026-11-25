function plot_responses(b_fir, b_iir, a_iir, fs)
% PLOT_RESPONSES  Magnitude, phase, group delay and pole-zero plots for the FIR and IIR filters.

[Hf, f]  = freqz(b_fir, 1, 4096, fs);
[Hi, ~]  = freqz(b_iir, a_iir, 4096, fs);

% magnitude
figure('Name', 'Magnitude response');
plot(f, 20*log10(abs(Hf) + eps), 'LineWidth', 1.2); hold on;
plot(f, 20*log10(abs(Hi) + eps), 'LineWidth', 1.2);
xline(300, ':'); xline(3400, ':');
ylim([-100 5]); grid on;
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
title('Magnitude response: FIR vs IIR band-pass');
legend('FIR (Hamming window)', 'IIR (Butterworth)', 'Location', 'south');

% phase
figure('Name', 'Phase response');
plot(f, unwrap(angle(Hf)), 'LineWidth', 1.2); hold on;
plot(f, unwrap(angle(Hi)), 'LineWidth', 1.2);
grid on; xlabel('Frequency (Hz)'); ylabel('Phase (rad)');
title('Phase response (FIR is linear, IIR is not)');
legend('FIR', 'IIR');

% group delay
[gf, fg] = grpdelay(b_fir, 1, 4096, fs);
[gi, ~]  = grpdelay(b_iir, a_iir, 4096, fs);
figure('Name', 'Group delay');
plot(fg, gf, 'LineWidth', 1.2); hold on;
plot(fg, gi, 'LineWidth', 1.2);
xlim([0 4000]); grid on;
xlabel('Frequency (Hz)'); ylabel('Group delay (samples)');
title('Group delay (constant for FIR, varies for IIR)');
legend('FIR', 'IIR');

% pole-zero
figure('Name', 'Pole-zero plots');
subplot(1, 2, 1); zplane(b_fir, 1);     title('FIR');
subplot(1, 2, 2); zplane(b_iir, a_iir); title('IIR (Butterworth)');
end
