classdef WaveformStorage < handle
    properties
        % Тут в соответствии с Code Guideline надо бы Nfft сделать nFFT или
        % fftCount, но это будет вносить путаницу из-за 5G toolbox
        Nfft
        sampleRate
        cyclicPrefixLengths
        symbolLengths
        symbolsCount
        subCarriersCount
        payloadSymbols
        payloadSymbolsIdxs

        waveformSamples
    end
    
    methods
        function obj = WaveformStorage(infoPath, waveformPath)
            info = load(infoPath);
            wfSamples = load(waveformPath, 'txWaveform');
            
            obj.Nfft = info.info.Nfft;
            obj.cyclicPrefixLengths = info.info.CyclicPrefixLengths;
            obj.symbolLengths = info.info.SymbolLengths;
            obj.symbolsCount = info.info.symbolsCount;
            obj.subCarriersCount = info.info.subCarriersCount;
            obj.payloadSymbols = info.info.payloadSymbols;
            obj.payloadSymbolsIdxs = info.info.payloadSymbolsIdxs;
            obj.sampleRate = info.info.SampleRate;

            obj.waveformSamples = wfSamples.txWaveform;
        end
        
        function wfSamples = getSamples(obj)
            wfSamples = obj.waveformSamples;
        end

        function sr = getSampleRate(obj)
            sr = obj.sampleRate;
        end

        function pls = getPayloadSymbols(obj)
            pls = obj.payloadSymbols;
        end

        function n = getNfft(obj)
            n = obj.Nfft;
        end

        function n = getSubCarriersCount(obj)
            n = obj.subCarriersCount;
        end
    end
end
