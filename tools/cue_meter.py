"""Objective cue check through Windows' per-application audio meter (IAudioMeterInformation).
Finds the Necrodancer.exe audio session on any render device (also virtual ones such as SteelSeries
Sonar, which loopback recording cannot see), plays cues at known offsets through the dev console, and
prints the left and right peak for each.

    python tools/cue_meter.py
"""
import ctypes
import os
import sys
import threading
import time
from ctypes import POINTER, byref, c_float, c_uint, c_int, c_void_p
from ctypes.wintypes import DWORD, LPWSTR, BOOL

import comtypes
from comtypes import GUID, HRESULT, COMMETHOD, IUnknown, CoCreateInstance, CLSCTX_ALL

sys.path.insert(0, os.path.dirname(__file__))
import dev  # noqa: E402


class IAudioMeterInformation(IUnknown):
    _iid_ = GUID("{C02216F6-8C67-4B5B-9D00-D008E73E0064}")
    _methods_ = [
        COMMETHOD([], HRESULT, "GetPeakValue", (["out"], POINTER(c_float), "peak")),
        COMMETHOD([], HRESULT, "GetMeteringChannelCount", (["out"], POINTER(c_uint), "count")),
        COMMETHOD([], HRESULT, "GetChannelsPeakValues", (["in"], c_uint, "count"), (["in"], POINTER(c_float), "values")),
        COMMETHOD([], HRESULT, "QueryHardwareSupport", (["out"], POINTER(DWORD), "mask")),
    ]


class IAudioSessionControl(IUnknown):
    _iid_ = GUID("{F4B1A599-7266-4319-A8CA-E70ACB11E8CD}")
    _methods_ = [
        COMMETHOD([], HRESULT, "GetState", (["out"], POINTER(c_int), "state")),
        COMMETHOD([], HRESULT, "GetDisplayName", (["out"], POINTER(LPWSTR), "name")),
        COMMETHOD([], HRESULT, "SetDisplayName", (["in"], LPWSTR), (["in"], c_void_p)),
        COMMETHOD([], HRESULT, "GetIconPath", (["out"], POINTER(LPWSTR), "path")),
        COMMETHOD([], HRESULT, "SetIconPath", (["in"], LPWSTR), (["in"], c_void_p)),
        COMMETHOD([], HRESULT, "GetGroupingParam", (["out"], POINTER(GUID), "g")),
        COMMETHOD([], HRESULT, "SetGroupingParam", (["in"], POINTER(GUID)), (["in"], c_void_p)),
        COMMETHOD([], HRESULT, "RegisterAudioSessionNotification", (["in"], c_void_p)),
        COMMETHOD([], HRESULT, "UnregisterAudioSessionNotification", (["in"], c_void_p)),
    ]


class IAudioSessionControl2(IAudioSessionControl):
    _iid_ = GUID("{BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D}")
    _methods_ = [
        COMMETHOD([], HRESULT, "GetSessionIdentifier", (["out"], POINTER(LPWSTR), "id")),
        COMMETHOD([], HRESULT, "GetSessionInstanceIdentifier", (["out"], POINTER(LPWSTR), "id")),
        COMMETHOD([], HRESULT, "GetProcessId", (["out"], POINTER(DWORD), "pid")),
        COMMETHOD([], HRESULT, "IsSystemSoundsSession"),
        COMMETHOD([], HRESULT, "SetDuckingPreference", (["in"], BOOL)),
    ]


class IAudioSessionEnumerator(IUnknown):
    _iid_ = GUID("{E2F5BB11-0570-40CA-ACDD-3AA01277DEE8}")
    _methods_ = [
        COMMETHOD([], HRESULT, "GetCount", (["out"], POINTER(c_int), "count")),
        COMMETHOD([], HRESULT, "GetSession", (["in"], c_int, "i"), (["out"], POINTER(POINTER(IAudioSessionControl)), "s")),
    ]


class IAudioSessionManager2(IUnknown):
    _iid_ = GUID("{77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F}")
    _methods_ = [
        COMMETHOD([], HRESULT, "GetAudioSessionControl", (["in"], c_void_p), (["in"], DWORD), (["out"], POINTER(c_void_p))),
        COMMETHOD([], HRESULT, "GetSimpleAudioVolume", (["in"], c_void_p), (["in"], DWORD), (["out"], POINTER(c_void_p))),
        COMMETHOD([], HRESULT, "GetSessionEnumerator", (["out"], POINTER(POINTER(IAudioSessionEnumerator)), "e")),
    ]


