//go:build windows

package platform

import (
	"context"
	"crypto/sha256"
	"fmt"
	"math"
	"net/http"
	"runtime"
	"syscall"
	"time"
	"unsafe"

	"github.com/go-ole/go-ole"
	"github.com/saltosystems/winrt-go/windows/foundation"
	"github.com/saltosystems/winrt-go/windows/media/control"
	"github.com/saltosystems/winrt-go/windows/storage/streams"
)

var (
	combaseMedia            = syscall.NewLazyDLL("combase.dll")
	procRoInitialize        = combaseMedia.NewProc("RoInitialize")
	procRoUninitialize      = combaseMedia.NewProc("RoUninitialize")
	clsidMMDeviceEnumerator = ole.NewGUID("{BCDE0395-E52F-467C-8E3D-C4579291692E}")
	iidMMDeviceEnumerator   = ole.NewGUID("{A95664D2-9614-4F35-A746-DE8DB63617E6}")
	iidAudioEndpointVolume  = ole.NewGUID("{5CDF2C82-841E-4546-9722-0CF74078229A}")
)

// Core Audio COM interfaces. Only the vtable slots used by this adapter are
// declared; preceding slots are retained so the ABI indices remain correct.
type mmDeviceEnumerator struct{ ole.IUnknown }
type mmDeviceEnumeratorVtbl struct {
	ole.IUnknownVtbl
	EnumAudioEndpoints, GetDefaultAudioEndpoint, GetDevice uintptr
}

type mmDevice struct{ ole.IUnknown }
type mmDeviceVtbl struct {
	ole.IUnknownVtbl
	Activate, OpenPropertyStore, GetId, GetState uintptr
}

type audioEndpointVolume struct{ ole.IUnknown }
type audioEndpointVolumeVtbl struct {
	ole.IUnknownVtbl
	RegisterControlChangeNotify, UnregisterControlChangeNotify, GetChannelCount                             uintptr
	SetMasterVolumeLevel, GetMasterVolumeLevel, SetMasterVolumeLevelScalar, GetMasterVolumeLevelScalar      uintptr
	SetChannelVolumeLevel, GetChannelVolumeLevel, SetChannelVolumeLevelScalar, GetChannelVolumeLevelScalar  uintptr
	SetMute, GetMute, GetVolumeStepInfo, VolumeStepUp, VolumeStepDown, QueryHardwareSupport, GetVolumeRange uintptr
}

func (v *mmDeviceEnumerator) mediaVtbl() *mmDeviceEnumeratorVtbl {
	return (*mmDeviceEnumeratorVtbl)(unsafe.Pointer(v.RawVTable))
}
func (v *mmDevice) mediaVtbl() *mmDeviceVtbl { return (*mmDeviceVtbl)(unsafe.Pointer(v.RawVTable)) }
func (v *audioEndpointVolume) mediaVtbl() *audioEndpointVolumeVtbl {
	return (*audioEndpointVolumeVtbl)(unsafe.Pointer(v.RawVTable))
}

