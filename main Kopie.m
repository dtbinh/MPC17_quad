
clear all
close all
clc

% adding the subfolders to the path
addpath(genpath('functions'))
addpath(genpath('data'))

% loads:
%    hovering equilibrium (xs,us)
%    continuous time matrices Ac,Bc of the linearization
%    matrices sys.A, sys.B of the inner-loop discretized with sampling period sys.Ts
%    outerController optimizer instance for the outer controller
load('quadData.mat')
outerController = getOuterController(Ac);
disp('Data successfully loaded')

%%%%%%%%%%%%%%%% ADD YOUR CODE BELOW THIS LINE %%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Part 1
%%%%%%%%%%%%%%%%%%%%%    First MPC controller %%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('PART I - First MPC controller...\n')
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Setup
n_states = 7;
n_inputs = 4;
N = 5; % TODO: Horizon length does not affect system output. Is this correct??
N = N+1; % account for the fact that mpc is defined for x0-xN, but matlab array indexing starts at 1.

% cost matrices
Q = diag([0.5,10,10,0.5,0.5,0.5,0.5])
R = 0.1*eye(n_inputs)


% yalmip variables
x = sdpvar(n_states, N);
u = sdpvar(n_inputs, N);

% state constraints
z_dot_max = 1;
alpha_beta_max = 10/360 * 2 * pi;
alpha_beta_dot_max = 15 / 360 * 2 * pi;
gamma_dot_max = 60 / 360 * 2 * pi;
u_min = 0-us;
u_max = 1-us;

x0 =  [-1 0.1745 -0.1745 0.8727 0 0 0]';



% Constraints
fprintf('setting constraints \n')
constraints_mpc = [];
for i = 2:N
    % set system constraints
    constraints_mpc = constraints_mpc + [x(:,i) == sys.A* x(:,i-1) + sys.B * u(:,i-1)];
    
    % set state constraints
    constraints_mpc =  constraints_mpc +  [-z_dot_max <= x(1,i) <= z_dot_max];
    constraints_mpc =  constraints_mpc + [-alpha_beta_max <= x(2:3,i) <= alpha_beta_max];
    constraints_mpc = constraints_mpc + [-alpha_beta_dot_max <= x(5:6,i) <= alpha_beta_dot_max];
    constraints_mpc = constraints_mpc + [-gamma_dot_max <= x(7,i) <= gamma_dot_max];

    % set input constraints
    constraints_mpc = constraints_mpc + [u_min <= u(1:4,i) <= u_max];
end
constraints_mpc = constraints_mpc + [u_min <= u(1:4,1) <= u_max]; % constrain u(1) alias u0 as well.


% Terminal Set

% Terminal set it positive invariant set for the system x(k+1) = (A +
% BF)x(k), where F is constructed as the infinite horizon control input and
% Pinf is the terminal constraint.

[Pinf,L,Finf] = dare(sys.A,sys.B,Q,R);

terminal_model = LTISystem('A',sys.A - sys.B * Finf);

mpt_mpc = MPCController(terminal_model,N-1);

mpt_yal = mpt_mpc.toYALMIP();

for i = 2:N
    % set state constraints
    mpt_yal.constraints =  mpt_yal.constraints +  [-z_dot_max <= mpt_yal.variables.x(1,i) <= z_dot_max];
    mpt_yal.constraints =  mpt_yal.constraints + [-alpha_beta_max <= mpt_yal.variables.x(2:3,i) <= alpha_beta_max];
    mpt_yal.constraints = mpt_yal.constraints + [-alpha_beta_dot_max <= mpt_yal.variables.x(5:6,i) <= alpha_beta_dot_max];
    mpt_yal.constraints = mpt_yal.constraints + [-gamma_dot_max <= mpt_yal.variables.x(7,i) <= gamma_dot_max];
end

mpt_mpc.fromYALMIP(mpt_yal)

fprintf('calculate invariant set\n')
terminal_set = mpt_mpc.model.invariantSet();

% deliverables Ax and bx
terminal_set.A
terminal_set.b

terminal_constraint = ismember(x(:,N),terminal_set);

