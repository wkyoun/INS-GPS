
clear; clc; close all;

% fileLIDAR= strcat('../DATA/DATA_COMPLETE/20180419/Smooth_turn/LIDAR/');
fileLIDAR= strcat('../DATA/DATA_COMPLETE/20180612/LIDAR/');

firstEpoch= 280;
lastEpoch= 3126;

% Initial rotation to get: x=foward & z=down
R_init= [ 0, -1;
         -1, 0];


for epoch= firstEpoch:lastEpoch
    fileName= strcat(fileLIDAR, 'textFiles/Epoch', num2str(epoch), '.txt');
    z= importdata(fileName);
    z= ( R_init * z' )';
%     save(strcat(fileLIDAR,'matFiles/Epoch',num2str(epoch),'.mat'),'z');
end

     


























