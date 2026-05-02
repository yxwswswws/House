classdef MPCController
    % 模型预测控制 (Model Predictive Control)
    % 使用预测模型，在有限时域内求解最优控制问题
    % 这是高级经典控制方法
    
    properties
        % MPC参数
        predictionHorizon = 10  % 预测步数
        controlHorizon = 5      % 控制步数
        
        % 热力学模型参数（简化线性模型）
        alpha = 0.1     % 温度损失系数
        beta = 0.3      % 加热器效率
        
        % 约束与目标
        T_target = 20.5
        T_max = 23
        T_min = 18
        
        % 成本权重
        weight_comfort = 1.0    % 舒适度权重
        weight_energy = 0.5     % 能源成本权重
        weight_action = 0.1     % 动作变化权重
    end
    
    methods
        function obj = MPCController(config)
            % 初始化MPC控制器
            if isfield(config, 'comfortMax') && isfield(config, 'comfortMin')
                obj.T_max = config.comfortMax;
                obj.T_min = config.comfortMin;
                obj.T_target = (config.comfortMin + config.comfortMax) / 2;
            end
        end
        
        function action = getAction(obj, observation)
            % MPC控制：求解最优控制序列
            % observation: [T_room, T_outside, T_max, T_min, heater_state, time]
            
            T_room = observation(1);
            T_outside = observation(2);
            heater_prev = observation(5);
            
            % 求解有限时域优化问题
            % min J = sum(||T - T_target||^2) + lambda*||u||^2
            % s.t. 热力学约束, 动作约束
            
            % 使用简化的贪心方法（完整MPC需要优化工具箱）
            best_action = 0;
            best_cost = inf;
            
            % 评估两个可能的动作
            for u = [0, 1]
                % 预测未来状态
                T_pred = T_room;
                cost = 0;
                
                for step = 1:obj.predictionHorizon
                    % 热力学模型: T(k+1) = (1-alpha)*T(k) + alpha*T_out + beta*u
                    T_pred = (1 - obj.alpha) * T_pred + obj.alpha * T_outside + obj.beta * u;
                    
                    % 计算成本
                    % 舒适度成本
                    if T_pred < obj.T_min || T_pred > obj.T_max
                        comfort_cost = obj.weight_comfort * (T_pred - obj.T_target)^2;
                    else
                        comfort_cost = 0;
                    end
                    
                    % 能源成本
                    energy_cost = obj.weight_energy * u;
                    
                    % 累积成本
                    cost = cost + comfort_cost + energy_cost;
                end
                
                % 考虑动作切换成本
                if u ~= heater_prev
                    cost = cost + obj.weight_action * 0.1;
                end
                
                % 选择最小成本的动作
                if cost < best_cost
                    best_cost = cost;
                    best_action = u;
                end
            end
            
            action = best_action;
        end
        
        function setModelParameters(obj, alpha, beta)
            % 设置热力学模型参数
            obj.alpha = alpha;
            obj.beta = beta;
        end
    end
end