% set terminal constraint
constraints_mpc = constraints_mpc + [terminal_constraint]

% Objective / Cost Function
fprintf('setting objective function\n')
objective_mpc = 0;
for i = 1:N-1
    objective_mpc = objective_mpc + x(:,i)' * Q * x(:,i) + u(:,i)' * R * u(:,i);
end

terminal_cost = x(:,N)' * Pinf * x(:,N);
objective_mpc = objective_mpc + terminal_cost;

% set first column to x0
parameters = x(:,1);
wanted = u(:,1);

% Setup MPC
fprintf('set up mpc problem\n')
mpc_simple = optimizer(constraints_mpc, objective_mpc, [], parameters, wanted);

% Simulation
fprintf('simulate system\n')
simQuad( sys, mpc_simple, 0, x0, 10);

%% Part 2
%%%%%%%%%%%%%%%%%%%%%  Reference Tracking %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('PART II - Reference tracking...\n')
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Setup
n_states = 7;
n_inputs = 4;
N =5; 
N = N+1; % account for the fact that mpc is defined for x0-xN, but matlab array indexing starts at 1.

% cost matrices
Q = diag([1,70,70,1,0.1,0.1,0.1])
R = 0.1*eye(n_inputs)
P = eye(n_states)


% yalmip variables
delta_x = sdpvar(n_states, N,'full');
delta_u = sdpvar(n_inputs, N,'full');

r = sdpvar(4,1,'full');
xr = sdpvar(n_states,1,'full')
ur = sdpvar(n_inputs,1,'full')

xk = sdpvar(n_states,1,'full')
uk = sdpvar(n_inputs,1,'full')

C = [eye(4) zeros(4,3)];

% state constraints
z_dot_max = 1;
alpha_beta_max = degtorad(10);
alpha_beta_dot_max = degtorad(15) ;
gamma_dot_max = degtorad(60);
u_min = 0-us
u_max = 1-us

x0 =  [-1 0.1745 -0.1745 0.8727 0 0 0]';
r1 = [1 0.1745 -0.1745 1.7453]'; 

% compute target state ts: (xr, ur)
xrur = inv([eye(n_states)-sys.A -sys.B; C zeros(4,n_inputs)])*[zeros(n_states,1); r1]
%xr = [r1; 0; 0; 0];
%ur = xrur(n_states + 1 : end);

% Constraints
fprintf('setting constraints \n')

constraints_mpc = [];

%target constraints
constraints_mpc = constraints_mpc + [C*xr == r];
constraints_mpc = constraints_mpc + [sys.A*xr+sys.B*ur == xr];

%delta shifting
constraints_mpc = constraints_mpc + [delta_x(:,1) == xk-xr];
constraints_mpc = constraints_mpc + [delta_u(:,1) == uk-ur];
 
for i = 2:N
    %system constraints
    constraints_mpc = constraints_mpc + [delta_x(:,i) == sys.A*delta_x(:,i-1)+sys.B*delta_u(:,i-1)];
    
    %state constraints
    constraints_mpc =  constraints_mpc +  [-z_dot_max-xr(1) <= delta_x(1,i) <= z_dot_max-xr(1)];
    constraints_mpc =  constraints_mpc + [-alpha_beta_max-xr(2:3)  <= delta_x(2:3,i) <= alpha_beta_max-xr(2:3)];
    constraints_mpc = constraints_mpc + [-alpha_beta_dot_max-xr(5:6)  <= delta_x(5:6,i) <= alpha_beta_dot_max-xr(5:6)];
    constraints_mpc = constraints_mpc + [-gamma_dot_max-xr(7)  <= delta_x(7,i) <= gamma_dot_max-xr(7)];

    %input constraints
    
    constraints_mpc = constraints_mpc + [u_min-ur <= delta_u(1:4,i) <= u_max-ur ];
end
constraints_mpc = constraints_mpc + [u_min-ur <= delta_u(1:4,1) <= u_max-ur ];

