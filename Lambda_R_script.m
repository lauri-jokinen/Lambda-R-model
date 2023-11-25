%%% Code to Compute Solutions and to Generate Figures for Flat Friedmann Differential Equation

% Author: Lauri Jokinen, lauri.jokinen@iki.fi
% https://github.com/lauri-jokinen/Lambda-R-model

% This file includes all relevant solvers regarding the figures.
% To keep the code short, the complete code for the figures is not shown.
% Code for an example graph is given.

% Contents:
% * Declaration of global variables (Hubble constant etc.)
% * Example figure
% * Evaluate numerical results (Optimal Omega^B etc.)
% * ODE integration functions
% * Equation solver functions (flatness equation solver etc.)



%%% DECLARATION OF GLOBAL VARIABLES

% We define a struct, G, which is then passed to functions.

% Hubble constant, and unit conversion factor
G.convertion_factor = 0.001 * 3.15576 / (1.495978707 * 6.48 / pi);
G.Hubble_constant = 67.26 * G.convertion_factor;

% ODE integration termination time
% (put a low value for speed; high value for robustness)
G.ode_t_termination = 30;

% This number sets required precision for all numerical routines
% Lower number increases precision.
G.precision = 1e-3;

% Options for numerical algorithms
G.fsolveOptions  = optimoptions('fsolve', ...
            'OptimalityTolerance',G.precision, ...
            'FunctionTolerance', G.precision, ...
            'StepTolerance', G.precision, ...
            'MaxFunctionEvaluations', ceil(sqrt(1/G.precision)), ...
            'MaxIterations', ceil(sqrt(1/G.precision)), ...
            'Display', 'off');
G.fminuncOptions = optimoptions('fminunc', ...
            'OptimalityTolerance', G.precision, ...
            'StepTolerance', G.precision, ...
            'MaxFunctionEvaluations', ceil(sqrt(1/G.precision)), ...
            'MaxIterations', ceil(sqrt(1/G.precision)), ...
            'Display', 'off');



%%% EXAMPLE FIGURE

[~, a, t, Omega_LR, b] = LR_model(G,0.049,0.6881,1);
plot(t, a)
title('Example \LambdaR-model')
xlabel('Time in Gyrs')
ylabel('a(t)')



%%% EVALUATE NUMERICAL RESULTS
% Evaluate numerical results described in the Code Manual

G.Omega_B = 0.049;

% Solve flatness equation, and store result
G.LR_Omega_L = flatness_solve_Omega_L(G, G.Omega_B, 1);

% Age of the universe, with benchmark model
[~, ~, t_benchmark] = LR_model(G, 0.049 + 0.268, 0.683, 0);
G.benchmark_age = -t_benchmark(1);

% Optimal Omega^B
disp('Evaluating optimal Omega^B... this may take a while')
[G.Omega_LR_opt, G.Omega_B_opt, G.Omega_L_opt] = optimal_Omega_B(G);
disp('Done!')

% Age-optimal Omega^D and alpha: case 2
[G.Omega_D_opt, G.alpha_opt] = optimal_Omega_D_and_alpha(G);

% Show the results
disp(G)




%%% ODE INTEGRATION

