if ~exist('combinePlots','var'); combinePlots = true; end; 

if combinePlots
    %% Plot the quad along the trajectory
    figure(2);
    clf
    hold on
    grid on

    plot3(x(:,1),x(:,2),x(:,3),'k-');
    I = ceil(linspace(1,length(t),10));
    for i = 1:length(I)
        j = I(i);
        state = struct('x',x(j,:)','v',v(j,:)','theta',theta(j,:)','omega',omega(j,:)');
        plotQuad(quad, state, u(j,:));
    end

    view(3)
    camlight
    axis vis3d
    axis equal
    xlabel('x');
    ylabel('y');
    zlabel('z');
    Sys.uMin  = -0.70071429*ones(4,1);
    Sys.uMax  = ones(4,1)-0.70071429*ones(4,1);
    Sys.angleMin = -[1;1]*(10/180)*pi;
    Sys.angleMax =  [1;1]*(10/180)*pi;
    Sys.zVelMin = -1;
    Sys.zVelMax = 1;
    Sys.angVelMin   = -[15;15;60]*pi/180;
    Sys.angVelMax   = [15;15;60]*pi/180;


    figure(1); clf;
    ax(1) = subplot(4,2,1); grid on; hold on;
        plot(t, x(:,1), t, x(:,2), t, x(:,3),'LineWidth',1.1);hold on
        plot(t,ref(:,1),'--',t,ref(:,2),'--',t,ref(:,3),'--')
        legend('x', 'y', 'z','ref_x','ref_y','ref_z','location','SE');
        ylabel('m'); xlabel('s')
        
    ax(2) = subplot(4,2,3); grid on; hold on;
        plot(t, theta(:,1)*180/pi, t, theta(:,2)*180/pi,'LineWidth',1.1); hold on
        plot(t, u1(:,2)*180/pi,'--', t, u1(:,3)*180/pi,'--')
        plot(t,repmat(Sys.angleMin(1)*180/pi,numel(t))','--','Color','Red','LineWidth',2)
        plot(t,repmat(Sys.angleMax(1)*180/pi,numel(t))','--','Color','Red','LineWidth',2)
        legend('Roll', 'Pitch', 'Roll ref', 'Pitch ref','location','SE');
        ylabel('deg'); xlabel('s')

    ax(3) = subplot(4,2,7); grid on; hold on;
        plot(t, v(:,3), 'LineWidth',1.1); hold on
        plot(t, u1(:,1),'--')
        plot(t,repmat(Sys.zVelMin,numel(t))','--','Color','Red','LineWidth',2)
        plot(t,repmat(Sys.zVelMax,numel(t))','--','Color','Red','LineWidth',2)
        legend('zdot', 'zdot ref','location','SE');
        ylabel('m/s'); xlabel('s')

    ax(4) = subplot(4,2,5); grid on; hold on;
        plot(t, theta(:,3)*180/pi,'LineWidth',1.1);
        plot(t,180*ref(:,4)/pi,'--')
        legend('Yaw','ref_{Yaw}','location','SE');
        ylabel('deg'); xlabel('s')

    ax(5) = subplot(4,2,8); grid on; hold on;
        plot(t, u(:,1), t, u(:,2), t, u(:,3), t, u(:,4));
        plot(t,repmat(0,numel(t))','--','Color','Red','LineWidth',2)
        plot(t,repmat(1,numel(t))','--','Color','Red','LineWidth',2)
        legend('rotor speed 1', 'rotor speed 2', 'rotor speed 3', 'rotor speed 4','location','SE');
        ylabel('u'); xlabel('s')

    ax(6) = subplot(4,2,2); grid on; hold on;
        plot(t, v(:,1), t, v(:,2),'LineWidth',1.1);
        legend('x dot', 'y dot','location','SE');
        ylabel('m/s'); xlabel('s')

    ax(7) = subplot(4,2,4);grid on; hold on;
        plot(t, omega(:,1)*180/pi, t, omega(:,2)*180/pi,'LineWidth',1.1);
        plot(t,repmat(Sys.angVelMin(1)*180/pi,numel(t))','--','Color','Red','LineWidth',2)
        plot(t,repmat(Sys.angVelMax(1)*180/pi,numel(t))','--','Color','Red','LineWidth',2)
        legend('Roll rate', 'Pitch rate','location','SE');
        ylabel('deg/s'); xlabel('s')

    ax(8) = subplot(4,2,6); grid on; hold on;
        plot(t, omega(:,3)*180/pi,'LineWidth',1.1);
        plot(t,repmat(Sys.angVelMin(3)*180/pi,numel(t))','--','Color','Red','LineWidth',2)
        plot(t,repmat(Sys.angVelMax(3)*180/pi,numel(t))','--','Color','Red','LineWidth',2)
        legend('Yaw rate','location','SE');
        ylabel('deg/s'); xlabel('s')
    
    linkaxes(ax,'x');

    if(exist('d1','var'))
        figure(3); clf; 
        ax(1) = subplot(2,1,2); grid on; hold on;
            plot(t, d1(:,1), 'LineWidth',1.1);
            legend('dz dist','location','SE')
            ylabel('m'); xlabel('s')
    
        ax(2) = subplot(2,1,1); grid on; hold on;
            plot(t, d1(:,2), t, d1(:,3), t, d1(:,4),'LineWidth',1.1);
            legend('droll dist', 'dpitch dist','dyaw dist','location','SE');
            ylabel('deg'); xlabel('s')
       
        linkaxes(ax,'x');
    end 
else
    % Plot the quad along the trajectory
    figure(1);
    clf
    hold on
    grid on

    plot3(x(:,1),x(:,2),x(:,3),'k-');
    I = ceil(linspace(1,length(t),10));
    for i = 1:length(I)
        j = I(i);
        state = struct('x',x(j,:)','v',v(j,:)','theta',theta(j,:)','omega',omega(j,:)');
        plotQuad(quad, state, u(j,:));
    end

    view(3)
    camlight
    axis vis3d
    axis equal
    xlabel('x');
    ylabel('y');
    zlabel('z');
    Sys.uMin  = -0.70071429*ones(4,1);
    Sys.uMax  = ones(4,1)-0.70071429*ones(4,1);
    Sys.angleMin = -[1;1]*(10/180)*pi;
    Sys.angleMax =  [1;1]*(10/180)*pi;
    Sys.zVelMin = -1;
    Sys.zVelMax = 1;
    Sys.angVelMin   = -[15;15;60]*pi/180;
    Sys.angVelMax   = [15;15;60]*pi/180;


    figure(2); clf; grid on; hold on;
    plot(t, x(:,1), t, x(:,2), t, x(:,3),'LineWidth',1.1);hold on
    plot(t,ref(:,1),'--',t,ref(:,2),'--',t,ref(:,3),'--')
    legend('x', 'y', 'z','ref_x','ref_y','ref_z');


    figure(3); clf; grid on; hold on;
    plot(t, theta(:,1)*180/pi, t, theta(:,2)*180/pi,'LineWidth',1.1); hold on
    plot(t, u1(:,2)*180/pi,'--', t, u1(:,3)*180/pi,'--')
    plot(t,repmat(Sys.angleMin(1)*180/pi,numel(t))','--','Color','Red','LineWidth',2)
    plot(t,repmat(Sys.angleMax(1)*180/pi,numel(t))','--','Color','Red','LineWidth',2)
    legend('Roll', 'Pitch', 'Roll ref', 'Pitch ref');


    figure(4); clf; grid on; hold on;
    plot(t, v(:,3), 'LineWidth',1.1); hold on
    plot(t, u1(:,1),'--')
    plot(t,repmat(Sys.zVelMin,numel(t))','--','Color','Red','LineWidth',2)
    plot(t,repmat(Sys.zVelMax,numel(t))','--','Color','Red','LineWidth',2)
    legend('zdot', 'zdot ref');


    figure(5); clf; grid on; hold on;
    plot(t, theta(:,3)*180/pi,'LineWidth',1.1);
    plot(t,180*ref(:,4)/pi,'--')
    legend('Yaw','ref_{Yaw}');

    figure(6); clf; grid on; hold on;
    plot(t, u(:,1), t, u(:,2), t, u(:,3), t, u(:,4));
    plot(t,repmat(0,numel(t))','--','Color','Red','LineWidth',2)
    plot(t,repmat(1,numel(t))','--','Color','Red','LineWidth',2)
    legend('rotor speed 1', 'rotor speed 2', 'rotor speed 3', 'rotor speed 4');

    figure(7); clf; grid on; hold on;
    plot(t, v(:,1), t, v(:,2),'LineWidth',1.1);
    legend('x dot', 'y dot');


    figure(8); clf; grid on; hold on;
    plot(t, omega(:,1)*180/pi, t, omega(:,2)*180/pi,'LineWidth',1.1);
    plot(t,repmat(Sys.angVelMin(1)*180/pi,numel(t))','--','Color','Red','LineWidth',2)
    plot(t,repmat(Sys.angVelMax(1)*180/pi,numel(t))','--','Color','Red','LineWidth',2)
    legend('Roll rate', 'Pitch rate');

    figure(9); clf; grid on; hold on;
    plot(t, omega(:,3)*180/pi,'LineWidth',1.1);
    plot(t,repmat(Sys.angVelMin(3)*180/pi,numel(t))','--','Color','Red','LineWidth',2)
    plot(t,repmat(Sys.angVelMax(3)*180/pi,numel(t))','--','Color','Red','LineWidth',2)
    legend('Yaw rate');

    if(exist('d1','var'))
        figure(10); clf; grid on; hold on;
        plot(t, d1(:,1), 'LineWidth',1.1);
        legend('dz dist')
    end

    if(exist('d1','var'))
        figure(11); clf; grid on; hold on;
        plot(t, d1(:,2), t, d1(:,3), t, d1(:,4),'LineWidth',1.1);
        legend('droll dist', 'dpitch dist','dyaw dist');
    end 
end