%Objective / Cost Function
fprintf('setting objective function\n')
objective_mpc = 0;
for i = 1:N
    objective_mpc = objective_mpc + delta_x(:,i)' * Q * delta_x(:,i) + delta_u(:,i)' * R * delta_u(:,i);
end

[Pinf,L,Finf] = dare(sys.A,sys.B,Q,R);

terminal_cost = delta_x(:,N)' * Pinf * delta_x(:,N);
objective_mpc = objective_mpc + terminal_cost;

% Setup MPC
fprintf('set up mpc problem\n')

innerController = optimizer(constraints_mpc, objective_mpc, [], [xk; r], uk);


% Simulation constant r
fprintf('simulate system with constant r\n')
simQuad( sys, innerController, 0, zeros(7,1), 10, r1);

fprintf('simulate system with varying r r\n')
n_k = 150
k = 1:n_k;
rt = [repmat(1,1,n_k); 0.1745*sin(sys.Ts*k); -0.1745*sin(sys.Ts*k); repmat(pi/2,1,n_k) ];
%simQuad( sys, innerController, 0, zeros(7,1), 20, rt);


%%%%%%%%%%%%%%%  First simulation of the nonlinear model %%%%%%%%%%%%%%%%%
fprintf('PART III - First simulation of the nonlinear model...\n')
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Part 3
% Atention: Part 2 needs to be run before running this part.
close all
sim('simulation1.mdl')

%%%%%%%%%%%%%%%%%%%%%%%  Offset free MPC  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('PART IV - Offset free MPC...\n')
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Part 4
close all

% Setup
n_states = 7;
n_inputs = 4;
N =5; 
N = N+1; % account for the fact that mpc is defined for x0-xN, but matlab array indexing starts at 1.

% cost matrices
Q = diag([10,50,50,1,0.1,0.1,0.1])
R = 0.1*eye(n_inputs)
P = eye(n_states)

% yalmip variables
delta_x = sdpvar(n_states, N,'full');
delta_u = sdpvar(n_inputs, N,'full');

r = sdpvar(4,1,'full');
xr = sdpvar(n_states,1,'full')
ur = sdpvar(n_inputs,1,'full')

xk = sdpvar(n_states,1,'full')
uk = sdpvar(n_inputs,1,'full')

d = sdpvar(n_states, 1, 'full')

C = [eye(4) zeros(4,3)];

% state constraints
z_dot_max = 1;
alpha_beta_max = degtorad(10);
alpha_beta_dot_max = degtorad(15) ;
gamma_dot_max = degtorad(60);
u_min = 0-us
u_max = 1-us

x0 =  [-1 0.1745 -0.1745 0.8727 0 0 0]';
r1 = [0.8 0.12 -0.12 pi/2]'; 

% Constraints
fprintf('setting constraints \n')

constraints_mpc = [];

%target constraints
constraints_mpc = constraints_mpc + [C*xr == r];
constraints_mpc = constraints_mpc + [sys.A*xr+sys.B*ur+d == xr];

%delta shifting
constraints_mpc = constraints_mpc + [delta_x(:,1) == xk-xr];
constraints_mpc = constraints_mpc + [delta_u(:,1) == uk-ur];
 
for i = 2:N
    %system constraints
    constraints_mpc = constraints_mpc + [delta_x(:,i) == sys.A*delta_x(:,i-1)+sys.B*delta_u(:,i-1)];  % add a disturbance d here? subtract d?
%     %state constraints
    constraints_mpc =  constraints_mpc +  [-z_dot_max-xr(1) <= delta_x(1,i) <= z_dot_max-xr(1)];
    constraints_mpc =  constraints_mpc + [-alpha_beta_max-xr(2:3)  <= delta_x(2:3,i) <= alpha_beta_max-xr(2:3)];
    constraints_mpc = constraints_mpc + [-alpha_beta_dot_max-xr(5:6)  <= delta_x(5:6,i) <= alpha_beta_dot_max-xr(5:6)];
    constraints_mpc = constraints_mpc + [-gamma_dot_max-xr(7)  <= delta_x(7,i) <= gamma_dot_max-xr(7)];
% 
%     %input constraints
    constraints_mpc = constraints_mpc + [u_min-ur <= delta_u(1:4,i) <= u_max-ur ];
