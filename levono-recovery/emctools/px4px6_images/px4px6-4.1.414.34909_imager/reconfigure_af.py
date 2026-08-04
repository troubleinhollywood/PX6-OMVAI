#!/usr/bin/python 

import sys
import os
from xml.dom.minidom import parse, getDOMImplementation

def main():
	features = [ "Facebook","Flickr"]
	doc = parse("/mnt/system/config/sohoActiveFolders.xml")
	applicationSets = doc.getElementsByTagName("Share")
	for app in applicationSets:
		if app.getAttribute('LastProtocol') in features:
			app.parentNode.removeChild(app)
	test_file=open("/mnt/system/config/sohoActiveFolders.xml",'w')
	doc.writexml(test_file)
	doc.unlink();
        return;
if (__name__ == "__main__"):
        main()
