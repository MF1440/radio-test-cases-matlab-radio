classdef WaveformStorage < handle
    properties
        Nfft
        SampleRate
        CyclicPrefixLengths
        SymbolLengths
        SymbolsCount
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
            obj.CyclicPrefixLengths = info.info.CyclicPrefixLengths;
            obj.SymbolLengths = info.info.SymbolLengths;
            obj.SymbolsCount = info.info.symbolsCount;
            obj.subCarriersCount = info.info.subCarriersCount;
            obj.payloadSymbols = info.info.payloadSymbols;
            obj.payloadSymbolsIdxs = info.info.payloadSymbolsIdxs;

            obj.waveformSamples = wfSamples.txWaveform;
        end
        
        function wfSamples = getSamples(obj)
            wfSamples = obj.waveformSamples;
        end
    end
end