end
constraints_mpc = constraints_mpc + [u_min-ur <= delta_u(1:4,1) <= u_max-ur ];

%Objective / Cost Function
fprintf('setting objective function\n')
objective_mpc = 0;
for i = 1:N
    objective_mpc = objective_mpc + delta_x(:,i)' * Q * delta_x(:,i) + delta_u(:,i)' * R * delta_u(:,i);
end

[Pinf,L,Finf] = dare(sys.A,sys.B,Q,R);

terminal_cost = delta_x(:,N)' * Pinf * delta_x(:,N);
objective_mpc = objective_mpc + terminal_cost;


% Disturbance estimation:
Aug = [sys.A eye(n_states); zeros(n_states) eye(n_states)];
Baug = [sys.B; zeros(n_states,n_inputs)];
Caug = [eye(n_states) eye(n_states)];

Lx = eye(n_states);
Ld = eye(n_states);
L = [Lx; Ld];

filter = struct('Af', Aug - L*Caug, 'Bf', [Baug L]);


% Setup MPC
fprintf('set up mpc problem\n')

innerController = optimizer(constraints_mpc, objective_mpc, [], [xk; r; d], uk);


% Simulation constant r
fprintf('simulate system with constant r and disturbance filter\n')
simQuad( sys, innerController, 0, zeros(7,1), 10, r1,filter);

fprintf('simulate system with varying r r\n')
n_k = 150
k = 1:n_k;
rt = [repmat(1,1,n_k); 0.1745*sin(sys.Ts*k); -0.1745*sin(sys.Ts*k); repmat(pi/2,1,n_k) ];
%simQuad( sys, innerController, 0, zeros(7,1), 10, rt,filter);


%%%%%%%%%%%%%%%%%%  Simulation of the nonlinear model %%%%%%%%%%%%%%%%%%%%
fprintf('PART V - simulation of the nonlinear model...\n')
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Part 5
% run part 4 first
close all
sim('simulation2.mdl')


%%%%%%%%%%%%%%%%%%%%%%%  Slew Rate Constraints %%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('PART VI - Slew Rate Constraints...\n')
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Part 6
close all

% Setup
n_states = 7;
n_inputs = 4;
N =5; 
N = N+1; % account for the fact that mpc is defined for x0-xN, but matlab array indexing starts at 1.

% cost matrices
Q = diag([10,50,50,1,0.1,0.1,0.1])
R = 0.1*eye(n_inputs)
P = eye(n_states)

% yalmip variables
delta_x = sdpvar(n_states, N,'full');
delta_u = sdpvar(n_inputs, N,'full');

r = sdpvar(4,1,'full');
xr = sdpvar(n_states,1,'full')
ur = sdpvar(n_inputs,1,'full')

xk = sdpvar(n_states,1,'full')
uk = sdpvar(n_inputs,1,'full')

d = sdpvar(n_states, 1, 'full')
u0 = sdpvar(n_inputs, 1 ,'full')

C = [eye(4) zeros(4,3)];

% state constraints
z_dot_max = 1;
alpha_beta_max = degtorad(10);
alpha_beta_dot_max = degtorad(15) ;
gamma_dot_max = degtorad(60);
u_min = 0-us
u_max = 1-us

x0 =  0;
r1 = [0.8 0.12 -0.12 pi/2]'; 
delta = 0.2;

% Constraints
fprintf('setting constraints \n')

constraints_mpc = [];

%target constraints
constraints_mpc = constraints_mpc + [C*xr == r];
constraints_mpc = constraints_mpc + [sys.A*xr+sys.B*ur+d == xr];

%delta shifting
constraints_mpc = constraints_mpc + [delta_x(:,1) == xk-xr];
constraints_mpc = constraints_mpc + [delta_u(:,1) == uk-ur];
 
for i = 2:N
    %system constraints
    constraints_mpc = constraints_mpc + [delta_x(:,i) == sys.A*delta_x(:,i-1)+sys.B*delta_u(:,i-1)];  % add a disturbance d here? subtract d?
