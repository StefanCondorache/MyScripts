nmcli -f IN-USE,SSID,BSSID,FREQ,SIGNAL device wifi list

nmcli connection modify "wifi_name" 802-11-wireless.band a

nmcli connection modify "wifi_name" 802-11-wireless.bssid MAC_adress

iw dev | grep Interface

nmcli connection modify "wifi_name" 802-11-wireless.powersave 2

nmcli connection up "wifi_name"

bluetoothctl discoverable off

bluetoothctl pairable off