% Main function
function [Omega_LR_T, a, t, Omega_LR, b, T_index] = LR_model(G, Omega_BD, Omega_L, alpha)
    % G is the global struct
    % T_index has the property a(T_index) == 1 (or closest to it)

    a0 = 1e-16;
    b0 = 0;
    t0 = 0;

    y_dot = @(t,y)odes(t, y, G.Hubble_constant, Omega_BD, Omega_L, alpha);

    opts = odeset('Events',@(t,y)ode_events(t, y, y_dot), ...
        'RelTol',1e-1*G.precision, ...
        'AbsTol',1e-2*G.precision); % Create events function
    
    [t, y, t_events, y_events] = ode23s(y_dot, [t0, G.ode_t_termination], [a0;b0], opts);
    
    % Add the 'events' to the result vectors, one by one
    for p = 1:length(t_events)
        ind = sum(t < t_events(p));
        t = [t(1:ind);   t_events(p);   t((ind+1):end)];
        y = [y(1:ind,:); y_events(p,:); y((ind+1):end,:)];
    end
    
    a = y(:,1);
    b = y(:,2);
    
    % find the event, a(T) = 1, and shift time axis, s.t., a(t=0) = 1
    [~, T_index] = min(abs(a - 1));
    T_index = T_index(1);
    t = t - t(T_index);
    
    % evaluate Omega_Lambda_R(t)
    Omega_LR = G.Hubble_constant * sqrt(Omega_L) * b ./ a;
    Omega_LR_T = Omega_LR(T_index);
end

% The differential equations
function y_dot = odes(t, y, Hubble_constant, Omega_BD, Omega_L, alpha) % differential equation
    y_dot = [Hubble_constant * sqrt(Omega_BD/y(1) + alpha*Hubble_constant*sqrt(Omega_L)*y(2)/y(1)^2 + y(1)^2*Omega_L);
             y(1) * exp(-t * Hubble_constant * sqrt(Omega_L))];
end

% Declare ODE events
function [value,isterminal,direction] = ode_events(t, y, y_dot)
    y_dot_value = y_dot(t,y);
    value = [y(1) - 1;                                    % event a(t) = 1
             y(1)*y_dot_value(2) - y(2)*y_dot_value(1)];  % event max Omega^{Lambda R}_T
    % ignore further definitions
    isterminal = [0; 0];
    direction = [0; 0];
end



%%% EQUATION SOLVERS

% Solves Omega^Lambda from the flatness equation
function Omega_L = flatness_solve_Omega_L(G, Omega_B, alpha)
    if Omega_B==1
        Omega_L = 0;
        return
    end
    % Function 'LR_model' returns value 'Omega_LR_T'
    Omega_L = fsolve(@(Omega_L) alpha*LR_model(G, Omega_B, abs(Omega_L), alpha) + Omega_B + abs(Omega_L) - 1, ...
                    (1-Omega_B)^1.6,... % initial guess
                    G.fsolveOptions);
    Omega_L = abs(Omega_L); % this is to suppress complex result
end

% Solves optimal Omega^B
function [Omega_LR, Omega_B, Omega_L] = optimal_Omega_B(G)
    % Function 'LR_model' returns value 'Omega_LR_T'
    [Omega_B, Omega_LR] = fminunc(@(Omega_B)-LR_model(G, Omega_B, flatness_solve_Omega_L(G,Omega_B,1), 1), ...
                                   0.0458, ... % initial guess
                                   G.fminuncOptions);
    Omega_LR = -Omega_LR; % change sign because of minimization instead of max.
    Omega_L = 1 - Omega_B - Omega_LR;
end

% Solves age-optimal Omega^D and alpha: case 2
function [Omega_D_opt, alpha_opt] = optimal_Omega_D_and_alpha(G)
    x = fsolve(@(x)objective_function_optimal_Omega_D_and_alpha(G, x(1), x(2)),[0.26,0.083], G.fsolveOptions);
    Omega_D_opt = x(1);
    alpha_opt = x(2);
end

% This is used in the above solver
function res = objective_function_optimal_Omega_D_and_alpha(G, Omega_D, alpha)
    Omega_L = 1 - G.Omega_LR_opt/G.Omega_B_opt * G.Omega_B - G.Omega_B;
    % Function 'LR_model' returns value 'Omega_LR_T'
    [~, ~, t, Omega_LR, ~, T_index] = LR_model(G, G.Omega_B + Omega_D, Omega_L, alpha);
    res = [(Omega_D + alpha*Omega_LR(T_index)) / G.Omega_B - G.Omega_LR_opt/G.Omega_B_opt;
           t(1) + G.benchmark_age];
end
