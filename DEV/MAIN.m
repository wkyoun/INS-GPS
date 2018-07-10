
clear; format short; clc; close all;

dbstop if error

configureFile;

% Initial discretization for cov. propagation
[Phi,D_bar]= linearize_discretize(u(:,1),S,taua,tauw,dT_IMU);

% ----------------------------------------------------------
% -------------------------- LOOP --------------------------
for k= 1:N_IMU-1
    disp(strcat('Epoch -> ', num2str(k)));
    
    
    % Turn off GPS updates if start moving
    if k == numEpochStatic
        SWITCH_CALIBRATION= 0; 
        PX(7,7)= sig_phi0^2;
        PX(8,8)= sig_phi0^2;
        PX(9,9)= sig_yaw0^2;
        u= u - XX(10:15);
        XX(10:15)= 0;
        taua= taua0;
        tauw= tauw0;
    end
        
    % Increase time count
    timeSim= T_IMU(k) - 1.98; %0.75
    timeSum= timeSum + dT_IMU;
    timeSumVirt_Z= timeSumVirt_Z + dT_IMU;
    timeSumVirt_Y= timeSumVirt_Y + dT_IMU;
    
    % ------------- IMU -------------
    IMU_update( u(:,k), w_IE, g_N, taua, tauw, dT_IMU );
    PX(1:15,1:15)= Phi*PX(1:15,1:15)*Phi' + D_bar; 
    % -------------------------------
    
    % Store data
    DATA.pred.XX(:,k)= XX(1:15);
    DATA.pred.time(k)= timeSim;
    
    % ------------- Calibration -------------
    if timeSum >= dT_cal && SWITCH_CALIBRATION
        
        z= [zeros(6,1); phi0; theta0; yaw0];
        calibration(z,H_cal,R_cal);
        
        [Phi,D_bar]= linearize_discretize(u(:,k),S_cal,taua,tauw,dT_IMU);
        
        % If GPS is calibrating initial biases, increse bias variance
        D_bar(10:12,10:12)= D_bar(10:12,10:12) + diag( [sig_ba,sig_ba,sig_ba] ).^2;
        D_bar(13:15,13:15)= D_bar(13:15,13:15) + diag( [sig_bw,sig_bw,sig_bw] ).^2;
        
        % Store data
        k_update= storeData(timeSim,k_update);

        % Reset counter
        timeSum= 0;
    end
    % ------------------------------------
    
    % ------------- virtual msmt update >> Z vel  -------------  
    if timeSumVirt_Z >= dT_virt_Z && SWITCH_VIRT_UPDATE_Z && ~SWITCH_CALIBRATION
        [XX,PX]= zVelocityUpdate(XX,PX,R_virt_Z);
        
        % Reset counter
        timeSumVirt_Z= 0;
    end
    % ---------------------------------------------------------
    
    % ------------- virtual msmt update >> Y vel  -------------  
    if timeSumVirt_Y >= dT_virt_Y && SWITCH_VIRT_UPDATE_Y && ~SWITCH_CALIBRATION        
         
        % Yaw update
        if SWITCH_YAW_UPDATE && norm(XX(4:6)) > minVelocityYaw
            disp('yaw udpate');
            yawUpdate(u(4:6,k), R_yaw_fn(norm(XX(4:6))),r_IMU2rearAxis);
        else
            disp('--------no yaw update------');
        end
        
        % Reset counter
        timeSumVirt_Y= 0;
    end
    % ---------------------------------------------------------
    
    % ------------------- GPS -------------------
    if (timeSim + dT_IMU) > timeGPS
        
        if ~SWITCH_CALIBRATION && SWITCH_GPS_UPDATE
            % GPS update -- only use GPS vel if it's fast
            GPS_update(z_GPS(:,k_GPS),R_GPS(:,k_GPS),minVelocityGPS,SWITCH_GPS_VEL_UPDATE);
            
            % Yaw update
            if SWITCH_YAW_UPDATE && norm(XX(4:6)) > minVelocityYaw
                disp('yaw udpate');
                yawUpdate(u(4:6,k), R_yaw_fn(norm(XX(4:6))),r_IMU2rearAxis);
            else
                disp('--------no yaw update------');
            end
            [Phi,D_bar]= linearize_discretize(u(:,k),S,taua,tauw,dT_IMU);

            % Store data
            k_update= storeData(timeSim,k_update);
        end
        
        % Time GPS counter
        k_GPS= k_GPS + 1;
        timeGPS= T_GPS(k_GPS);
    end
    % ----------------------------------------
    
    % ------------- LIDAR -------------
    if (timeSim + dT_IMU) > timeLIDAR && SWITCH_LIDAR_UPDATE
        epochLIDAR= T_LIDAR(k_LIDAR,1); % T_LIDAR contains both the epoch number and the time
        
        if k > numEpochStatic + 1500
            % Read the lidar features
            z= dataReadLIDAR(fileLIDAR, lidarRange, epochLIDAR, SWITCH_REMOVE_FAR_FEATURES);
            
            % Remove people-features
            z= removeFeatureInArea(XX(1:9), z, 0,8,0,15);
            z= removeFeatureInArea(XX(1:9), z, -28,15,-24,-18);
            z= removeFeatureInArea(XX(1:9), z, -35,-27,27,30);
            
            % NN data association
            [association,appearances]= nearestNeighbor(z(:,1:2),appearances,R_lidar,T_NN, T_newLM);
            
            % Lidar update
            lidarUpdate(z(:,1:2),association,appearances,R_lidar,SWITCH_CALIBRATION);
            
            % Increase landmark covariance to the minimum
            increaseLandmarkCov(R_minLM);
            
            % Add new landmarks
            addNewLM( z(association' == -1,:), R_lidar );
            
            % Add to landmarks
            z= body2nav(z,XX(1:9));
            LM= [LM; z];
            
            % Lineariza and discretize
            [Phi,D_bar]= linearize_discretize(u(:,k),S,taua,tauw,dT_IMU);
            
            % Store data
            k_update= storeData(timeSim,k_update);
        end
        
        % Increase counters
        k_LIDAR= k_LIDAR + 1;
        timeLIDAR= T_LIDAR(k_LIDAR,2);
    end
    % ---------------------------------
    
end

% Store data for last epoch
storeData(timeSim,k_update);
% ------------------------- END LOOP -------------------------
% ------------------------------------------------------------






% ------------- PLOTS -------------
numEpochInitPlot= numEpochStatic;
timeComplete= 0:dT_IMU:timeSim+dT_IMU/2;
timeMove= timeComplete(numEpochInitPlot:end);

% % Plot estimates
% figure; hold on;
% 
% subplot(3,3,1); hold on; grid on;
% plot(timeComplete,DATA.pred.XX(1,:));
% ylabel('x [m]');
% 
% subplot(3,3,2); hold on; grid on;
% plot(timeComplete,DATA.pred.XX(2,:));
% ylabel('y [m]');
% 
% subplot(3,3,3); hold on; grid on; 
% plot(timeComplete,DATA.pred.XX(3,:))
% ylabel('z [m]');
% 
% subplot(3,3,4); hold on; grid on;
% plot(timeComplete,DATA.pred.XX(4,:))
% ylabel('v_x [m/s]');
% 
% subplot(3,3,5); hold on; grid on;
% plot(timeComplete,DATA.pred.XX(5,:))
% ylabel('v_y [m/s]');
% 
% subplot(3,3,6); hold on; grid on;
% plot(timeComplete,DATA.pred.XX(6,:));
% ylabel('v_z [m/s]');
% 
% subplot(3,3,7); hold on; grid on;
% plot(timeComplete,rad2deg(DATA.pred.XX(7,:)))
% ylabel('\phi [deg]');
% 
% subplot(3,3,8); hold on; grid on;
% plot(timeComplete,rad2deg(DATA.pred.XX(8,:)))
% ylabel('\theta [deg]');
% 
% subplot(3,3,9); hold on; grid on;
% plot(timeComplete,rad2deg(DATA.pred.XX(9,:)))
% ylabel('\psi [deg]');

% Plot GPS+IMU estimated path
figPath= figure; hold on; grid on;
plot3(DATA.pred.XX(1,:), DATA.pred.XX(2,:), DATA.pred.XX(3,:), 'b.');
plot3(DATA.update.XX(1,1:k_update), DATA.update.XX(2,1:k_update), DATA.update.XX(3,1:k_update),...
            'b.','markersize', 7);
plot3(z_GPS(1,:),z_GPS(2,:),z_GPS(3,:),'r*');
if SWITCH_LIDAR_UPDATE % Plot landmarks
    plot3(LM(:,1),LM(:,2),zeros(size(LM,1),1),'k.'); 
    plot3(DATA.update.LM{k_update}(1:2:end) ,DATA.update.LM{k_update}(2:2:end),zeros((length(XX)-15)/2,1),...
    'g+', 'markersize',20);
end 
for i= 1:N_IMU
    if rem(i,100) == 0
        R_NB= R_NB_rot(DATA.pred.XX(7,i),DATA.pred.XX(8,i),DATA.pred.XX(9,i));
        xyz_N= R_NB*xyz_B + DATA.pred.XX(1:3,i);
        plot3(xyz_N(1,:), xyz_N(2,:), xyz_N(3,:), 'g-', 'linewidth', 2);
    end
end
xlabel('x [m]'); ylabel('y [m]'); zlabel('z [m]');
axis equal

% Plot variance estimates
SD= sqrt( DATA.update.PX(:,1:k_update) );
update_time= DATA.update.time(1:k_update);

% Plot SD -- pose
figure; hold on; title('Standard Deviations');

subplot(3,3,1); hold on; grid on;
plot(update_time, SD(1,:),'b-','linewidth',2);
xlim([0,update_time(end)]);
ylabel('x [m]');

subplot(3,3,2); hold on; grid on;
plot(update_time, SD(2,:),'r-','linewidth',2);
xlim([0,update_time(end)]);
ylabel('y [m]');

subplot(3,3,3); hold on; grid on;
plot(update_time, SD(3,:),'g-','linewidth',2);
xlim([0,update_time(end)]);
ylabel('z [m]');

subplot(3,3,4); hold on; grid on;
plot(update_time, SD(4,:),'b-','linewidth',2);
xlim([0,update_time(end)]);
ylabel('v_x [m/s]');

subplot(3,3,5); hold on; grid on;
plot(update_time, SD(5,:),'r-','linewidth',2);
xlim([0,update_time(end)]);
ylabel('v_y [m/s]');

subplot(3,3,6); hold on; grid on;
plot(update_time, SD(6,:),'g-','linewidth',2);
xlim([0,update_time(end)]);
ylabel('v_z [m/s]');

subplot(3,3,7); hold on; grid on;
plot(update_time, rad2deg(SD(7,:)),'b-','linewidth',2);
xlim([0,update_time(end)]);
ylabel('\phi [deg]'); xlabel('Time [s]');

subplot(3,3,8); hold on; grid on;
plot(update_time, rad2deg(SD(8,:)),'r-','linewidth',2);
xlim([0,update_time(end)]);
ylabel('\theta [deg]'); xlabel('Time [s]');

subplot(3,3,9); hold on; grid on;
plot(update_time, rad2deg(SD(9,:)),'g-','linewidth',2);
xlim([0,update_time(end)]);
ylabel('\psi [deg]'); xlabel('Time [s]');

% % Plot SD -- Biases
% figure; hold on;
% 
% subplot(2,3,1); hold on; grid on;
% plot(update_time, SD(10,:),'b-','linewidth',2);
% xlim([0,update_time(end)]);
% ylabel('a_x');
% 
% subplot(2,3,2); hold on; grid on;
% plot(update_time, SD(11,:),'r-','linewidth',2);
% xlim([0,update_time(end)]);
% ylabel('a_y');
% 
% subplot(2,3,3); hold on; grid on;
% plot(update_time, SD(12,:),'g-','linewidth',2);
% xlim([0,update_time(end)]);
% ylabel('a_z');
% 
% subplot(2,3,4); hold on; grid on;
% plot(update_time, SD(13,:),'b--','linewidth',2);
% xlim([0,update_time(end)]);
% ylabel('w_x'); xlabel('Time [s]')
% 
% subplot(2,3,5); hold on; grid on;
% plot(update_time, SD(14,:),'r--','linewidth',2);
% xlim([0,update_time(end)]);
% ylabel('w_y'); xlabel('Time [s]')
% 
% subplot(2,3,6); hold on; grid on;
% plot(update_time, SD(15,:),'g--','linewidth',2);
% xlim([0,update_time(end)]);
% ylabel('w_z'); xlabel('Time [s]')


% % Plot biases
% figure; hold on; grid on; title('biases in accelerometers');
% plot(timeComplete, DATA.pred.XX(10,:), 'linewidth',2)
% plot(timeComplete, DATA.pred.XX(11,:), 'linewidth',2)
% plot(timeComplete, DATA.pred.XX(12,:), 'linewidth',2)
% ylabel('m/s^2')
% legend('x','y','z')
% 
% figure; hold on; grid on; title('biases in gyros');
% plot(timeComplete, rad2deg(DATA.pred.XX(13,:)), 'linewidth',2)
% plot(timeComplete, rad2deg(DATA.pred.XX(14,:)), 'linewidth',2)
% plot(timeComplete, rad2deg(DATA.pred.XX(15,:)), 'linewidth',2)
% ylabel('deg');
% legend('w_x','w_y','w_z')


% % Plot GPS positions
% figure; hold on; grid on; title('GPS positions');
% plot(1:N_GPS, z_GPS(1,:), 'linewidth',2)
% plot(1:N_GPS, z_GPS(2,:), 'linewidth',2)
% plot(1:N_GPS, z_GPS(3,:), 'linewidth',2)
% ylabel('m')
% legend('r_x','r_y','r_z')

% % Plot GPS velocities
% figure; hold on; grid on; title('GPS velocities');
% plot(1:N_GPS, z_GPS(4,:), 'linewidth',2)
% plot(1:N_GPS, z_GPS(5,:), 'linewidth',2)
% plot(1:N_GPS, z_GPS(6,:), 'linewidth',2)
% ylabel('m/s')
% legend('v_x','v_y','v_z')


% % Plot measurements
% figure; hold on; grid on;
% u_ax_filter= filter(ones(1,500)/500,1,u(1,:));
% u_ay_filter= filter(ones(1,500)/500,1,u(2,:));
% plot(timeComplete, u_ax_filter(:));
% plot(timeComplete, u_ay_filter(:));
% legend('accX','accY')