func (n *Native) MediaState(ctx context.Context) (MediaState, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	var state MediaState
	err := withWindowsRuntime(func() error {
		volume, muted, err := getWindowsMasterVolume()
		if err != nil {
			return err
		}
		state = MediaState{Status: "ok", Playback: "no_media", Volume: volume, Muted: muted}
		manager, err := requestMediaSessionManager(ctx)
		if err != nil {
			return fmt.Errorf("consultar sessão de mídia do Windows: %w", err)
		}
		defer manager.Release()
		session, err := manager.GetCurrentSession()
		if err != nil {
			return fmt.Errorf("obter sessão ativa do Windows: %w", err)
		}
		if session == nil {
			state.Status = "no_media"
			return nil
		}
		defer session.Release()
		source, err := session.GetSourceAppUserModelId()
		if err != nil {
			return fmt.Errorf("identificar aplicativo da sessão de mídia: %w", err)
		}
		playbackInfo, err := session.GetPlaybackInfo()
		if err != nil {
			return fmt.Errorf("consultar reprodução da sessão de mídia: %w", err)
		}
		defer playbackInfo.Release()
		playback, err := playbackInfo.GetPlaybackStatus()
		if err != nil {
			return fmt.Errorf("consultar status da sessão de mídia: %w", err)
		}
		state.Player = source
		switch playback {
		case control.GlobalSystemMediaTransportControlsSessionPlaybackStatusPlaying:
			state.Playback = "playing"
		case control.GlobalSystemMediaTransportControlsSessionPlaybackStatusPaused,
			control.GlobalSystemMediaTransportControlsSessionPlaybackStatusOpened,
			control.GlobalSystemMediaTransportControlsSessionPlaybackStatusChanging:
			state.Playback = "paused"
		case control.GlobalSystemMediaTransportControlsSessionPlaybackStatusClosed,
			control.GlobalSystemMediaTransportControlsSessionPlaybackStatusStopped:
			state.Status = "no_media"
			state.Playback = "no_media"
			state.Player = ""
			return nil
		default:
			state.Playback = "paused"
		}
		propertiesOp, err := session.TryGetMediaPropertiesAsync()
		if err != nil {
			return fmt.Errorf("solicitar metadados da sessão de mídia: %w", err)
		}
		result, err := awaitWindowsOperation(ctx, propertiesOp)
		if err != nil {
			return fmt.Errorf("ler metadados da sessão de mídia: %w", err)
		}
		properties := (*control.GlobalSystemMediaTransportControlsSessionMediaProperties)(result)
		if properties != nil {
			defer properties.Release()
			state.Title, _ = properties.GetTitle()
			state.Artist, _ = properties.GetArtist()
			artworkKey := state.Player + "\x00" + state.Title + "\x00" + state.Artist
			n.mediaMu.Lock()
			cached := n.mediaArtworkKey == artworkKey
			if cached {
				state.Artwork = append([]byte(nil), n.mediaArtwork...)
				state.ArtworkMIME = n.mediaArtworkMIME
			}
			n.mediaMu.Unlock()
			if !cached {
				var artwork []byte
				var mimeType string
				if thumbnail, thumbErr := properties.GetThumbnail(); thumbErr == nil && thumbnail != nil {
					artwork, mimeType, _ = readWindowsThumbnail(ctx, thumbnail)
					thumbnail.Release()
				}
				n.mediaMu.Lock()
				n.mediaArtworkKey = artworkKey
				n.mediaArtwork = append(n.mediaArtwork[:0], artwork...)
				n.mediaArtworkMIME = mimeType
				state.Artwork = append([]byte(nil), artwork...)
				state.ArtworkMIME = mimeType
				n.mediaMu.Unlock()
			}
			if len(state.Artwork) > 0 {
				state.ArtworkID = fmt.Sprintf("%x", sha256.Sum256(state.Artwork))
			}
		}
		if timeline, timelineErr := session.GetTimelineProperties(); timelineErr == nil && timeline != nil {
			defer timeline.Release()
			position, positionErr := timeline.GetPosition()
			start, startErr := timeline.GetStartTime()
			end, endErr := timeline.GetEndTime()
			if positionErr == nil {
				state.PositionMS = position.Duration / 10000
			}
			if startErr == nil && endErr == nil && end.Duration >= start.Duration {
				state.DurationMS = (end.Duration - start.Duration) / 10000
			}
		}
		return nil
	})
	return state, err
}

