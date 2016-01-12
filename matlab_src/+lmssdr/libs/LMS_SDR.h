/**
@author Lime Microsystems
@brief  Interface for implementing SDR using Lime microsystems boards
*/

#ifndef LMS_SDR_INTERFACE_H
#define LMS_SDR_INTERFACE_H

#include <stdint.h>

#ifdef __cplusplus
class LMScomms;
#else
typedef void LMScomms;
#endif

#ifndef __unix__
#ifdef BUILD_DLL
    #define DLL_EXPORT __declspec(dllexport)
#else
    #define DLL_EXPORT __declspec(dllimport)
#endif
#else
#define DLL_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

/** @brief Returns stats of internal buffers
    @param RxBufSize Receiver buffer size in samples
    @param RxBufFilled Number of samples currently in the receiver buffer
    @param RxSamplingRate Approximate receiver sampling rate, calculated from incomming data
    @param TxBufSize Transmitter buffer size in samples
    @param TxBufFilled Number of samples currently in the transmitter buffer
    @param TxSamplingRate Approximate transmitter sampling rate, calculated from outgoing data
*/
DLL_EXPORT void LMS_Stats(uint32_t *RxBufSize, uint32_t *RxBufFilled, uint32_t *RxSamplingRate, uint32_t *TxBufSize, uint32_t *TxBufFilled, uint32_t *TxSamplingRate);

/**	@brief Initializes internal memory for samples buffering to hardware
    @param refClk_MHz board reference clock in MHz
    @param OperationMode samples transfering mode: 0-packets synchronized, 1-packets not synchronized
    @param trxBuffersLength Rx and Tx internal buffers size in samples
    @param channelsCount number of channels to operate
	@return 0 success, -1 failure
*/
DLL_EXPORT int LMS_Init(const float refClk_MHz, const int OperationMode, uint32_t trxBuffersLength, uint8_t channelsCount);

/** @brief Returns true if library is already initialized
*/
DLL_EXPORT bool LMS_IsInitialized();

/**	@brief Stops internal threads and frees internal buffers memory
	@return 0 success, -1 failure
*/
DLL_EXPORT int LMS_Destroy();

///@name Device connection
/**	@return object for communicating over USB port
*/
DLL_EXPORT LMScomms* LMS_GetUSBPort();

/**	@return object for communicating over COM port
*/
DLL_EXPORT LMScomms* LMS_GetCOMPort();

/** @brief Refreshes currently connected device list
    @param port Communications port to update
    @return number of devices connected
*/
DLL_EXPORT int LMS_UpdateDeviceList(LMScomms* port);

/** @brief Returns pointer to static null terminated c-string name of selected device
    @param port Communications port object
    @param deviceIndex index from communications port device list
*/
DLL_EXPORT const char* LMS_GetDeviceName(LMScomms* port, unsigned int deviceIndex);

/**	@brief Connects to selected device on given port
    @param port Communications port object
    @param deviceIndex index from communications port device list
	@return 0-success
*/
DLL_EXPORT int LMS_DeviceOpen(LMScomms* port, const uint32_t deviceIndex);

/**	@brief Connects to selected device on given port
    @param port Communications port object
    @return 0-not connected, 1-connected
*/
DLL_EXPORT int LMS_IsDeviceOpen(LMScomms* port);

/**	@brief Closes connection on given port
    @param port Communications port to close
*/
DLL_EXPORT void LMS_DeviceClose(LMScomms* port);
///@}

///@name Communications
/**	@brief Writes given data to control port
	@param port Port for communications
    @param buffer data to be written
    @param bufLen buffer length in bytes
    @return number of bytes written
*/
DLL_EXPORT uint32_t LMS_ControlWrite(LMScomms* port, const uint8_t *buffer, const uint16_t bufLen);

/**	@brief Reads given data from SPI regiter
    @param port Port for communications
    @param buffer destination buffer for data
    @param bufLen number of bytes to read
	@return number of bytes read
*/
DLL_EXPORT uint32_t LMS_ControlRead(LMScomms* port, uint8_t* buffer, const uint16_t bufLen);

/** @brief Starts thread for samples receiving
    @param burstMode receive data in bursts of contiguous samples
    @param burstLength length of single burst
    @return 0-success
*/
DLL_EXPORT int LMS_RxStart(const bool burstMode, const uint32_t burstLength);

/** @brief Stops samples receiving thread
    @return 0:success, 1:failed
*/
DLL_EXPORT int LMS_RxStop();

