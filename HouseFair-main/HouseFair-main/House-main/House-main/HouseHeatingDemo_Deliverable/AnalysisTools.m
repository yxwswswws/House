classdef AnalysisTools
    % 分析工具类
    % 提供对比分析、可视化等功能
    
    methods (Static)
        
        function generateComparisonReport(results, config, filename)
            % 生成详细的对比报告
            if nargin < 3
                filename = 'control_comparison_report.txt';
            end
            
            fid = fopen(filename, 'w');
            fprintf(fid, '========================================\n');
            fprintf(fid, '       控制算法对比分析报告\n');
            fprintf(fid, '========================================\n\n');
            
            fprintf(fid, '实验配置:\n');
            fprintf(fid, '  - 舒适温度范围: [%.1f, %.1f]°C\n', config.comfortMin, config.comfortMax);
            fprintf(fid, '  - 决策周期: %d秒\n', config.sampleTime);
            fprintf(fid, '  - 最大步数: %d\n', config.maxStepsPerEpisode);
            fprintf(fid, '\n');
            
            % 性能指标
            fprintf(fid, '性能指标对比:\n');
            fprintf(fid, '%-30s | %12s | %15s | %12s\n', '算法', '能源成本($)', '舒适度违反(min)', '平均奖励');
            fprintf(fid, repmat('-', 1, 70));
            fprintf(fid, '\n');
            
            for i = 1:length(results)
                r = results{i};
                fprintf(fid, '%-30s | %12.2f | %15d | %12.2f\n', ...
                    r.name, mean(r.energyCosts), mean(r.comfortViolations), mean(r.averageRewards));
            end
            
            fprintf(fid, '\n');
            fprintf(fid, '优势分析 (相对于DQN+LSTM):\n');
            fprintf(fid, '\n');
            
            dqn_cost = mean(results{5}.energyCosts);
            dqn_comfort = mean(results{5}.comfortViolations);
            
            for i = 1:4
                r = results{i};
                cost_diff = mean(r.energyCosts) - dqn_cost;
                comfort_diff = mean(r.comfortViolations) - dqn_comfort;
                
                fprintf(fid, '%s:\n', r.name);
                fprintf(fid, '  能源成本相差: $%.2f (%.1f%%)\n', cost_diff, cost_diff/mean(r.energyCosts)*100);
                fprintf(fid, '  舒适度违反相差: %d分钟 (%.1f%%)\n', ...
                    comfort_diff, comfort_diff/max(mean(r.comfortViolations),1)*100);
                fprintf(fid, '\n');
            end
            
            fclose(fid);
            fprintf('报告已保存到: %s\n', filename);
        end
        
        function createSummaryFigure(results, config)
            % 创建总结图表
            numMethods = length(results);
            
            fig = figure('Name', '控制算法对比总结', 'NumberTitle', 'off');
            fig.Position = [100, 100, 1400, 900];
            
            % 主要指标矩阵
            metrics = zeros(numMethods, 3);
            labels = {};
            
            for i = 1:numMethods
                r = results{i};
                labels{i} = r.name;
                metrics(i, 1) = mean(r.energyCosts);
                metrics(i, 2) = mean(r.comfortViolations);
                metrics(i, 3) = mean(r.averageRewards);
            end
            
            % 归一化指标
            normalized = metrics ./ max(metrics, [], 1);
            
            % 绘制雷达图
            ax = subplot(1, 2, 1, polaraxes);
            theta = linspace(0, 2*pi, size(normalized, 2)+1);
            colors = lines(numMethods);
            
            for i = 1:numMethods
                rho = [normalized(i, :), normalized(i, 1)];
                plot(ax, theta, rho, 'o-', 'Color', colors(i,:), 'DisplayName', labels{i}, 'LineWidth', 2);
                hold on;
            end
            
            ax.ThetaTickLabel = {'能源成本', '舒适度', '奖励'};
            legend('Location', 'northeast');
            title('性能雷达图');
            
            % 综合评分
            subplot(1, 2, 2);
            scores = 0.4 * normalized(:,1) + 0.4 * (1-normalized(:,2)) + 0.2 * normalized(:,3);
            bar(1:numMethods, scores);
            set(gca, 'XTickLabel', labels, 'XTickLabelRotation', 45);
            ylabel('综合评分');
            title('综合性能评分');
            grid on;
        end
        
        function exportResults(results, config, filename)
            % 导出结果到CSV
            if nargin < 3
                filename = 'control_comparison_results.csv';
            end
            
            % 创建数据表
            fid = fopen(filename, 'w');
            fprintf(fid, '算法,能源成本($),标准差,舒适度违反(min),标准差,平均奖励,标准差\n');
            
            for i = 1:length(results)
                r = results{i};
                fprintf(fid, '%s,%.2f,%.2f,%d,%.2f,%.2f,%.2f\n', ...
                    r.name, ...
                    mean(r.energyCosts), std(r.energyCosts), ...
                    mean(r.comfortViolations), std(r.comfortViolations), ...
                    mean(r.averageRewards), std(r.averageRewards));
            end
            
            fclose(fid);
            fprintf('结果已导出到: %s\n', filename);
        end
    end
end