func (*Native) ExecuteMedia(ctx context.Context, action string, value *float64) error {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := ctx.Err(); err != nil {
		return err
	}
	if action == "set_volume" {
		if value == nil || math.IsNaN(*value) || math.IsInf(*value, 0) || *value < 0 || *value > 100 {
			return fmt.Errorf("set_volume exige valor entre 0 e 100")
		}
		return withWindowsRuntime(func() error { return setWindowsMasterVolume(float32(*value / 100)) })
	}
	if action == "toggle_mute" {
		return withWindowsRuntime(func() error {
			_, muted, err := getWindowsMasterVolume()
			if err != nil {
				return err
			}
			return setWindowsMuted(!muted)
		})
	}
	if action != "play_pause" && action != "next" && action != "previous" && action != "seek" {
		return fmt.Errorf("ação de mídia desconhecida: %s", action)
	}
	if action == "seek" && (value == nil || math.IsNaN(*value) || math.IsInf(*value, 0) || *value < 0 || *value > 86400000) {
		return fmt.Errorf("seek exige posição entre 0 e 86400000 ms")
	}
	return withWindowsRuntime(func() error {
		manager, err := requestMediaSessionManager(ctx)
		if err != nil {
			return fmt.Errorf("consultar sessão de mídia do Windows: %w", err)
		}
		defer manager.Release()
		session, err := manager.GetCurrentSession()
		if err != nil {
			return fmt.Errorf("obter sessão ativa do Windows: %w", err)
		}
		if session == nil {
			return ErrNoMedia
		}
		defer session.Release()
		var operation *foundation.IAsyncOperation
		switch action {
		case "play_pause":
			operation, err = session.TryTogglePlayPauseAsync()
		case "next":
			operation, err = session.TrySkipNextAsync()
		case "previous":
			operation, err = session.TrySkipPreviousAsync()
		case "seek":
			operation, err = session.TryChangePlaybackPositionAsync(int64(*value * 10000))
		}
		if err != nil {
			return fmt.Errorf("enviar comando %s à sessão de mídia: %w", action, err)
		}
		accepted, err := awaitWindowsBooleanOperation(ctx, operation)
		if err != nil {
			return fmt.Errorf("executar comando %s na sessão de mídia: %w", action, err)
		}
		if !accepted {
			return fmt.Errorf("o Windows não aceitou o comando %s", action)
		}
		return nil
	})
}

func withWindowsRuntime(fn func() error) error {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	hr, _, _ := procRoInitialize.Call(1) // RO_INIT_MULTITHREADED
	if int32(hr) < 0 {
		return fmt.Errorf("inicializar Windows Runtime: HRESULT 0x%08X", uint32(hr))
	}
	defer procRoUninitialize.Call()
	return fn()
}

func requestMediaSessionManager(ctx context.Context) (*control.GlobalSystemMediaTransportControlsSessionManager, error) {
	operation, err := control.GlobalSystemMediaTransportControlsSessionManagerRequestAsync()
	if err != nil {
		return nil, err
	}
	result, err := awaitWindowsOperation(ctx, operation)
	if err != nil {
		return nil, err
	}
	if result == nil {
		return nil, fmt.Errorf("o Windows não retornou o gerenciador de mídia")
	}
	return (*control.GlobalSystemMediaTransportControlsSessionManager)(result), nil
}

func awaitWindowsOperation(ctx context.Context, operation *foundation.IAsyncOperation) (unsafe.Pointer, error) {
	if operation == nil {
		return nil, fmt.Errorf("operação WinRT vazia")
	}
	defer operation.Release()
	if err := waitWindowsOperation(ctx, operation); err != nil {
		return nil, err
	}
	return operation.GetResults()
}

// readWindowsThumbnail consumes the WinRT random access stream into a bounded
// buffer. Thumbnail streams are supplied by the active media session.
func readWindowsThumbnail(ctx context.Context, reference *streams.IRandomAccessStreamReference) ([]byte, string, error) {
	openOperation, err := reference.OpenReadAsync()
	if err != nil {
		return nil, "", err
	}
	result, err := awaitWindowsOperation(ctx, openOperation)
	if err != nil {
		return nil, "", err
	}
	stream := (*ole.IInspectable)(result)
	defer stream.Release()
	streamVtbl := (*randomAccessStreamVtbl)(unsafe.Pointer(stream.RawVTable))
	var size uint64
	hr, _, _ := syscall.SyscallN(streamVtbl.GetSize, uintptr(unsafe.Pointer(stream)), uintptr(unsafe.Pointer(&size)))
	if hr != 0 {
		return nil, "", ole.NewError(hr)
	}
	if size == 0 || size > 2*1024*1024 {
		return nil, "", fmt.Errorf("thumbnail fora do limite de tamanho")
	}

	factoryObject, err := ole.RoGetActivationFactory("Windows.Storage.Streams.DataReader", ole.NewGUID("d7527847-57da-4e15-914c-06806699a098"))
	if err != nil {
		return nil, "", err
	}
	factory := (*dataReaderStatics)(unsafe.Pointer(factoryObject))
	var reader *streams.DataReader
	hr, _, _ = syscall.SyscallN(factory.VTable().CreateDataReader, uintptr(unsafe.Pointer(factory)), uintptr(unsafe.Pointer(stream)), uintptr(unsafe.Pointer(&reader)))
	factory.Release()
	if hr != 0 {
		return nil, "", ole.NewError(hr)
	}
	defer reader.Release()
	readerInterface := reader.MustQueryInterface(ole.NewGUID(streams.GUIDIDataReader))
	defer readerInterface.Release()
	dataReader := (*streams.IDataReader)(unsafe.Pointer(readerInterface))
	var operation *foundation.IAsyncOperation
	hr, _, _ = syscall.SyscallN(dataReader.VTable().LoadAsync, uintptr(unsafe.Pointer(dataReader)), uintptr(uint32(size)), uintptr(unsafe.Pointer(&operation)))
	if hr != 0 {
		return nil, "", ole.NewError(hr)
	}
	if err := waitWindowsOperation(ctx, operation); err != nil {
		operation.Release()
		return nil, "", err
	}
	var loaded uint32
	hr, _, _ = syscall.SyscallN(operation.VTable().GetResults, uintptr(unsafe.Pointer(operation)), uintptr(unsafe.Pointer(&loaded)))
	operation.Release()
	if hr != 0 {
		return nil, "", ole.NewError(hr)
	}
	if loaded == 0 || loaded > 2*1024*1024 {
		return nil, "", fmt.Errorf("thumbnail vazio ou grande demais")
	}
	data, err := reader.ReadBytes(loaded)
	if err != nil {
		return nil, "", err
	}
	return data, http.DetectContentType(data), nil
}

