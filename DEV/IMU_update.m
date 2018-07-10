
function IMU_update( u, w_IE, g_N, taua, tauw, dt )

global XX

% Create variables (for clarity)
v= XX(4:6);
phi= XX(7); theta= XX(8); psi= XX(9);
b_f= XX(10:12);
b_w= XX(13:15);
f= u(1:3); 
w= u(4:6);
w_IE= [0;0;w_IE];

% Calculate parameters
R_NB= R_NB_rot(phi,theta,psi);
R_BN= R_NB';
Q_BE= Q_BE_fn(phi,theta);

r_dot= v;
v_dot= R_NB * ( f - b_f ) - 2* cross(w_IE,v) + g_N;
E_dot= Q_BE * ( w - b_w - R_BN*w_IE);
b_f_dot= -eye(3) / taua * b_f;
b_w_dot= -eye(3) / tauw * b_w;
x_dot= [r_dot; v_dot; E_dot; b_f_dot; b_w_dot];

% Return new pose
XX(1:15)= XX(1:15) + dt*x_dot;





