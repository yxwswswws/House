classdef RuleBasedController
    % 规则型控制器
    % 基于简单规则的启发式控制：温度低于下限则开，高于上限则关
    % 这是最简单的基准方法
    
    properties
        config
        previousAction = 0
        hysteresis = 1.0  % 迟滞范围，防止频繁切换
    end
    
    methods
        function obj = RuleBasedController(config)
            % 初始化规则控制器
            obj.config = config;
        end
        
        function action = getAction(obj, observation)
            % 根据观察返回控制动作
            % observation: [T_room, T_outside, T_max, T_min, heater_state, time]
            
            T_room = observation(1);
            T_max = observation(3);
            T_min = observation(4);
            
            % 规则1: 如果温度过低，开加热器
            if T_room < T_min - obj.hysteresis
                action = 1;
            % 规则2: 如果温度过高，关加热器
            elseif T_room > T_max + obj.hysteresis
                action = 0;
            % 规则3: 否则保持当前状态
            else
                action = obj.previousAction;
            end
            
            obj.previousAction = action;
        end
    end
end