type randomAccessStreamVtbl struct {
	ole.IInspectableVtbl
	ReadAsync, WriteAsync, FlushAsync, Seek, GetPosition, SetSize, GetSize uintptr
}

type dataReaderStatics struct{ ole.IInspectable }
type dataReaderStaticsVtbl struct {
	ole.IInspectableVtbl
	CreateDataReader uintptr
}

func (v *dataReaderStatics) VTable() *dataReaderStaticsVtbl {
	return (*dataReaderStaticsVtbl)(unsafe.Pointer(v.RawVTable))
}

func awaitWindowsBooleanOperation(ctx context.Context, operation *foundation.IAsyncOperation) (bool, error) {
	if operation == nil {
		return false, fmt.Errorf("operação WinRT vazia")
	}
	defer operation.Release()
	if err := waitWindowsOperation(ctx, operation); err != nil {
		return false, err
	}
	var accepted uint8
	hr, _, _ := syscall.SyscallN(operation.VTable().GetResults,
		uintptr(unsafe.Pointer(operation)), uintptr(unsafe.Pointer(&accepted)))
	if hr != 0 {
		return false, ole.NewError(hr)
	}
	return accepted != 0, nil
}

func waitWindowsOperation(ctx context.Context, operation *foundation.IAsyncOperation) error {
	infoDispatch, err := operation.QueryInterface(ole.NewGUID(foundation.GUIDIAsyncInfo))
	if err != nil {
		return err
	}
	info := (*foundation.IAsyncInfo)(unsafe.Pointer(infoDispatch))
	defer infoDispatch.Release()
	ticker := time.NewTicker(10 * time.Millisecond)
	defer ticker.Stop()
	for {
		status, err := info.GetStatus()
		if err != nil {
			return err
		}
		switch status {
		case foundation.AsyncStatusCompleted:
			return nil
		case foundation.AsyncStatusError:
			code, codeErr := info.GetErrorCode()
			if codeErr != nil {
				return codeErr
			}
			return fmt.Errorf("operação WinRT falhou: HRESULT 0x%08X", uint32(code.Value))
		case foundation.AsyncStatusCanceled:
			return fmt.Errorf("operação WinRT cancelada")
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
		}
	}
}

