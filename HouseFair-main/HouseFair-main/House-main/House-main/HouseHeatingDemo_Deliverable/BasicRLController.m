classdef BasicRLController
    % 基础强化学习控制器
    % 使用简单的表格Q-Learning（无神经网络）
    % 用于展示基础RL vs 深度RL的差异
    
    properties
        % Q-Learning参数
        alpha = 0.1        % 学习率
        gamma = 0.95       % 折扣因子
        epsilon = 0.1      % 探索率
        
        % Q表: 状态-动作价值
        % 量化状态空间为离散的"箱"
        Q_table = containers.Map('KeyType', 'char', 'ValueType', 'any')
        
        % 状态量化参数
        temp_bins = 5       % 温度量化的箱数
        temp_min = 10
        temp_max = 30
        
        % 经验回放
        experience_buffer = []
        buffer_size = 100
    end
    
    methods
        function obj = BasicRLController(config)
            % 初始化基础RL控制器
            if isfield(config, 'comfortMin')
                obj.temp_min = config.comfortMin - 5;
            end
            if isfield(config, 'comfortMax')
                obj.temp_max = config.comfortMax + 5;
            end
            
            % 初始化Q表
            obj = obj.initializeQTable();
        end
        
        function obj = initializeQTable(obj)
            % 初始化Q表，对所有状态-动作对
            for T_idx = 1:obj.temp_bins
                for a = [0, 1]
                    state_key = sprintf('T%d', T_idx);
                    if ~isKey(obj.Q_table, state_key)
                        obj.Q_table(state_key) = [0, 0];  % Q值 for action 0 and 1
                    end
                end
            end
        end
        
        function action = getAction(obj, observation)
            % ε-贪心策略
            T_room = observation(1);
            state_idx = obj.quantizeTemperature(T_room);
            state_key = sprintf('T%d', state_idx);
            
            % 以epsilon概率随机探索，否则利用
            if rand() < obj.epsilon
                % 探索：随机选择动作
                action = randi([0, 1]) - 1;  % 0 or 1
            else
                % 利用：选择Q值最大的动作
                Q_values = obj.Q_table(state_key);
                [~, action] = max(Q_values);
                action = action - 1;  % Convert to 0 or 1
            end
        end
        
        function obj = updateQValue(obj, state, action, reward, next_state)
            % Q-Learning更新规则
            % Q(s,a) <- Q(s,a) + alpha * [r + gamma*max Q(s',a') - Q(s,a)]
            
            state_key = sprintf('T%d', state);
            next_state_key = sprintf('T%d', next_state);
            
            Q_current = obj.Q_table(state_key);
            Q_next = obj.Q_table(next_state_key);
            
            action_idx = action + 1;  % Convert 0/1 to 1/2 for indexing
            
            % Q值更新
            max_Q_next = max(Q_next);
            Q_current(action_idx) = Q_current(action_idx) + ...
                obj.alpha * (reward + obj.gamma * max_Q_next - Q_current(action_idx));
            
            obj.Q_table(state_key) = Q_current;
        end
        
        function state_idx = quantizeTemperature(obj, temperature)
            % 将连续温度量化为离散状态
            normalized = (temperature - obj.temp_min) / (obj.temp_max - obj.temp_min);
            normalized = max(0, min(1, normalized));  % Clip to [0, 1]
            state_idx = max(1, ceil(normalized * obj.temp_bins));
        end
    end
end