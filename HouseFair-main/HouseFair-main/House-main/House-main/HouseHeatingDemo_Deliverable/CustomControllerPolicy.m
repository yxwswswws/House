classdef CustomControllerPolicy
    % CustomControllerPolicy - 将自定义控制器适配为 RL Policy
    % 
    % 这个类使用适配器模式，将你的规则型、PID、MPC等控制器
    % 转换为 MATLAB RL 工具箱兼容的策略对象
    % 
    % 关键特性：
    %   - 不需要继承 rl.policy.Policy（兼容性更好）
    %   - 支持离散和连续动作空间
    %   - 自动处理观测和动作格式转换
    %   - 与 sim(env, policy) 完全兼容
    % 
    % 使用方法：
    %   controller = RuleBasedController(config);
    %   policy = CustomControllerPolicy(controller, obsInfo, actInfo);
    %   experience = sim(env, policy, options);
    
    properties
        Controller              % 自定义控制器实例
        ObservationInfo         % 观测空间信息
        ActionInfo              % 动作空间信息
    end
    
    methods
        function obj = CustomControllerPolicy(controller, obsInfo, actInfo)
            % 初始化自定义策略
            % 
            % 输入：
            %   controller: 自定义控制器对象（需要有 getAction 方法）
            %   obsInfo:    rlNumericSpec 或 rlFiniteSetSpec
            %   actInfo:    rlFiniteSetSpec 或 rlNumericSpec
            
            % 保存控制器和空间信息
            obj.Controller = controller;
            obj.ObservationInfo = obsInfo;
            obj.ActionInfo = actInfo;
        end
        
        function action = getAction(obj, observation)
            % 根据观察返回动作
            %
            % 输入：
            %   observation: 观测值 (可以是列向量或行向量)
            %
            % 输出：
            %   action: 动作值
            
            % 确保观测是列向量
            if isrow(observation)
                observation = observation';
            end
            
            % 调用自定义控制器的 getAction 方法
            try
                action = obj.Controller.getAction(observation);
            catch ME
                % 如果控制器没有 getAction 方法，尝试直接计算
                warning('CustomControllerPolicy: 控制器不支持 getAction 方法。错误: %s', ME.message);
                action = 0;  % 默认动作
            end
            
            % 将动作转换为 RL 工具箱格式
            action = obj.formatAction(action);
        end
        
        function action = formatAction(obj, rawAction)
            % 将原始动作转换为 RL 工具箱兼容的格式
            %
            % 输入：
            %   rawAction: 控制器返回的原始动作
            %
            % 输出：
            %   action: RL 工具箱兼容的动作
            
            % 获取动作类型和范围
            actSpec = obj.ActionInfo;
            
            % 如果动作空间是离散的 (rlFiniteSetSpec)
            if isa(actSpec, 'rl.util.rlFiniteSetSpec')
                % 获取可用的离散动作
                possibleActions = actSpec.Elements;
                
                % 如果 rawAction 已经在可用动作中，直接返回
                if any(possibleActions == rawAction)
                    action = rawAction;
                else
                    % 否则，找最接近的动作
                    [~, idx] = min(abs(possibleActions - rawAction));
                    action = possibleActions(idx);
                end
            
            % 如果动作空间是连续的 (rlNumericSpec)
            elseif isa(actSpec, 'rl.util.rlNumericSpec')
                % 限制在动作范围内
                lowerLimit = actSpec.LowerLimit;
                upperLimit = actSpec.UpperLimit;
                action = max(lowerLimit, min(upperLimit, rawAction));
            else
                % 其他情况，直接返回
                action = rawAction;
            end
        end
    end
end
