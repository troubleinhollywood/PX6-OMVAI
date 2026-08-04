#!/usr/bin/python 

""" 
afpd_start.py - Wait for the complete system to come up before starting afpd

The processes are started in the following order. appmd.xml, sohoDisk/sohoFlash.xml and sohoRAM.xml.
Sometimes the processes in sohoDisk/sohoFlash are started before svcd since execd_enable is used.
So execd_enabletemp is used to avoid it. So far execd_enable is used.
 
""" 

import sys 
import os 
import codecs
from xml.dom.minidom import parse, getDOMImplementation 
 
def main():

	changed = False
	isPresent = os.path.isfile("/etc/sohoFlash.xml")
	if(isPresent != True):
		print "sohoFlash xml is not in the device"
		return;

	doc = parse("/etc/sohoFlash.xml")

	processes = doc.documentElement.getElementsByTagName("Program")
	for process in processes:
		prog_name = process.getAttribute('Name')
		if prog_name == "afpd" or prog_name == "cnid_metad":
			process.parentNode.removeChild(process)
			changed = True

	if (changed):
                o = codecs.open("/etc/sohoFlash.xml", "w", encoding="utf-8")
                doc.writexml(o);
                o.close()

	doc.unlink() 
	return; 
 
 
if (__name__ == "__main__"): 
	main() 
