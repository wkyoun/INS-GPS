
function T_LIDAR= dataReadLIDARtime(fileName, timeInitRef)

load(fileName); % loads the variable "T_LIDAR"

% Add half the difference to the next scan to obtain the time at the middle
% of the scan (the one loaded directly is the time at the beginning of the
% scan)
diff_T= diff(T_LIDAR(:,2)) / 2;
diff_T= [diff_T; mean(diff_T)];

T_LIDAR(:,2)= T_LIDAR(:,2) + diff_T;

% Use the GPS first reading time as reference
T_LIDAR(:,2)= T_LIDAR(:,2) - timeInitRef;

% If some of the initial times are negative (prior to first GPS reading),
% eliminate them
T_LIDAR(T_LIDAR(:,2) < 0,:)= [];






