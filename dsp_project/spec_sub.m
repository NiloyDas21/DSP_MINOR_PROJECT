function y = spec_sub(x, fs, alpha, beta)
if nargin < 3, alpha = 2;    end
if nargin < 4, beta  = 0.02; end

x = x(:);
N   = round(0.032 * fs);          % 32 ms frame
if mod(N, 2), N = N + 1; end
hop = N / 2;                      % 50% overlap
w   = sqrt(hann(N, 'periodic'));  % sqrt-Hann analysis + synthesis => perfect reconstruction

nfr = ceil((length(x) - N) / hop) + 1;
xp  = [x; zeros((nfr - 1) * hop + N - length(x), 1)];

% analysis
X = zeros(N, nfr);
for i = 1:nfr
    seg = xp((i - 1) * hop + (1:N)) .* w;
    X(:, i) = fft(seg);
end
P  = abs(X).^2;
ph = angle(X);

% noise power estimate from quietest frames
e = sum(P, 1);
[~, idx] = sort(e, 'ascend');
k  = max(3, round(0.15 * nfr));
Pn = mean(P(:, idx(1:k)), 2);

% subtraction with floor
Pc = P - alpha * Pn;
Pc = max(Pc, beta * P);
Y  = sqrt(Pc) .* exp(1j * ph);

% synthesis (overlap-add)
yp = zeros(size(xp));
for i = 1:nfr
    rng_i = (i - 1) * hop + (1:N);
    seg = real(ifft(Y(:, i))) .* w;
    yp(rng_i) = yp(rng_i) + seg;
end
y = yp(1:length(x));
end
