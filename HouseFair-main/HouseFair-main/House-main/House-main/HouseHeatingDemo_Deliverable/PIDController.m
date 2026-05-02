classdef PIDController
    % PID控制器
    % 经典的PID（比例-积分-微分）控制器
    % 广泛用于工业HVAC系统
    
    properties
        % PID参数
        Kp = 0.05;      % 比例系数
        Ki = 0.02;      % 积分系数
        Kd = 0.01;      % 微分系数
        
        % 内部状态
        setpoint = 20.5;  % 目标温度（舒适范围中点）
        integral_error = 0
        previous_error = 0
        
        % 输出限制
        output_min = -5
        output_max = 5
    end
    
    methods
        function obj = PIDController(config)
            % 初始化PID控制器
            % 可以根据config调整参数
            if isfield(config, 'comfortMin') && isfield(config, 'comfortMax')
                obj.setpoint = (config.comfortMin + config.comfortMax) / 2;
            end
        end
        
        function action = getAction(obj, observation)
            % PID控制律
            % observation: [T_room, T_outside, T_max, T_min, heater_state, time]
            
            T_room = observation(1);
            
            % 计算误差
            error = obj.setpoint - T_room;  % 目标温度 - 实际温度
            
            % 比例项
            P = obj.Kp * error;
            
            % 积分项（累积误差）
            obj.integral_error = obj.integral_error + error;
            % 积分饱和限制
            obj.integral_error = max(min(obj.integral_error, 10), -10);
            I = obj.Ki * obj.integral_error;
            
            % 微分项（误差变化率）
            D = obj.Kd * (error - obj.previous_error);
            obj.previous_error = error;
            
            % 计算输出
            output = P + I + D;
            
            % 输出限制
            output = max(min(output, obj.output_max), obj.output_min);
            
            % 转换为二值动作（开/关）
            if output > 0
                action = 1;  % 开加热器
            else
                action = 0;  % 关加热器
            end
        end
        
        function setTuningParameters(obj, Kp, Ki, Kd)
            % 调整PID参数
            obj.Kp = Kp;
            obj.Ki = Ki;
            obj.Kd = Kd;
        end
    end
end