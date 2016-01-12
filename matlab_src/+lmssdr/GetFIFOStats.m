function [RxBufSize, RxBufFilled, RxRate, TxBufSize, TxBufFilled, TxRate] = GetFIFOStats
%Returns approximate sampling rate and status of the internal FIFO
% RxBufSize - total size of Rx FIFO
% RxBufFilled - currently filled items count
% RxRate - approximate Rx sampling rate
% TxBufSize - total size of Tx FIFO
% TxBufFilled - currently filled items count of Tx FIFO
% TxRate - approximate Tx sampling rate

RxRate = uint32(0);
RxRatePtr = libpointer('uint32Ptr', RxRate);
RxBufSize = uint32(0);
RxBufSizePtr = libpointer('uint32Ptr', RxBufSize);
RxBufFilled = uint32(0);
RxBufFilledPtr = libpointer('uint32Ptr', RxBufFilled);
TxRate = uint32(0);
TxRatePtr = libpointer('uint32Ptr', TxRate);
TxBufSize = uint32(0);
TxBufSizePtr = libpointer('uint32Ptr', TxBufSize);
TxBufFilled = uint32(0);
TxBufFilledPtr = libpointer('uint32Ptr', TxBufFilled);

[RxBufSize, RxBufFilled, RxRate, TxBufSize, TxBufFilled, TxRate] = calllib(lmssdr.GetLibraryName(),'LMS_Stats', RxBufSizePtr, RxBufFilledPtr, RxRatePtr, TxBufSizePtr, TxBufFilledPtr, TxRatePtr);
end