func audioEndpoint() (*audioEndpointVolume, error) {
	unknown, err := ole.CreateInstance(clsidMMDeviceEnumerator, ole.IID_IUnknown)
	if err != nil {
		return nil, fmt.Errorf("criar enumerador de áudio: %w", err)
	}
	defer unknown.Release()
	dispatch, err := unknown.QueryInterface(iidMMDeviceEnumerator)
	if err != nil {
		return nil, fmt.Errorf("obter enumerador de áudio: %w", err)
	}
	enumerator := (*mmDeviceEnumerator)(unsafe.Pointer(dispatch))
	defer dispatch.Release()
	var device *mmDevice
	hr, _, _ := syscall.SyscallN(enumerator.mediaVtbl().GetDefaultAudioEndpoint,
		uintptr(unsafe.Pointer(enumerator)), 0, 0, uintptr(unsafe.Pointer(&device))) // eRender, eConsole
	if hr != 0 {
		return nil, ole.NewError(hr)
	}
	if device == nil {
		return nil, fmt.Errorf("Windows não retornou o dispositivo de áudio padrão")
	}
	defer device.Release()
	var endpoint *audioEndpointVolume
	hr, _, _ = syscall.SyscallN(device.mediaVtbl().Activate,
		uintptr(unsafe.Pointer(device)), uintptr(unsafe.Pointer(iidAudioEndpointVolume)), 23, 0, uintptr(unsafe.Pointer(&endpoint))) // CLSCTX_ALL
	if hr != 0 {
		return nil, ole.NewError(hr)
	}
	if endpoint == nil {
		return nil, fmt.Errorf("Windows não retornou o controle de volume master")
	}
	return endpoint, nil
}

func getWindowsMasterVolume() (int, bool, error) {
	endpoint, err := audioEndpoint()
	if err != nil {
		return 0, false, fmt.Errorf("consultar volume master do Windows: %w", err)
	}
	defer endpoint.Release()
	var scalar float32
	hr, _, _ := syscall.SyscallN(endpoint.mediaVtbl().GetMasterVolumeLevelScalar, uintptr(unsafe.Pointer(endpoint)), uintptr(unsafe.Pointer(&scalar)))
	if hr != 0 {
		return 0, false, fmt.Errorf("ler volume master: %w", ole.NewError(hr))
	}
	var muted int32
	hr, _, _ = syscall.SyscallN(endpoint.mediaVtbl().GetMute, uintptr(unsafe.Pointer(endpoint)), uintptr(unsafe.Pointer(&muted)))
	if hr != 0 {
		return 0, false, fmt.Errorf("ler estado de mudo: %w", ole.NewError(hr))
	}
	return int(math.Round(float64(scalar) * 100)), muted != 0, nil
}

func setWindowsMasterVolume(value float32) error {
	endpoint, err := audioEndpoint()
	if err != nil {
		return fmt.Errorf("alterar volume master do Windows: %w", err)
	}
	defer endpoint.Release()
	var current, steps uint32
	hr, _, _ := syscall.SyscallN(endpoint.mediaVtbl().GetVolumeStepInfo,
		uintptr(unsafe.Pointer(endpoint)), uintptr(unsafe.Pointer(&current)), uintptr(unsafe.Pointer(&steps)))
	if hr != 0 {
		return fmt.Errorf("consultar passos de volume master: %w", ole.NewError(hr))
	}
	if steps == 0 {
		return fmt.Errorf("dispositivo de áudio não informa passos de volume")
	}
	target := uint32(math.Round(float64(value) * float64(steps)))
	for current < target {
		hr, _, _ = syscall.SyscallN(endpoint.mediaVtbl().VolumeStepUp, uintptr(unsafe.Pointer(endpoint)), 0)
		if hr != 0 {
			return fmt.Errorf("aumentar volume master: %w", ole.NewError(hr))
		}
		current++
	}
	for current > target {
		hr, _, _ = syscall.SyscallN(endpoint.mediaVtbl().VolumeStepDown, uintptr(unsafe.Pointer(endpoint)), 0)
		if hr != 0 {
			return fmt.Errorf("reduzir volume master: %w", ole.NewError(hr))
		}
		current--
	}
	return nil
}

func setWindowsMuted(muted bool) error {
	endpoint, err := audioEndpoint()
	if err != nil {
		return fmt.Errorf("alterar mudo do Windows: %w", err)
	}
	defer endpoint.Release()
	var value uintptr
	if muted {
		value = 1
	}
	hr, _, _ := syscall.SyscallN(endpoint.mediaVtbl().SetMute, uintptr(unsafe.Pointer(endpoint)), value, 0)
	if hr != 0 {
		return fmt.Errorf("definir estado de mudo: %w", ole.NewError(hr))
	}
	return nil
}