%     %state constraints
    constraints_mpc =  constraints_mpc +  [-z_dot_max-xr(1) <= delta_x(1,i) <= z_dot_max-xr(1)];
    constraints_mpc =  constraints_mpc + [-alpha_beta_max-xr(2:3)  <= delta_x(2:3,i) <= alpha_beta_max-xr(2:3)];
    constraints_mpc = constraints_mpc + [-alpha_beta_dot_max-xr(5:6)  <= delta_x(5:6,i) <= alpha_beta_dot_max-xr(5:6)];
    constraints_mpc = constraints_mpc + [-gamma_dot_max-xr(7)  <= delta_x(7,i) <= gamma_dot_max-xr(7)];
% 
%     %input constraints
    constraints_mpc = constraints_mpc + [u_min-ur <= delta_u(1:4,i) <= u_max-ur ];
    
    % slew rate constraints
    constraints_mpc = constraints_mpc + [abs(delta_u(:,i)-delta_u(:,i-1)) <= delta] 
    
end
constraints_mpc = constraints_mpc + [u_min-ur <= delta_u(1:4,1) <= u_max-ur ];

constraints_mpc = constraints_mpc + [abs(delta_u(:,1)-(u0-ur)) <= delta];


%Objective / Cost Function
fprintf('setting objective function\n')
objective_mpc = 0;
for i = 1:N
    objective_mpc = objective_mpc + delta_x(:,i)' * Q * delta_x(:,i) + delta_u(:,i)' * R * delta_u(:,i);
end


[Pinf,L,Finf] = dare(sys.A,sys.B,Q,R);

terminal_cost = delta_x(:,N)' * Pinf * delta_x(:,N);
objective_mpc = objective_mpc + terminal_cost;


% Disturbance estimation:
Aug = [sys.A eye(n_states); zeros(n_states) eye(n_states)];
Baug = [sys.B; zeros(n_states,n_inputs)];
Caug = [eye(n_states) eye(n_states)];

Lx = eye(n_states);
Ld = eye(n_states);
L = [Lx; Ld];

filter = struct('Af', Aug - L*Caug, 'Bf', [Baug L]);


% Setup MPC
fprintf('set up mpc problem\n')

innerController = optimizer(constraints_mpc, objective_mpc, [], [xk; r; u0 ;d], uk);


% Simulation constant r
fprintf('simulate system with constant r and disturbance filter and slew constraints\n')
simQuad( sys, innerController, 0, zeros(7,1), 10, r1,filter,[],1);


%%%%%%%%%%%%%%%%%%%%%%%%%%%  Soft Constraints %%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('PART VII - Soft Constraints...\n')
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Part 7
close all

% Setup
n_states = 7;
n_inputs = 4;
N =5; 
N = N+1; % account for the fact that mpc is defined for x0-xN, but matlab array indexing starts at 1.

% cost matrices
Q = diag([10,50,50,1,0.1,0.1,0.1])
R = 0.1*eye(n_inputs)
P = eye(n_states)

% yalmip variables
delta_x = sdpvar(n_states, N,'full');
delta_u = sdpvar(n_inputs, N,'full');

r = sdpvar(4,1,'full');
xr = sdpvar(n_states,1,'full')
ur = sdpvar(n_inputs,1,'full')

xk = sdpvar(n_states,1,'full')
uk = sdpvar(n_inputs,1,'full')

d = sdpvar(n_states, 1, 'full' )
u0 = sdpvar(n_inputs, 1 ,'full')

epsilon = sdpvar(n_inputs,N,'full')

C = [eye(4) zeros(4,3)];

% state constraints
z_dot_max = 1;
alpha_beta_max = degtorad(10);
alpha_beta_dot_max = degtorad(15) ;
gamma_dot_max = degtorad(60);
u_min = 0-us
u_max = 1-us

x0 =  0;
r1 = [0.8 0.12 -0.12 pi/2]'; 
delta = 0.1;

% variables for soft constraints % TODO: How to tune them???
v = 1*[1;1;1;1]'; % v > lambda*
s = 0.1*[1;1;1;1]'; % s > 0

