#!/usr/bin/python 

""" 
sdk_compatibility_from_wynn3 - Check for the compatibility of the SDK applications with the newer Firmware
 
""" 

import sys 
import os 
from xml.dom.minidom import parse, getDOMImplementation 
 
def main():

	isPresent = os.path.isfile("/mnt/system/config/applicationSetTable.xml")
	if(isPresent != True):
		print "No SDK applications installed in the device"
		return;

	#SDK applications installed
	atmos_appid = "emc_atmosAppSet";
	doc = parse("/mnt/system/config/applicationSetTable.xml")

	applicationSets = doc.documentElement.getElementsByTagName("applicationSet")
	for application in applicationSets:
		app_id = application.getAttribute('id')
		app_version = application.getAttribute('version')
		app_name = application.getAttribute('name')
		if (app_id == atmos_appid):
			#The Atmos application will no longer be compatible with the new firmware
			#Also the decision was to stop supporting Atmos in Lifeline
			doc.unlink()
        		sys.exit(1);

	doc.unlink() 
	return; 
 
 
if (__name__ == "__main__"): 
	main() 