/** @brief Starts thread for samples transmitting
    @return 0:success, 1:failed
*/
DLL_EXPORT int LMS_TxStart();

/** @brief Stops samples transmitting thread
    @return 0-success
*/
DLL_EXPORT int LMS_TxStop();

/** @brief Adds given samples to transmitter buffer, to be sent at specified timestamp
@param buffer source array for interleaved values (IQIQIQ...), each value amplitude should be from -2048 to 2047
@param samplesCount number of samples in buffer, 1 sample = 2 bytes I + 2 bytes Q
@param channel_id destination channel
@param timestamp timestamp when the first sample in buffer should be transmitted (used only in synchronized operating mode)
@param timeout_ms time amount in milliseconds to try adding samples
@return number of samples written
*/
DLL_EXPORT uint32_t LMS_TRxWrite(const int16_t **buffer, const uint32_t samplesCount, const uint32_t channel_id, const uint64_t timestamp, const uint32_t timeout_ms);

/** @brief Adds given samples to transmitter buffer, to be sent at specified timestamp
@param buffer source array for interleaved values (IQIQIQ...), each value amplitude should be from -2048 to 2047,
    channels data should be concatenated
@param samplesCount number of samples in buffer, 1 sample = 2 bytes I + 2 bytes Q
@param channel_id destination channel
@param timestamp timestamp when the first sample in buffer should be transmitted (used only in synchronized operating mode)
@param timeout_ms time amount in milliseconds to try adding samples
@return number of samples written
*/
DLL_EXPORT uint32_t LMS_TRxWrite_matlab(const int16_t *buffer, const uint32_t samplesCount, const uint32_t channel_id, const uint64_t timestamp, const uint32_t timeout_ms);

/** @brief Reads samples from receiver buffer
@param buffer destination array for interleaved values (IQIQIQ...), must be big enough to store requested number of samples, each value amplitude will be from -2048 to 2047
@param samplesCount number of samples to read, 1 sample = 2 bytes I + 2 bytes Q
@param channel_id source channel
@param timestamp returns timestamp of the first sample in the buffer (used only in synchronized operating mode)
@param timeout_ms time amount in milliseconds to try reading samples
@return number of samples read
*/
DLL_EXPORT uint32_t LMS_TRxRead(int16_t **buffer, const uint32_t samplesCount, const uint32_t channel_id, uint64_t *timestamp, const uint32_t timeout_ms);

/** @brief Reads samples from receiver buffer
@param buffer destination array for interleaved values (IQIQIQ...), must be big enough to store requested number of samples*channels, each value amplitude will be from -2048 to 2047,
    channels data is returned concatenated
@param samplesCount number of samples to read, 1 sample = 2 bytes I + 2 bytes Q
@param channel_id source channel
@param timestamp returns timestamp of the first sample in the buffer (used only in synchronized operating mode)
@param timeout_ms time amount in milliseconds to try reading samples
@return number of samples read
*/
DLL_EXPORT uint32_t LMS_TRxRead_matlab(int16_t *buffer, const uint32_t samplesCount, const uint32_t channel_id, uint64_t *timestamp, const uint32_t timeout_ms);

/** @brief Configures Stream board FPGA clocks
    @param serPort Communications port to send data
    @param fOutTx_MHz transmitter frequency in MHz
    @param fOutRx_MHz receiver frequency in MHz
    @param phaseShift_deg IQ phase shift in degrees
    @return 0-success, other-failure
*/
DLL_EXPORT int32_t LMS_BRDConfigurePLL(LMScomms *serPort, const float fOutTx_MHz, const float fOutRx_MHz, const float phaseShift_deg);

/** @brief Sets Receiver center frequency
    @param serPort Communications port to send data
    @param freq_MHz desired frequency in MHz
    @return 0:success, other:failure
*/
DLL_EXPORT int32_t LMS_SetCenterFrequencyRx(LMScomms *serPort, const float freq_MHz);

/** @brief Sets Transmitter center frequency
@param serPort Communications port to send data
@param freq_MHz desired frequency in MHz
@return 0:success, other:failure
*/
DLL_EXPORT int32_t LMS_SetCenterFrequencyTx(LMScomms *serPort, const float freq_MHz);

/** @brief Loads configuration file registers to chip
    @param filename file name or full path to configuration file
    @return 0:success, other:failure
*/
DLL_EXPORT int32_t LMS_LoadConfigurationFile(const char* filename);
///@}

#ifdef __cplusplus
} //extern "C"
#endif

#endif //LMS_SDR_INTERFACE_H
