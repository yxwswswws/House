%% ============================================
%% 公平对比：所有控制器在同一 Simulink 模型上（完全重写版）
%% ============================================
%% 关键改进：
%% 1. ✓ 完全删除 simulateCustomController（简化模型）
%% 2. ✓ 所有控制器都用 sim(env, policy) 在真实 Simulink 上
%% 3. ✓ 与 MathWorks 官方示例 TrainDQNAgentWithLSTMToControlHouseHeatingSystemExample 完全一致
%% ============================================

clear; clc; close all;

%% ========================================
%% 1. 初始化：与 MathWorks 官方示例一致
%% ========================================
fprintf('\n========== 初始化环境 ==========\n');

% 模型和参数（完全按照官方示例）
mdl = "rlHouseHeatingSystem";
open_system(mdl);

sampleTime = 120;           % 决策周期（秒）
maxStepsPerEpisode = 1000;  % 每个片段最多步数
agentBlk = mdl + "/Smart Thermostat/RL Agent";

% 舒适温度范围
comfortMax = 23;
comfortMin = 18;

% 加载温度数据
data = load('temperatureMar21toApr15_2022.mat');
temperatureData = data.temperatureData;

% 数据划分（与官方示例完全一致）
temperatureMarch21 = temperatureData(1:60*24, :);
temperatureApril15 = temperatureData(end-60*24+1:end, :);
temperatureTraining = temperatureData(60*24+1:end-60*24, :);

fprintf('✓ 数据加载完成\n');
fprintf('  训练数据: %d个样本\n', size(temperatureTraining, 1));
fprintf('  验证集1: %d个样本\n', size(temperatureMarch21, 1));
fprintf('  验证集2: %d个样本\n', size(temperatureApril15, 1));

%% ========================================
%% 2. 定义观测和动作空间
%% ========================================
obsInfo = rlNumericSpec([6, 1]);
obsInfo.Name = 'observations';
obsInfo.Description = 'integrated error, error, and reference';

actInfo = rlFiniteSetSpec([0, 1]);
actInfo.Name = 'action';
actInfo.Description = '(0=off,1=on)';

%% ========================================
%% 3. 创建 RL 环境
%% ========================================
fprintf('\n========== 创建环境 ==========\n');

env = rlSimulinkEnv(mdl, agentBlk, obsInfo, actInfo);

% 【关键】使用官方提供的 ResetFcn
env.ResetFcn = @(in) hRLHeatingSystemResetFcn(in);

fprintf('✓ RL 环境创建完成\n');

%% ========================================
%% 4. 初始化所有控制器
%% ========================================
fprintf('\n========== 初始化控制器 ==========\n');

config = struct();
config.mdl = mdl;
config.agentBlk = agentBlk;
config.sampleTime = sampleTime;
config.maxStepsPerEpisode = maxStepsPerEpisode;
config.comfortMax = comfortMax;
config.comfortMin = comfortMin;

controllers = {};
controllerNames = {};

% 1. 规则型控制器
fprintf('1. 规则型控制器... ');
ruleCtrl = RuleBasedController(config);
rulePolicy = CustomControllerPolicy(ruleCtrl, obsInfo, actInfo);
controllers{1} = rulePolicy;
controllerNames{1} = '规则型 (Rule-Based)';
fprintf('✓\n');

% 2. PID 控制器
fprintf('2. PID控制器... ');
pidCtrl = PIDController(config);
pidPolicy = CustomControllerPolicy(pidCtrl, obsInfo, actInfo);
controllers{2} = pidPolicy;
controllerNames{2} = 'PID';
fprintf('✓\n');

% 3. MPC 控制器
fprintf('3. MPC控制器... ');
mpcCtrl = MPCController(config);
mpcPolicy = CustomControllerPolicy(mpcCtrl, obsInfo, actInfo);
controllers{3} = mpcPolicy;
controllerNames{3} = 'MPC';
fprintf('✓\n');

% 4. 基础 Q-Learning
fprintf('4. 基础Q-Learning... ');
qlCtrl = BasicRLController(config);
qlPolicy = CustomControllerPolicy(qlCtrl, obsInfo, actInfo);
controllers{4} = qlPolicy;
controllerNames{4} = 'Q-Learning';
fprintf('✓\n');

% 5. DQN+LSTM（使用官方训练的模型）
fprintf('5. DQN+LSTM... ');
load("HeatControlDQNAgent.mat", "agent");
agent.SampleTime = sampleTime;
controllers{5} = agent;
controllerNames{5} = 'DQN+LSTM (最先进)';
fprintf('✓\n');

fprintf('\n✓ 所有控制器初始化完成\n');

