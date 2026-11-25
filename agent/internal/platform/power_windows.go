//go:build windows

package platform

import (
	"context"
	"errors"
	"fmt"
	"runtime"
	"syscall"
	"unsafe"
)

func (*Native) MediaState(context.Context) (MediaState, error) {
	return MediaState{Status: "unavailable", Playback: "unavailable", Error: "integração GSMTC do Windows ainda não implementada"}, nil
}

func (*Native) ExecuteMedia(context.Context, string, *float64) error { return ErrNotImplemented }

var (
	user32Power               = syscall.NewLazyDLL("user32.dll")
	procLockWorkStation       = user32Power.NewProc("LockWorkStation")
	procExitWindowsEx         = user32Power.NewProc("ExitWindowsEx")
	advapiPower               = syscall.NewLazyDLL("advapi32.dll")
	procOpenProcessToken      = advapiPower.NewProc("OpenProcessToken")
	procLookupPrivilegeValue  = advapiPower.NewProc("LookupPrivilegeValueW")
	procAdjustTokenPrivileges = advapiPower.NewProc("AdjustTokenPrivileges")
	kernel32Power             = syscall.NewLazyDLL("kernel32.dll")
	procCloseHandlePower      = kernel32Power.NewProc("CloseHandle")
)

type luid struct {
	LowPart  uint32
	HighPart int32
}

type luidAndAttributes struct {
	LUID       luid
	Attributes uint32
}

type tokenPrivileges struct {
	PrivilegeCount uint32
	Privileges     [1]luidAndAttributes
}

func (*Native) ExecutePower(ctx context.Context, action string) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	switch action {
	case "lock":
		ok, _, callErr := procLockWorkStation.Call()
		if ok == 0 {
			return fmt.Errorf("LockWorkStation: %w", callError(callErr))
		}
		return nil
	case "shutdown", "restart":
		return windowsShutdown(action)
	default:
		return fmt.Errorf("ação de energia não suportada no Windows: %s", action)
	}
}

func windowsShutdown(action string) error {
	var token syscall.Token
	const tokenAdjustPrivileges = 0x0020
	const tokenQuery = 0x0008
	process, err := syscall.GetCurrentProcess()
	if err != nil {
		return fmt.Errorf("obter processo atual: %w", err)
	}
	ok, _, callErr := procOpenProcessToken.Call(uintptr(process), tokenAdjustPrivileges|tokenQuery, uintptr(unsafe.Pointer(&token)))
	if ok == 0 {
		return fmt.Errorf("abrir token de segurança do processo: %w", callError(callErr))
	}
	defer procCloseHandlePower.Call(uintptr(token))

	name, err := syscall.UTF16PtrFromString("SeShutdownPrivilege")
	if err != nil {
		return err
	}
	var privileges tokenPrivileges
	privileges.PrivilegeCount = 1
	privileges.Privileges[0].Attributes = 0x00000002 // SE_PRIVILEGE_ENABLED
	ok, _, callErr = procLookupPrivilegeValue.Call(0, uintptr(unsafe.Pointer(name)), uintptr(unsafe.Pointer(&privileges.Privileges[0].LUID)))
	if ok == 0 {
		return fmt.Errorf("localizar privilégio de desligamento: %w", callError(callErr))
	}
	ok, _, callErr = procAdjustTokenPrivileges.Call(uintptr(token), 0, uintptr(unsafe.Pointer(&privileges)), 0, 0, 0)
	if ok == 0 {
		return fmt.Errorf("habilitar privilégio de desligamento: %w", callError(callErr))
	}
	if errno, ok := callErr.(syscall.Errno); ok && errno == 1300 { // ERROR_NOT_ALL_ASSIGNED
		return errors.New("a conta atual não possui o privilégio de desligar o sistema")
	}
	runtime.KeepAlive(name)
	runtime.KeepAlive(&privileges)

	const ewxShutdown = 0x00000001
	const ewxReboot = 0x00000002
	const plannedApplicationMaintenance = 0x80040000
	flags := uintptr(ewxShutdown)
	if action == "restart" {
		flags = ewxReboot
	}
	ok, _, callErr = procExitWindowsEx.Call(flags, plannedApplicationMaintenance)
	if ok == 0 {
		return fmt.Errorf("iniciar %s: %w", action, callError(callErr))
	}
	return nil
}

func callError(err error) error {
	if err == nil || err == syscall.Errno(0) {
		return syscall.EINVAL
	}
	return err
}