% Constraints
fprintf('setting constraints \n')

constraints_mpc = [];

%target constraints
constraints_mpc = constraints_mpc + [C*xr == r];
constraints_mpc = constraints_mpc + [sys.A*xr+sys.B*ur+d == xr];

%delta shifting
constraints_mpc = constraints_mpc + [delta_x(:,1) == xk-xr];
constraints_mpc = constraints_mpc + [delta_u(:,1) == uk-ur];
 
for i = 2:N
    %system constraints
    constraints_mpc = constraints_mpc + [delta_x(:,i) == sys.A*delta_x(:,i-1)+sys.B*delta_u(:,i-1)];  % add a disturbance d here? subtract d?
%     %state constraints
    constraints_mpc =  constraints_mpc +  [-z_dot_max-xr(1) <= delta_x(1,i) <= z_dot_max-xr(1)];
    constraints_mpc =  constraints_mpc + [-alpha_beta_max-xr(2:3)  <= delta_x(2:3,i) <= alpha_beta_max-xr(2:3)];
    constraints_mpc = constraints_mpc + [-alpha_beta_dot_max-xr(5:6)  <= delta_x(5:6,i) <= alpha_beta_dot_max-xr(5:6)];
    constraints_mpc = constraints_mpc + [-gamma_dot_max-xr(7)  <= delta_x(7,i) <= gamma_dot_max-xr(7)];
% 
%     %input constraints
    constraints_mpc = constraints_mpc + [u_min-ur <= delta_u(1:4,i) <= u_max-ur ];
    
    % slew rate constraints
    constraints_mpc = constraints_mpc + [abs(delta_u(:,i)-delta_u(:,i-1)) <= delta + epsilon(:,i)] 
    
end
constraints_mpc = constraints_mpc + [u_min-ur <= delta_u(1:4,1) <= u_max-ur ];

constraints_mpc = constraints_mpc + [abs(delta_u(:,1)-(u0-ur)) <= delta + epsilon(:,1)];
constraints_mpc = constraints_mpc + [epsilon >= 0]

%Objective / Cost Function
fprintf('setting objective function\n')
objective_mpc = 0;
for i = 1:N
    objective_mpc = objective_mpc + delta_x(:,i)' * Q * delta_x(:,i) + delta_u(:,i)' * R * delta_u(:,i);
    objective_mpc = objective_mpc + v*epsilon(:,i) + s*epsilon(:,i).^2;
end




[Pinf,~,Finf] = dare(sys.A,sys.B,Q,R);

terminal_cost = delta_x(:,N)' * Pinf * delta_x(:,N);
objective_mpc = objective_mpc + terminal_cost;


% Disturbance estimation:
Aug = [sys.A eye(n_states); zeros(n_states) eye(n_states)];
Baug = [sys.B; zeros(n_states,n_inputs)];
Caug = [eye(n_states) eye(n_states)];

Lx = eye(n_states);
Ld = eye(n_states);
L = [Lx; Ld];

filter = struct('Af', Aug - L*Caug, 'Bf', [Baug L]);


% Setup MPC
fprintf('set up mpc problem\n')

innerController = optimizer(constraints_mpc, objective_mpc, [], [xk; r; u0 ;d], [uk,epsilon(:,1)]);


% Simulation constant r
fprintf('simulate system with constant r and disturbance filter and slew constraints\n')
[xt ut t rt epsilon] = simQuad( sys, innerController, 0, zeros(7,1), 10, r1,filter,[],2);
epsilon

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  FORCES Pro %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('PART VIII - FORCES Pro...\n')
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Part 8.1. Comparison of task 5

% Setup
n_states = 7;
n_inputs = 4;
N =5; 
N = N+1; % account for the fact that mpc is defined for x0-xN, but matlab array indexing starts at 1.

% cost matrices
Q = diag([1,70,70,1,0.1,0.1,0.1])
R = 0.1*eye(n_inputs)
P = eye(n_states)


% yalmip variables
delta_x = sdpvar(n_states, N,'full');
delta_u = sdpvar(n_inputs, N,'full');

