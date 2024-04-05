#!/usr/bin/env python3
#python3 kasa-onoff.py $name_plug $user_name $password $sleep_time_toswitch_plug_on

import sys
import time
from PyP100 import PyP110


#WARNING: insert here your tapo app credentials
tapo_email = ""
tapo_psw = ""


moniotr_dir="/opt/moniotr"
"""
This script runs an experiment on the Tapo P110 Smart Plug.
It uses the https://github.com/almottier/TapoP100/tree/main library to control the plug.
"""

def get_ip(deviceid):
    # returns the ip address
    with open(f'{moniotr_dir}/traffic/by-name/{deviceid}/ip.txt') as f:
        return f.readline().rstrip()

def control_plug(plugid,command):

    # Get ip address of device
    ip_address = get_ip(plugid)
    while True:
        try:
            p100 = PyP110.P110(ip_address,tapo_email, tapo_psw) #Creates a P100 plug object
            p100.handshake() #Creates the cookies required for further methods
            p100.login() #Sends credentials to the plug and creates AES Key and IV for further methods
            if command == "on":
                p100.turnOn() #Turns the connected plug onoff
            elif command=="off":
                p100.turnOff() #Turns the connected plug onoff
            break
        except:
            print("Error in kasa-power, trying again in 1 second")
            time.sleep(1)
            pass
    #p110.turnOff()

# Run!
if __name__ == "__main__":
    if len(sys.argv)<3:
        print(f"Usage: {sys.argv[0]} plug_name command(on/off)")
    else:
        control_plug(sys.argv[1], sys.argv[2])
    