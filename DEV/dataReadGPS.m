

function [T,z,R,R_NE]= dataReadGPS(string, timeStatic, timeInitRef)

load(string);


T= data(:,4);
posX= data(:,5);
posY= data(:,6);
posZ= data(:,7);
velX= data(:,8);
velY= data(:,9);
velZ= data(:,10);
sigPosX= data(:,11);
sigPosY= data(:,12);
sigPosZ= data(:,13);
sigVelX= data(:,14);
sigVelY= data(:,15);
sigVelZ= data(:,16);


% Make time start at zero
T= T - timeInitRef;

% create variables
z= [posX, posY, posZ, velX, velY, velZ]';
R= ([sigPosX, sigPosY, sigPosZ, sigVelX, sigVelY, sigVelZ].^2)';


% Number of GPS epochs while the cart is static since we start logging GPS
numEpochStaticGPS= ceil(timeStatic - T(1));

% Use initial position as reference
muX= mean(posX(1:numEpochStaticGPS));
muY= mean(posY(1:numEpochStaticGPS));
muZ= mean(posZ(1:numEpochStaticGPS));
z(1:3,:) = z(1:3,:) - [muX;muY;muZ];

% Convert from ECEF to Navigation-frame
[phi, lambda, ~]=  ecef2lla(muX,muY,muZ) ;

R_NE= [-sin(phi)*cos(lambda), -sin(phi)*sin(lambda),  cos(phi);
       -sin(lambda),           cos(lambda),           0;
       -cos(phi)*cos(lambda), -cos(phi)*sin(lambda), -sin(phi)];

R_NE_block= blkdiag(R_NE,R_NE);
z= R_NE_block* z;

for i= 1:length(T)
    R(:,i)= diag( R_NE_block * diag( R(:,i) ) * R_NE_block' );
end