%% ========================================
%% 5. 仿真配置（关键参数）
%% ========================================
% 【关键】使用较短的步数进行验证，加快速度
maxSteps = 720;  % 720 步 = 12小时（与官方示例一致）

simOptions = rlSimulationOptions(...
    'MaxSteps', maxSteps, ...
    'StopOnError', 'on', ...
    'Verbose', false);

%% ========================================
%% 6. 在三个验证集上运行对比实验
%% ========================================
fprintf('\n========== 开始对比实验 ==========\n');

numControllers = length(controllers);
numValidationSets = 3;
results = {};

% 定义三个验证集
validationSets = {
    temperatureMarch21, '验证集1 (3月21日 - 冷天)';
    temperatureApril15, '验证集2 (4月15日 - 温暖)';
    temperatureApril15, '验证集3 (4月15日+8°C - 热天)'
};

for ctrlIdx = 1:numControllers
    ctrlName = controllerNames{ctrlIdx};
    fprintf('\n>> 测试 %d/%d: %s\n', ctrlIdx, numControllers, ctrlName);
    
    methodResults = struct();
    methodResults.name = ctrlName;
    methodResults.energyCosts = [];
    methodResults.comfortViolations = [];
    methodResults.temperatures = {};
    methodResults.actions = {};
    
    for valSetIdx = 1:numValidationSets
        valSetName = validationSets{valSetIdx, 1};
        fprintf('  - %s... ', validationSets{valSetIdx, 2});
        
        try
            % 【关键】将验证数据分配给全局变量，Simulink 会读取它
            if valSetIdx == 3
                % 第三个验证集：温度 +8°C
                validationTemperature = validationSets{valSetIdx, 1};
                validationTemperature(:, 2) = validationTemperature(:, 2) + 8;
            else
                validationTemperature = validationSets{valSetIdx, 1};
            end
            
            % 【关键】分配到全局变量
            assignin('base', 'validationTemperature', validationTemperature);
            
            % 【关键】使用验证 ResetFcn（会从全局变量 validationTemperature 中读取）
            env.ResetFcn = @(in) hRLHeatingSystemValidateResetFcn(in);
            
            % 【关键】运行仿真 - 所有控制器使用完全相同的方式
            experience = sim(env, controllers{ctrlIdx}, simOptions);
            
            % 提取指标
            [energyCost, comfortViolation, temps, actions] = extractMetrics(experience, maxSteps, config);
            
            methodResults.energyCosts = [methodResults.energyCosts; energyCost];
            methodResults.comfortViolations = [methodResults.comfortViolations; comfortViolation];
            methodResults.temperatures{valSetIdx} = temps;
            methodResults.actions{valSetIdx} = actions;
            
            fprintf('完成 (能耗: $%.2f, 舒适违反: %d分钟)\n', energyCost, comfortViolation);
            
        catch ME
            fprintf('失败\n');
            fprintf('  错误: %s\n', ME.message);
            % 继续下一个验证集
        end
    end
    
    results{ctrlIdx} = methodResults;
end

%% ========================================
%% 7. 结果分析与可视化
%% ========================================
fprintf('\n========== 性能汇总 ==========\n\n');

resultTable = table();
for i = 1:numControllers
    resultTable.Method{i} = controllerNames{i};
    resultTable.AvgEnergyCost(i) = mean(results{i}.energyCosts);
    resultTable.StdEnergyCost(i) = std(results{i}.energyCosts);
    resultTable.AvgComfortViolation(i) = mean(results{i}.comfortViolations);
    resultTable.StdComfortViolation(i) = std(results{i}.comfortViolations);
end

disp(resultTable);

%% 绘制对比图表
figure('Name', '公平对比：所有控制器在同一 Simulink 模型', 'NumberTitle', 'off');
fig = gcf;
fig.Position = [100, 100, 1600, 1000];

% 1. 能源成本对比
subplot(2, 3, 1);
energyCosts = cellfun(@(x) mean(x.energyCosts), results);
stdEnergyCosts = cellfun(@(x) std(x.energyCosts), results);
bar(1:numControllers, energyCosts, 'FaceColor', [0.2, 0.6, 0.9]);
hold on;
errorbar(1:numControllers, energyCosts, stdEnergyCosts, 'k.', 'LineWidth', 2);
set(gca, 'XTickLabel', controllerNames, 'XTickLabelRotation', 45);
ylabel('能源成本 ($)');
title('能源成本对比');
grid on;
hold off;

