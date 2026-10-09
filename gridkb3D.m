function [m, mGPU, p] = gridkb3D(d,kx,ky,kz,n,OS,wg)
% width of the kernel on the original grid
kw = wg/OS;

% compute kernel, assume e1 is 0.001, assuming nearest neighbor
kOS = floor(0.91/(OS*1e-3));

% half width in oversampled grid units
kWidth = OS*kw/2;

% beta from the Beatty paper
beta = pi*sqrt((kw*(OS-0.5)).^2-0.8);

% compute kernel
om = (0:kOS*kWidth)/(kOS*kWidth);
p  = besseli(0,beta*sqrt(1-om.*om));
p  = p'./p(1);
% last sample is zero so we can use min() below for samples bigger than kwidth
p(end) = 0;


% convert k-space samples to matrix indices, such that kSpace center is
% located at (oversample*n)/2+1
nx = OS * (n/2+1 + n*kx) - (OS-1);
ny = OS * (n/2+1 + n*ky) - (OS-1);
nz = OS * (n/2+1 + n*kz) - (OS-1);

m = zeros(OS*n,OS*n,OS*n);

if gpuDeviceCount
    temp = gpuDevice(1);
    %if contains(temp.Name,'RTX') &&  temp.TotalMemory/(1024^3) > 15
    if temp.TotalMemory/(1024^3) >15

        m = gpuArray(m);
        d = gpuArray(d);
        nx = gpuArray(nx);
        ny = gpuArray(ny);
        nz = gpuArray(nz);
        p = gpuArray(p);
    end
end

msg0 = fprintf('\tCalculate Spokes in kSpace...');
percent = 0;
msg = fprintf('%d%%',0);
idx = 0;

for lx = -kWidth:kWidth
    for ly = -kWidth:kWidth
        for lz = -kWidth:kWidth
            if percent ~= uint8(idx/numel(-kWidth:kWidth)^3*100)
                percent = uint8(idx/numel(-kWidth:kWidth)^3*100);
                fprintf(repmat(sprintf('\b'),1,msg));
                msg = fprintf('%d%%',percent);
            end
            idx = idx+1;
            % find nearest samples
            nxt = round(nx+lx);
            nyt = round(ny+ly);
            nzt = round(nz+lz);

            % separable kernel value
            kkx = min(round(kOS*abs(nx-nxt)+1), floor(kOS*kWidth)+1);
            kwx = p(kkx);
            kky = min(round(kOS*abs(ny-nyt)+1), floor(kOS*kWidth)+1);
            kwy = p(kky);
            kkz = min(round(kOS*abs(nz-nzt)+1), floor(kOS*kWidth)+1);
            kwz = p(kkz);

            % only consider values that are actually placed inside the
            % reconstructed kSpace matrix
            insideMatrix =  nxt >=1  &  nxt <= OS*n  &  nyt >=1  &  nyt <= OS*n  &  nzt >=1  &  nzt <= OS*n;
            subs = [nxt(insideMatrix) nyt(insideMatrix) nzt(insideMatrix)];
            values = d(insideMatrix).*kwx(insideMatrix).*kwy(insideMatrix).*kwz(insideMatrix);
            values = values(:,1);
            % accumulate gridded data
            if ~isempty(subs)
                m = m + accumarray(subs,values,[OS*n OS*n OS*n]);
            end
            if isempty(subs)
                break;
            end
        end
    end
end
fprintf(repmat(sprintf('\b'),1,msg0+msg));
mGPU = m;
m = gather(m);
end


