#!/usr/bin/python 

""" 
noproxy_localhost.py - Python script not to bypass localhost ip through proxy.
 
""" 

import sys 
import os 
from xml.dom.minidom import parse, getDOMImplementation 
 
def main():

	doc = parse("/mnt/system/config/sohoNetwork.xml")
	proxyInfo = doc.documentElement.getElementsByTagName("Proxy")

	#Check whether sohoNetwork.xml has an entry for proxy
	if len(proxyInfo) != 1:
		print "Proxy is not used so far in the device\n";
		doc.unlink()
		return False;

	#Check the value of UseProxy which says whether proxy is currently enabled or not
	if (proxyInfo[0].getAttribute("UseProxy") == "1"):
		found = 0
		#Check whether the /etc/profile has already an entry for localhost for not going through proxy
		localhost_noproxy = os.system("cat /etc/profile | grep 'export no_proxy'")
        	if localhost_noproxy != found:
			os.system("echo 'export no_proxy=localhost,127.0.0.1' >> /etc/profile")
	else:
		print "Proxy is not used currently"

	doc.unlink() 
	return; 
 
 
if (__name__ == "__main__"): 
	main() 


