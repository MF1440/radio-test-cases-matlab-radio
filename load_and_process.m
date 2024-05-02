function [processedData,inputData] = load_and_process(silent_mode,fname1,fname2)
cd waveform
close all
%clear all
% load('waveformInfo.mat');
% load('waveformSource.mat');
load(fname1);
load(fname2);
cd ..\
%silent_mode = 0;
number_points_to_display_in_constellation = info.subCarriersCount;%3168
nfft=info.Nfft;
points_Number = zeros(1,info.symbolsCount);
snr_array= zeros(1,info.symbolsCount);
e_noise_per_subcarrier = zeros(1,info.symbolsCount);
e_sig_per_subcarrier = zeros(1,info.symbolsCount);
phaseShift = zeros(1,info.symbolsCount);
demodulatedData=[];
for num_frame=1:info.symbolsCount
 if num_frame==1
  stpoint = 1;
 else
  stpoint =  sum(info.SymbolLengths(1:(num_frame-1)))+1;
 end 
 endpoint = stpoint+info.SymbolLengths(num_frame)-1;
 frame_rx=rxWaveform(stpoint: endpoint);
 n1=(nfft - info.subCarriersCount)/2+1;
 n2=n1+info.subCarriersCount;
 nullidx = [1:n1 (n2+1):nfft]';
 cplen = info.CyclicPrefixLengths(num_frame);
 symOffset = cplen - info.Windowing;
 xx1=frame_rx(1:cplen-info.Windowing);
 xx2=frame_rx(nfft+1:nfft+cplen-info.Windowing);
 Phi = wrapTo2Pi(angle(mean(xx1.*conj(xx2))));%3.665191429188099
 %info.SymbolPhases(num_frame) = Phi;
 phaseShift(num_frame) = Phi;
 w=0;
 Phase_Correction=exp(-(1:length(frame_rx)).*((Phi+2*w*pi)*1i)/nfft);
 frame_rx=frame_rx.*Phase_Correction';
 if num_frame==1 & silent_mode == 0
  figure()
  plot(1:cplen,abs(frame_rx(1:cplen)-frame_rx(nfft+1:end)));
  title({'Abs value of the diffirence between the dopler shift';['corrected cyclic prefixes and windowing. cplen=',num2str(cplen),'windowing=',num2str(info.Windowing)]});
 end 
 xx1=frame_rx(1:cplen-info.Windowing);
 xx2=frame_rx(nfft+1:nfft+cplen-info.Windowing);
 ave_noise_power = mean((xx1-xx2).*conj(xx1-xx2))/2;
 xtmp=frame_rx(symOffset:symOffset+nfft);
 sig_and_noise_power = mean(xtmp.*conj(xtmp));
 snr = 10*log10((sig_and_noise_power-ave_noise_power)/ave_noise_power);

 y1 = ofdmdemod(frame_rx,nfft,cplen,symOffset);%,nullidx
 ny1=mean(y1(1:n1).*conj(y1(1:n1)));
 ey1=mean(y1(n1+1:n2).*conj(y1(n1+1:n2)));
 snr_after_demod=10*log10((ey1-ny1)/ny1);
 snr_array(num_frame) = snr_after_demod;
 e_noise_per_subcarrier(num_frame) = ny1;
 e_sig_per_subcarrier(num_frame) = ey1-ny1;
 frame_IQ=y1(n1+1:n2);
 demodulatedData=[demodulatedData, frame_IQ];
 if silent_mode == 0
  figure()
  plot(frame_IQ(1:number_points_to_display_in_constellation),'r*');
  title({['Frame: ',num2str(num_frame)], ['Constelation points:',num2str(number_points_to_display_in_constellation)]});
 end 
 threshold=max(abs(frame_IQ))-4*sqrt(ny1);
 [corner_pos_y1,b]=find(abs(frame_IQ)>threshold);
number_points_in_corners_in_frame_IQ = length(corner_pos_y1);
 %num_frame;
 points_Number(num_frame) =number_points_in_corners_in_frame_IQ;
end


num_frame=1;
number_of_payloads=max(info.payloadSymbolsIdxs);
payloadData=zeros(number_of_payloads,1);
payloadData(info.payloadSymbolsIdxs)=info.payloadSymbols;
stpay = (num_frame-1)*info.subCarriersCount+1;
enpay = stpay + info.subCarriersCount-1;
payload = payloadData(stpay:enpay);
if silent_mode == 0
 figure()
 plot(payload(1:number_points_to_display_in_constellation),'b*');
 title({['Payload: ',num2str(num_frame)], ['Constelation points:',num2str(number_points_to_display_in_constellation)]});
 threshold=max(abs(payload))-4*sqrt(ny1);
 [corner_pos_payload,b]=find(abs(payload)>threshold);
 number_points_in_corners_in_payload_1 = size(corner_pos_payload);
 points_Number;
 % J.-J. van de Beek, M. Sandell and P. O. Borjesson, "ML estimation of time and frequency offset in OFDM systems", IEEE Trans. Signal Process., vol. 45, no. 7, pp. 1800-1805, Jul. 19
end
inputData = struct('info',info,'rxWaveform',rxWaveform);
processedData = struct('payloadData',payloadData,'snr_array', snr_array,'e_sig_per_subcarrier', e_sig_per_subcarrier,'e_noise_per_subcarrier', e_noise_per_subcarrier,'phaseShift',phaseShift,'demodulatedData',demodulatedData);
end

