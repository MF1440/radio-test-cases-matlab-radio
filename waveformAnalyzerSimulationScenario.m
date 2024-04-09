close all;
clear;
clc;

% initial data paths
waveformInfoFile = 'waveform/waveformInfo.mat';
waveformSourceFile = 'waveform/waveformSource.mat';

% create waveform analyzer
wfa = WaveformAnalyzer(waveformInfoFile, waveformSourceFile);

% calcualte waveform parameters
wfa.calcWaveformParameters();
% plot power spectral density
wfa.plotPowerSpectrumDensity();
% constellation visualization
wfa.plotPayloadConstellation();

% show all calculated parameters
fprintf('Waveform Mean Power: %f \n', wfa.waveformMeanPower);
fprintf('Channel bandwidth [MHz]: %.3f \n', wfa.channelBandwidth / 1e6);
fprintf('Modulation type: %s \n', wfa.modulationType);
fprintf('Waveform duration [ms]: %3f \n', wfa.waveformDuration * 1e3);
fprintf('Doppler shift (slot) [Hz]: %.3f \n', wfa.dopplerShift);
for sym = 1:14
    fprintf(['Doppler shift (symbol ',num2str(sym),') [Hz]: %.3f \n'], wfa.dopplerShiftAllSym{sym});
end