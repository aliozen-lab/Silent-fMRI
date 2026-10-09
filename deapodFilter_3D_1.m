 function  c_xyz = deapodFilter_3D(kw,beta,OS,N)
%========================================================================
% function image = deapod_3D_KB(image,kbwidth,kbbeta)
%   
%   input
%
%   output
% 
%   
%   Dmitry Kurzhunov, University Medical Center Freiburg
%   21.06.2014
%========================================================================

% compute deapodization function (compare: Dissertation A. Nagel (2009) eq. 3.16)

x   = (-OS*N/2:OS*N/2-1) / N;
sqa = sqrt( (pi*kw*x).^2 - beta^2);
c_x = sin(sqa)./sqa;
% normalize by DC value
c_x = c_x / c_x(OS*N/2);

% create vectors along all 3 dimensions and create a 3D matrix
c_y         = c_x';
c_z(1,1,:)  = c_x;

c_xyz       = c_y*c_x.*c_z;

