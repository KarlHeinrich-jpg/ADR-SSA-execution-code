clear,clc,close all
%% 绘制F1-F10
dim = 10; %维度，可选 2, 10, 30, 50, 100
for i = 1:12
    str = ['F',num2str(i)]; %函数名
    [x,y,f] = Plot_CEC2022(str,dim);

    subplot(3,4,i)
    surfc(x,y,f,'LineStyle','none');
    colormap sky
    title(str);
end