class IMMDevice(IUnknown):
    _iid_ = GUID("{D666063F-1587-4E43-81F1-B948E807363F}")
    _methods_ = [
        COMMETHOD([], HRESULT, "Activate", (["in"], POINTER(GUID), "iid"), (["in"], DWORD, "ctx"),
                  (["in"], c_void_p, "params"), (["out"], POINTER(c_void_p), "iface")),
        COMMETHOD([], HRESULT, "OpenPropertyStore", (["in"], DWORD), (["out"], POINTER(c_void_p))),
        COMMETHOD([], HRESULT, "GetId", (["out"], POINTER(LPWSTR), "id")),
        COMMETHOD([], HRESULT, "GetState", (["out"], POINTER(DWORD), "state")),
    ]


class IMMDeviceCollection(IUnknown):
    _iid_ = GUID("{0BD7A1BE-7A1A-44DB-8397-CC5392387B5E}")
    _methods_ = [
        COMMETHOD([], HRESULT, "GetCount", (["out"], POINTER(c_uint), "count")),
        COMMETHOD([], HRESULT, "Item", (["in"], c_uint, "i"), (["out"], POINTER(POINTER(IMMDevice)), "dev")),
    ]


class IMMDeviceEnumerator(IUnknown):
    _iid_ = GUID("{A95664D2-9614-4F35-A746-DE8DB63617E6}")
    _methods_ = [
        COMMETHOD([], HRESULT, "EnumAudioEndpoints", (["in"], c_int, "flow"), (["in"], DWORD, "mask"),
                  (["out"], POINTER(POINTER(IMMDeviceCollection)), "devs")),
    ]


CLSID_MMDeviceEnumerator = GUID("{BCDE0395-E52F-467C-8E3D-C4579291692E}")


def find_game_meters():
    comtypes.CoInitialize()
    enum = CoCreateInstance(CLSID_MMDeviceEnumerator, IMMDeviceEnumerator, CLSCTX_ALL)
    devices = enum.EnumAudioEndpoints(0, 1)  # eRender, DEVICE_STATE_ACTIVE
    meters = []
    for i in range(devices.GetCount()):
        device = devices.Item(i)
        iid = IAudioSessionManager2._iid_
        ptr = device.Activate(byref(iid), CLSCTX_ALL, None)
        manager = ctypes.cast(ptr, POINTER(IAudioSessionManager2))
        sessions = manager.GetSessionEnumerator()
        for j in range(sessions.GetCount()):
            control = sessions.GetSession(j).QueryInterface(IAudioSessionControl2)
            try:
                pid = control.GetProcessId()
            except Exception:
                continue
            name = ""
            try:
                import subprocess
                out = subprocess.run(["tasklist", "/FI", "PID eq %d" % pid, "/NH"], capture_output=True, text=True).stdout
                name = out.strip().split(" ")[0] if out.strip() else ""
            except Exception:
                pass
            if name.lower().startswith("necrodancer"):
                meters.append((device.GetId(), control.QueryInterface(IAudioMeterInformation)))
    return meters


def peaks_during(meter, action, seconds=0.7):
    count = meter.GetMeteringChannelCount()
    buf = (c_float * count)()
    best = [0.0] * count
    threading.Timer(0.15, action).start()
    end = time.time() + seconds
    while time.time() < end:
        meter.GetChannelsPeakValues(count, buf)
        for k in range(count):
            best[k] = max(best[k], buf[k])
        time.sleep(0.003)
    return best


def main():
    meters = find_game_meters()
    if not meters:
        print("No Necrodancer audio session found on any active render device.")
        return
    for device_id, meter in meters:
        print("session on", device_id, "channels", meter.GetMeteringChannelCount())
    _, meter = meters[0]
    quiet = peaks_during(meter, lambda: None)
    print("baseline   L %.3f  R %.3f" % (quiet[0], quiet[1] if len(quiet) > 1 else 0))
    for dx, dy in ((-3, 0), (-1, 0), (0, 0), (1, 0), (3, 0)):
        p = peaks_during(meter, lambda: dev.run('M.Cues.play("enemy", %d, %d, 1) return 1' % (dx, dy), 3))
        left, right = p[0], (p[1] if len(p) > 1 else 0)
        print("dx=%2d dy=%2d  L %.3f  R %.3f  balance %+.2f" % (dx, dy, left, right, (right - left) / max(1e-6, right + left)))


if __name__ == "__main__":
    main()