r = sdpvar(4,1,'full');
xr = sdpvar(n_states,1,'full')
ur = sdpvar(n_inputs,1,'full')

xk = sdpvar(n_states,1,'full')
uk = sdpvar(n_inputs,1,'full')

C = [eye(4) zeros(4,3)];

% state constraints
z_dot_max = 1;
alpha_beta_max = degtorad(10);
alpha_beta_dot_max = degtorad(15) ;
gamma_dot_max = degtorad(60);
u_min = 0-us
u_max = 1-us

x0 =  [-1 0.1745 -0.1745 0.8727 0 0 0]';
r1 = [1 0.1745 -0.1745 1.7453]'; 

% compute target state ts: (xr, ur)
xrur = inv([eye(n_states)-sys.A -sys.B; C zeros(4,n_inputs)])*[zeros(n_states,1); r1]
%xr = [r1; 0; 0; 0];
%ur = xrur(n_states + 1 : end);

% Constraints
fprintf('setting constraints \n')

constraints_mpc = [];

%target constraints
constraints_mpc = constraints_mpc + [C*xr == r];
constraints_mpc = constraints_mpc + [sys.A*xr+sys.B*ur == xr];

%delta shifting
constraints_mpc = constraints_mpc + [delta_x(:,1) == xk-xr];
constraints_mpc = constraints_mpc + [delta_u(:,1) == uk-ur];
 
for i = 2:N
    %system constraints
    constraints_mpc = constraints_mpc + [delta_x(:,i) == sys.A*delta_x(:,i-1)+sys.B*delta_u(:,i-1)];
    
    %state constraints
    constraints_mpc =  constraints_mpc +  [-z_dot_max-xr(1) <= delta_x(1,i) <= z_dot_max-xr(1)];
    constraints_mpc =  constraints_mpc + [-alpha_beta_max-xr(2:3)  <= delta_x(2:3,i) <= alpha_beta_max-xr(2:3)];
    constraints_mpc = constraints_mpc + [-alpha_beta_dot_max-xr(5:6)  <= delta_x(5:6,i) <= alpha_beta_dot_max-xr(5:6)];
    constraints_mpc = constraints_mpc + [-gamma_dot_max-xr(7)  <= delta_x(7,i) <= gamma_dot_max-xr(7)];

    %input constraints
    
    constraints_mpc = constraints_mpc + [u_min-ur <= delta_u(1:4,i) <= u_max-ur ];
end
constraints_mpc = constraints_mpc + [u_min-ur <= delta_u(1:4,1) <= u_max-ur ];

%Objective / Cost Function
fprintf('setting objective function\n')
objective_mpc = 0;
for i = 1:N
    objective_mpc = objective_mpc + delta_x(:,i)' * Q * delta_x(:,i) + delta_u(:,i)' * R * delta_u(:,i);
end

[Pinf,L,Finf] = dare(sys.A,sys.B,Q,R);

terminal_cost = delta_x(:,N)' * Pinf * delta_x(:,N);
objective_mpc = objective_mpc + terminal_cost;


% Setup MPC
fprintf('set up mpc problem\n')

% without disturbances
codeoptions = getOptions('simpleMPC_solver');
innerControllerForces = optimizerFORCES(constraints_mpc, objective_mpc, codeoptions, [xk; r], uk,{'inputvariables'},{'u0_variable'});
innerController = optimizer(constraints_mpc, objective_mpc, [], [xk; r], uk);

fprintf('simulate system with constant r and disturbance filter\n')

[xt ut t rt_free deltat] = simQuad( sys, innerController, 0, zeros(7,1), 10, r1);
[xt ut t rt_forces_free deltat] = simQuad( sys, innerControllerForces, 1, zeros(7,1), 10, r1);

%% Part 8.2: comparison of task 9
close all

% Setup
n_states = 7;
n_inputs = 4;
N =5; 
N = N+1; % account for the fact that mpc is defined for x0-xN, but matlab array indexing starts at 1.

% cost matrices
Q = diag([10,70,70,1,0.1,0.1,0.1])
R = 0.1*eye(n_inputs)
P = eye(n_states)