% 2. 舒适度违反对比
subplot(2, 3, 2);
comfortViolations = cellfun(@(x) mean(x.comfortViolations), results);
stdComfortViolations = cellfun(@(x) std(x.comfortViolations), results);
bar(1:numControllers, comfortViolations, 'FaceColor', [0.9, 0.6, 0.2]);
hold on;
errorbar(1:numControllers, comfortViolations, stdComfortViolations, 'k.', 'LineWidth', 2);
set(gca, 'XTickLabel', controllerNames, 'XTickLabelRotation', 45);
ylabel('舒适违反 (分钟)');
title('舒适度性能');
grid on;
hold off;

% 3. 综合评分
subplot(2, 3, 3);
scores = zeros(numControllers, 1);
maxCost = max(energyCosts);
maxViolation = max(comfortViolations);
for i = 1:numControllers
    if maxCost > 0
        cost_score = 1 - energyCosts(i) / maxCost;
    else
        cost_score = 0;
    end
    if maxViolation > 0
        comfort_score = 1 - comfortViolations(i) / maxViolation;
    else
        comfort_score = 1;
    end
    scores(i) = 0.5 * cost_score + 0.5 * comfort_score;
end
bar(1:numControllers, scores, 'FaceColor', [0.2, 0.9, 0.2]);
set(gca, 'XTickLabel', controllerNames, 'XTickLabelRotation', 45);
ylabel('综合评分');
title('综合性能');
grid on;

% 4-6. 温度曲线
colors = lines(numControllers);
for setIdx = 1:3
    subplot(2, 3, 3 + setIdx);
    for i = 1:numControllers
        if ~isempty(results{i}.temperatures{setIdx})
            temps = results{i}.temperatures{setIdx};
            plot(1:length(temps), temps, 'Color', colors(i, :), 'LineWidth', 2, ...
                'DisplayName', controllerNames{i});
            hold on;
        end
    end
    yline(comfortMax, 'r--', 'LineWidth', 1.5, 'DisplayName', '舒适上限');
    yline(comfortMin, 'b--', 'LineWidth', 1.5, 'DisplayName', '舒适下限');
    xlabel('时间步');
    ylabel('温度 (°C)');
    title(sprintf('温度曲线 - %s', validationSets{setIdx, 2}));
    if setIdx == 1
        legend('Location', 'best', 'FontSize', 8);
    end
    grid on;
    hold off;
end

%% 8. DQN+LSTM 优势分析
fprintf('\n========== DQN+LSTM 相对优势分析 ==========\n\n');

dqnIdx = 5;
dqnResults = results{dqnIdx};
dqnEnergy = mean(dqnResults.energyCosts);
dqnComfort = mean(dqnResults.comfortViolations);

fprintf('DQN+LSTM 基准性能：\n');
fprintf('  能源成本: $%.2f\n', dqnEnergy);
fprintf('  舒适违反: %d分钟\n\n', dqnComfort);

for i = 1:numControllers
    if i == dqnIdx
        continue;
    end
    
    otherResults = results{i};
    otherEnergy = mean(otherResults.energyCosts);
    otherComfort = mean(otherResults.comfortViolations);
    
    if otherEnergy > 0
        energyImprovement = (otherEnergy - dqnEnergy) / otherEnergy * 100;
    else
        energyImprovement = 0;
    end
    
    if otherComfort > 0
        comfortImprovement = (otherComfort - dqnComfort) / otherComfort * 100;
    else
        comfortImprovement = 0;
    end
    
    fprintf('%s:\n', controllerNames{i});
    fprintf('  能源成本: $%.2f (DQN+LSTM降低 %.1f%%)\n', otherEnergy, energyImprovement);
    fprintf('  舒适违反: %d分钟 (DQN+LSTM减少 %.1f%%)\n', otherComfort, comfortImprovement);
    fprintf('\n');
end

fprintf('========== 实验完成 ==========\n\n');

%% ========================================
%% 辅助函数
%% ========================================

function [energyCost, comfortViolation, temps, actions] = extractMetrics(experience, maxSteps, config)
    % 提取性能指标（与 MathWorks 官方示例完全一致）
    
    % 房间温度
    obsData = experience.Observation.obs1.Data(1, :, 1:maxSteps);
    roomTemp = squeeze(obsData);
    temps = roomTemp;
    
    % 舒适度违反（分钟数）
    comfortViolation = sum(roomTemp < config.comfortMin) + sum(roomTemp > config.comfortMax);
    comfortViolation = comfortViolation * config.sampleTime / 60;  % 转换为分钟
    
    % 动作
    try
        actionData = experience.Action.act1.Data(:, :, 1:maxSteps);
        actions = squeeze(actionData);
    catch
        actions = [];
    end
    
    % 能源成本（从 SimulationInfo 中提取）
    try
        totalCosts = experience.SimulationInfo(1).househeat_output{1}.Values;
        energyCost = totalCosts.Data(end);
    catch
        % 如果无法提取，计算为 NaN
        energyCost = NaN;
    end
end