#!/usr/bin/python 

""" 
sdk_compatibility_from_wynn3 - Check for the compatibility of the SDK applications with the newer Firmware
 
""" 

import sys 
import os 
from xml.dom.minidom import parse, getDOMImplementation 
 
def main():

	isPresent = os.path.isfile("/mnt/system/config/partnerApplicationTable.xml")
	if(isPresent != True):
		print "File not found"
		return;

	changed=0
	securemind_appid = "mindtree_securemind";
	doc = parse("/mnt/system/config/partnerApplicationTable.xml")

	applications = doc.documentElement.getElementsByTagName("application")
	for app in applications:
		app_id = app.getAttribute('id')
		if (app_id == securemind_appid):
			#The Securemind application will no longer be compatible with the new firmware
			#Also the decision was to stop supporting Securemind in Lifeline. So removing this icon from UI
			app.setAttribute('hidden', '1')
			changed=1
        		break;
	if (changed):
		fd=open("/mnt/system/config/partnerApplicationTable.xml",'w')
	        doc.writexml(fd)
		fd.close()

	doc.unlink() 
	return; 
 
 
if (__name__ == "__main__"): 
	main() 
