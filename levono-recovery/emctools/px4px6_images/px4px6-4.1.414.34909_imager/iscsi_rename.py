#!/usr/bin/python 

""" 
iscsi_naming - Check for the iscsi name whether it contains '.' character
 
""" 

import sys 
import os 
from xml.dom.minidom import parse, getDOMImplementation 
 
def main():

	isPresent = os.path.isfile("/mnt/system/config/sohoiSCSI.xml")
	if(isPresent != True):
		print "No iscsi luns have been created"
		return;

	doc = parse("/mnt/system/config/sohoiSCSI.xml")

	luns = doc.documentElement.getElementsByTagName("Target")
	for lun in luns:
		lun_name = lun.getAttribute('Name')
		if '.' in lun_name:
			doc.unlink()
        		sys.exit(1);

	doc.unlink() 
	return; 
 
 
if (__name__ == "__main__"): 
	main() 
