function [ T, u, iu , timeInitialRef] = DataReadIMUMatFile( fileName )

load(fileName); % Load variable data

g0= 9.80665; % m/s^2 -- by manufacturerw

% Read sensor data
gyroX= deg2rad(data(:,5));
gyroY= deg2rad(data(:,6));
gyroZ= deg2rad(data(:,7));
accX= data(:,9) *g0;
accY= data(:,10) *g0;
accZ= data(:,11) *g0;
incX= data(:,13) *g0;
incY= data(:,14) *g0;
incZ= data(:,15) *g0;

% Read times 
timeInitialRef= data(1,4);
counterIMU= data(:,18);
T= cumsum( counterIMU*16 / 1e6 );
T= [0; T(1:end-1)];

% Set paramters
iu= [incX, incY, incZ]';
u= [accX, accY, accZ, gyroX, gyroY, gyroZ]';


end

