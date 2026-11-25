function [b_fir, b_iir, a_iir] = design_filters(fs, fir_order, iir_order)
f1 = 300;
f2 = 3400;
Wn = [f1 f2] / (fs / 2);

% FIR: windowed-sinc design with a Hamming window (linear phase)
b_fir = fir1(fir_order, Wn, 'bandpass', hamming(fir_order + 1));

% IIR: Butterworth band-pass (maximally flat passband)
[b_iir, a_iir] = butter(iir_order, Wn, 'bandpass');
end
