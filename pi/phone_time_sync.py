#!/usr/bin/env python3
"""
Sets the Pi's clock from the iPhone over Bluetooth, for when there is no internet.

iPhones share their time with paired accessories through the Bluetooth LE
"Current Time" service (0x1805, characteristic 0x2A2B). This script:
  1. advertises the Pi so it shows up in iPhone Settings > Bluetooth,
  2. accepts pairing, but only until one phone is paired,
  3. each time the paired phone connects, reads its time and sets the clock,
     unless the clock is already set from the internet.
Runs as root (setting the clock needs it). Log: journalctl -u phone-time-sync
"""

import subprocess
import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib

BUS = 'org.bluez'
ADAPTER = '/org/bluez/hci0'
CURRENT_TIME = '00002a2b-0000-1000-8000-00805f9b34fb'
# Apple Notification Center Service: asking for it makes iPhones list the Pi in Settings
ANCS = '7905f431-b5ce-4e99-a40f-4b1e122d00d0'
PROPS = 'org.freedesktop.DBus.Properties'


def decode_current_time(value):
    """0x2A2B bytes -> 'YYYY-MM-DD HH:MM:SS' (the phone's local time)."""
    b = bytes(value)
    year = b[0] | (b[1] << 8)
    return f'{year:04d}-{b[2]:02d}-{b[3]:02d} {b[4]:02d}:{b[5]:02d}:{b[6]:02d}'


def internet_time_ok():
    out = subprocess.run(['timedatectl', 'show', '-p', 'NTPSynchronized', '--value'],
                         capture_output=True, text=True).stdout.strip()
    return out == 'yes'


class Advertisement(dbus.service.Object):
    PATH = '/riact/advert0'

    def __init__(self, bus):
        super().__init__(bus, self.PATH)

    @dbus.service.method(PROPS, in_signature='s', out_signature='a{sv}')
    def GetAll(self, interface):
        return {'Type': 'peripheral',
                'LocalName': dbus.String(GLib.get_host_name()),
                'SolicitUUIDs': dbus.Array([ANCS], signature='s'),
                'Discoverable': dbus.Boolean(True)}

    @dbus.service.method('org.bluez.LEAdvertisement1')
    def Release(self):
        pass


class Agent(dbus.service.Object):
    """Answers "yes" to pairing (there's no screen to type a code), but only for the first phone."""
    PATH = '/riact/agent'

    def __init__(self, bus, sync):
        super().__init__(bus, self.PATH)
        self.sync = sync

    def _allow(self):
        if self.sync.paired_devices():
            raise dbus.DBusException('A phone is already paired', name='org.bluez.Error.Rejected')

    @dbus.service.method('org.bluez.Agent1', in_signature='ou')
    def RequestConfirmation(self, device, passkey):
        self._allow()

    @dbus.service.method('org.bluez.Agent1', in_signature='o')
    def RequestAuthorization(self, device):
        self._allow()

    @dbus.service.method('org.bluez.Agent1', in_signature='os')
    def AuthorizeService(self, device, uuid):
        pass

    @dbus.service.method('org.bluez.Agent1')
    def Cancel(self):
        pass

    @dbus.service.method('org.bluez.Agent1')
    def Release(self):
        pass


class PhoneTimeSync:
    def __init__(self):
        self.bus = dbus.SystemBus()
        self.agent = Agent(self.bus, self)
        self.advert = Advertisement(self.bus)

    def objects(self):
        manager = dbus.Interface(self.bus.get_object(BUS, '/'), 'org.freedesktop.DBus.ObjectManager')
        return manager.GetManagedObjects()

    def paired_devices(self):
        return [p for p, i in self.objects().items()
                if i.get('org.bluez.Device1', {}).get('Paired')]

    def start(self):
        adapter = self.bus.get_object(BUS, ADAPTER)
        adapter.Set('org.bluez.Adapter1', 'Powered', True, dbus_interface=PROPS)
        agents = dbus.Interface(self.bus.get_object(BUS, '/org/bluez'), 'org.bluez.AgentManager1')
        agents.RegisterAgent(Agent.PATH, 'NoInputNoOutput')
        agents.RequestDefaultAgent(Agent.PATH)
        dbus.Interface(adapter, 'org.bluez.LEAdvertisingManager1').RegisterAdvertisement(
            Advertisement.PATH, {},
            reply_handler=lambda: print('Advertising: the Pi shows up in iPhone Settings > Bluetooth', flush=True),
            error_handler=lambda e: print(f'Could not advertise: {e}', flush=True))
        adapter.Set('org.bluez.Adapter1', 'Pairable', not self.paired_devices(), dbus_interface=PROPS)
        # A phone connecting (and finishing its service list) is the cue to read its time
        self.bus.add_signal_receiver(self.on_change, dbus_interface=PROPS,
                                     signal_name='PropertiesChanged', path_keyword='path')
        self.read_all()

    def on_change(self, interface, changed, invalidated, path):
        if interface == 'org.bluez.Device1' and changed.get('ServicesResolved'):
            GLib.timeout_add_seconds(1, self.read_all)
        if interface == 'org.bluez.Device1' and changed.get('Paired'):
            print(f'Paired with {path}', flush=True)
            self.bus.get_object(BUS, ADAPTER).Set('org.bluez.Adapter1', 'Pairable', False,
                                                  dbus_interface=PROPS)
            GLib.timeout_add_seconds(1, self.read_all)

    def read_all(self):
        paired = self.paired_devices()
        for path, ifaces in self.objects().items():
            char = ifaces.get('org.bluez.GattCharacteristic1')
            if not char or char.get('UUID') != CURRENT_TIME:
                continue
            if not any(path.startswith(d + '/') for d in paired):
                continue
            try:
                value = dbus.Interface(self.bus.get_object(BUS, path),
                                       'org.bluez.GattCharacteristic1').ReadValue({})
                self.set_clock(decode_current_time(value))
            except Exception as e:
                print(f'Could not read the time from {path}: {e}', flush=True)
        return False  # run once when called from a GLib timer

    def set_clock(self, when):
        if internet_time_ok():
            print(f'iPhone time is {when}; the clock is already set from the internet', flush=True)
            return
        subprocess.run(['date', '-s', when], check=True, capture_output=True)
        print(f'Clock set from iPhone: {when}', flush=True)


if __name__ == '__main__':
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    PhoneTimeSync().start()
    GLib.MainLoop().run()
