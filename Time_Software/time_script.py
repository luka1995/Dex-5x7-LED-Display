import serial
import sys
import time
from datetime import datetime

ser = serial.Serial('/dev/ttyS1')
ser.baudrate = 19200

def serialWrite(string):
	packet = bytearray()
	packet.append(0x1B)
	packet.extend(string)
	ser.write(packet)

dots = 0

while True:
	if dots == 0:
		serialWrite(datetime.now().strftime("%H:%M"))
		dots = 1
	else:
		serialWrite(datetime.now().strftime("%H %M"))
		dots = 0
	time.sleep(1)