% yalmip variables
delta_x = sdpvar(n_states, N,'full');
delta_u = sdpvar(n_inputs, N,'full');

r = sdpvar(4,1,'full');
xr = sdpvar(n_states,1,'full')
ur = sdpvar(n_inputs,1,'full')

xk = sdpvar(n_states,1,'full')
uk = sdpvar(n_inputs,1,'full')

d = sdpvar(n_states, 1, 'full')

C = [eye(4) zeros(4,3)];

% state constraints
z_dot_max = 1;
alpha_beta_max = degtorad(10);
alpha_beta_dot_max = degtorad(15) ;
gamma_dot_max = degtorad(60);
u_min = 0-us
u_max = 1-us

x0 =  [-1 0.1745 -0.1745 0.8727 0 0 0]';
r1 = [0.8 0.12 -0.12 pi/2]'; 

% Constraints
fprintf('setting constraints \n')

constraints_mpc = [];

%target constraints
constraints_mpc = constraints_mpc + [C*xr == r];
constraints_mpc = constraints_mpc + [sys.A*xr+sys.B*ur+d == xr];

%delta shifting
constraints_mpc = constraints_mpc + [delta_x(:,1) == xk-xr];
constraints_mpc = constraints_mpc + [delta_u(:,1) == uk-ur];
 
for i = 2:N
    %system constraints
    constraints_mpc = constraints_mpc + [delta_x(:,i) == sys.A*delta_x(:,i-1)+sys.B*delta_u(:,i-1)];  % add a disturbance d here? subtract d?
%     %state constraints
    constraints_mpc =  constraints_mpc +  [-z_dot_max-xr(1) <= delta_x(1,i) <= z_dot_max-xr(1)];
    constraints_mpc =  constraints_mpc + [-alpha_beta_max-xr(2:3)  <= delta_x(2:3,i) <= alpha_beta_max-xr(2:3)];
    constraints_mpc = constraints_mpc + [-alpha_beta_dot_max-xr(5:6)  <= delta_x(5:6,i) <= alpha_beta_dot_max-xr(5:6)];
    constraints_mpc = constraints_mpc + [-gamma_dot_max-xr(7)  <= delta_x(7,i) <= gamma_dot_max-xr(7)];
% 
%     %input constraints
    constraints_mpc = constraints_mpc + [u_min-ur <= delta_u(1:4,i) <= u_max-ur ];
end
constraints_mpc = constraints_mpc + [u_min-ur <= delta_u(1:4,1) <= u_max-ur ];

%Objective / Cost Function
fprintf('setting objective function\n')
objective_mpc = 0;
for i = 1:N
    objective_mpc = objective_mpc + delta_x(:,i)' * Q * delta_x(:,i) + delta_u(:,i)' * R * delta_u(:,i);
end

[Pinf,L,Finf] = dare(sys.A,sys.B,Q,R);

terminal_cost = delta_x(:,N)' * Pinf * delta_x(:,N);
objective_mpc = objective_mpc + terminal_cost;


% Disturbance estimation:
Aug = [sys.A eye(n_states); zeros(n_states) eye(n_states)];
Baug = [sys.B; zeros(n_states,n_inputs)];
Caug = [eye(n_states) eye(n_states)];

Lx = eye(n_states);
Ld = eye(n_states);
L = [Lx; Ld];

filter = struct('Af', Aug - L*Caug, 'Bf', [Baug L]);

% with disturbances
codeoptions = getOptions('simpleMPC_solver');
innerControllerForces = optimizerFORCES(constraints_mpc, objective_mpc, codeoptions, [xk; r; d], uk,{'inputvariables'},{'u0_variable'});
innerController = optimizer(constraints_mpc, objective_mpc, [], [xk; r; d], uk);

fprintf('simulate system with constant r and disturbance filter\n')
[xt ut t rt_forces deltat] = simQuad( sys, innerControllerForces, 1, zeros(7,1), 10, r1,filter);
[xt ut t rt deltat] = simQuad( sys, innerController, 0, zeros(7,1), 10, r1,filter);
