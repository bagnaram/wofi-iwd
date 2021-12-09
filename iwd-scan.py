#!/usr/bin/python3
#
# Usage:
#   iwd-scan.py [ssid]
# DESCRIPTION:
#   Outputs scanned SSIDs from of all wifi devices via dbus. Outputs in the following format:
#     SSID/n
#     Signal Strength dBm\n
#     psk|wpa|open \n
# OPTIONS:
#   ssid
#     print just the SSID data, followed by a newline character

import sys
import dbus
import collections

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

bus = dbus.SystemBus()

manager = dbus.Interface(bus.get_object("net.connman.iwd", "/"),
                                        "org.freedesktop.DBus.ObjectManager")
objects = manager.GetManagedObjects()

Obj = collections.namedtuple('Obj', ['interfaces', 'children'])
tree = Obj({}, {})
for path in objects:
    node = tree
    elems = path.split('/')
    for subpath in [ '/'.join(elems[:l + 1]) for l in range(1, len(elems)) ]:
        if subpath not in node.children:
            node.children[subpath] = Obj({}, {})
        node = node.children[subpath]
    node.interfaces.update(objects[path])

root = tree.children['/net'].children['/net/connman'].children['/net/connman/iwd']
for path, phy in root.children.items():
    if 'net.connman.iwd.Adapter' not in phy.interfaces:
        continue

    properties = phy.interfaces['net.connman.iwd.Adapter']

    for path2, device in phy.children.items():
        if 'net.connman.iwd.Device' not in device.interfaces:
            continue

        if len(sys.argv) !=2 or (len(sys.argv) == 2 and sys.argv[1] != 'ssid'):
            edevice = dbus.Interface(bus.get_object("net.connman.iwd", path2),
                                        "net.connman.iwd.Station")
            eprint("Scanning: [ %s ]" % path2)
            try:
                edevice.Scan()
            except dbus.exceptions.DBusException as e:
                eprint("Scan already in progress: %s" % e)
                eprint("Defaulting to use existing scan")

        for interface in device.interfaces:
            name = interface.rsplit('.', 1)[-1]
            if name not in ('Device', 'Station', 'AccessPoint', 'AdHoc'):
                continue

            properties = device.interfaces[interface]

            if name != 'Station':
                continue

            eprint("Networks:")

            station = dbus.Interface(bus.get_object("net.connman.iwd", path2),
                                     'net.connman.iwd.Station')
            for path3, rssi in station.GetOrderedNetworks():

                properties2 = objects[path3]['net.connman.iwd.Network']

                if len(sys.argv) !=2 or (len(sys.argv) == 2 and sys.argv[1] != 'ssid'):
                    print("%s%ls" % ( ">" if properties2['Connected'] == 1 else " ",properties2['Name'], ))
                    print("%i dBm" % (rssi / 100,))
                    print("%s" % (properties2['Type'],))
                else:
                    print("%ls" % (properties2['Name'],))
